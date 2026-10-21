"""Original deterministic, loopable music; Python 3 + NumPy, no sampled sources.
Run from the repository root: python tools/generate_music.py
"""
from pathlib import Path
import math
import wave
import numpy as np

RATE = 44100
OUTPUT = Path(__file__).resolve().parents[1] / 'assets' / 'audio'
OUTPUT.mkdir(parents=True, exist_ok=True)
RNG = np.random.default_rng(421705)

def hz(note):
    return 440.0 * 2 ** ((note - 69) / 12)

def envelope(size, attack=.008, release=.09):
    env = np.ones(size)
    attack_n = min(int(RATE * attack), size)
    release_n = min(int(RATE * release), size)
    env[:attack_n] *= np.sin(np.linspace(0, math.pi / 2, attack_n)) ** 2
    env[-release_n:] *= np.cos(np.linspace(0, math.pi / 2, release_n)) ** 2
    return env

def pluck(note, duration):
    t = np.arange(int(RATE * duration)) / RATE
    signal = np.zeros_like(t)
    for harmonic in range(1, 8):
        signal += np.sin(2 * math.pi * hz(note) * harmonic * t) * np.exp(-t * (2.8 + harmonic * 1.6)) / harmonic ** 1.45
    signal += RNG.normal(0, .08, len(t)) * np.exp(-t * 85)
    return signal * envelope(len(t), .003, .1)

def flute(note, duration):
    t = np.arange(int(RATE * duration)) / RATE
    phase = 2 * math.pi * hz(note) * t + .022 * np.sin(2 * math.pi * 5.1 * t)
    tone = np.sin(phase) + .16 * np.sin(phase * 2) + .07 * np.sin(phase * 3)
    breath = np.convolve(RNG.normal(0, .035, len(t)), np.ones(8) / 8, mode='same')
    return (tone + breath) * envelope(len(t), .065, .14)

def strings(note, duration):
    t = np.arange(int(RATE * duration)) / RATE
    tone = sum(np.sin(2 * math.pi * hz(note) * detune * t) for detune in [.998, 1, 1.002]) / 3
    return (tone + .14 * np.sin(4 * math.pi * hz(note) * t)) * envelope(len(t), .22, .35)

def drum(kind):
    duration = {'kick': .42, 'snare': .22, 'hat': .085, 'frame': .3}[kind]
    t = np.arange(int(RATE * duration)) / RATE
    noise = RNG.normal(0, 1, len(t))
    if kind == 'kick':
        phase = 2 * math.pi * (48 * t + 115 * .024 * (1 - np.exp(-t / .024)))
        out = np.sin(phase) * np.exp(-t * 13) + noise * .12 * np.exp(-t * 180)
    elif kind == 'snare':
        out = (noise - np.convolve(noise, np.ones(14) / 14, 'same')) * np.exp(-t * 22) * .48
        out += np.sin(2 * math.pi * 183 * t) * np.exp(-t * 30) * .35
    elif kind == 'hat':
        out = (noise - np.convolve(noise, np.ones(5) / 5, 'same')) * np.exp(-t * 65) * .3
    else:
        out = np.sin(2 * math.pi * 108 * t + .6 * np.sin(2 * math.pi * 28 * t)) * np.exp(-t * 17)
        out += noise * np.exp(-t * 45) * .11
    return out * envelope(len(t), .001, .02)

def synth(note, duration, bright=False):
    t = np.arange(int(RATE * duration)) / RATE
    frequency = hz(note)
    out = np.zeros_like(t)
    for harmonic in range(1, 10 if bright else 5):
        # Additive synthesis keeps every oscillator comfortably below Nyquist.
        if frequency * harmonic < RATE / 2:
            out += np.sin(2 * math.pi * frequency * harmonic * t) / harmonic ** (1.35 if bright else 1.7)
    return out * envelope(len(t), .007, .075)

class Score:
    def __init__(self, bpm):
        self.beat = 60 / bpm
        self.samples = int(round(64 * self.beat * RATE))
        self.mix = np.zeros(self.samples)
    def add(self, beat, sound, gain):
        indices = (int(round(beat * self.beat * RATE)) + np.arange(len(sound))) % self.samples
        np.add.at(self.mix, indices, sound * gain)
    def note(self, beat, midi, length, instrument, gain):
        self.add(beat, instrument(midi, length * self.beat), gain)
    def write(self, name):
        signal = self.mix - np.mean(self.mix)
        # Gentle saturation and -2 dB true sample peak headroom.
        signal = np.tanh(signal * .9)
        signal *= .79 / max(np.max(np.abs(signal)), 1e-9)
        # Sub-millisecond seam smoothing makes the encoded boundaries meet at zero.
        seam = 128
        signal[:seam] *= np.linspace(0, 1, seam)
        signal[-seam:] *= np.linspace(1, 0, seam)
        pcm = (signal * 32767).astype('<i2')
        with wave.open(str(OUTPUT / name), 'wb') as stream:
            stream.setnchannels(1)
            stream.setsampwidth(2)
            stream.setframerate(RATE)
            stream.writeframes(pcm.tobytes())
        print(f'{name}: {len(pcm) / RATE:.2f}s, {(OUTPUT / name).stat().st_size:,} bytes, peak={np.max(np.abs(signal)):.3f}, DC={np.mean(signal):.7f}')

# D minor / modal medieval processional. Two related eight-bar flute phrases.
medieval = Score(90)
chords = [(50, 53, 57), (46, 50, 53), (48, 53, 57), (48, 52, 55),
          (50, 53, 57), (43, 46, 50), (46, 50, 53), (45, 49, 52)]
melody = [
 [(69, 1), (72, .5), (74, .5), (77, 1), (76, 1)],
 [(74, 1.5), (72, .5), (70, 1), (69, 1)],
 [(69, .5), (72, .5), (77, 1), (76, 1), (72, 1)],
 [(67, 1), (69, 1), (72, 1.5), (76, .5)],
 [(77, 1), (76, .5), (74, .5), (72, 1), (69, 1)],
 [(70, 1), (74, 1), (77, .5), (74, .5), (70, 1)],
 [(72, 1), (70, 1), (69, 1), (65, 1)],
 [(64, 1), (69, 1), (73, 1), (76, 1)],
]
for bar in range(16):
    chord = chords[bar % 8]
    base = bar * 4
    medieval.note(base, chord[0] - 12, 4.1, strings, .13)
    for eighth in range(8):
        note = chord[[0, 1, 2, 1, 0, 2, 1, 2][eighth]] + (12 if eighth % 4 == 3 else 0)
        medieval.note(base + eighth * .5, note, 1.8, pluck, .24 if eighth % 2 == 0 else .17)
    if bar not in [0, 8]:
        offset = .125 if bar % 2 else 0
        for note, length in melody[bar % 8]:
            medieval.note(base + offset, note + (0 if bar < 12 else -12), max(.18, length * .92), flute, .13)
            offset += length
    medieval.add(base, drum('frame'), .11)
    medieval.add(base + 2, drum('frame'), .065)
    if bar % 4 == 3:
        medieval.add(base + 3.5, drum('frame'), .05)
medieval.write('exploration_medieval.wav')

# D minor four-on-the-floor encounter cue. Intro, statement, breakdown, reprise.
boss = Score(144)
roots = [38, 34, 41, 36, 38, 43, 34, 37]
lead_phrase = [74, 77, 81, 79, 77, 74, 72, 69,
               70, 74, 77, 76, 74, 70, 69, 65,
               77, 81, 84, 81, 79, 77, 76, 72,
               72, 76, 79, 81, 79, 76, 72, 73]
for bar in range(16):
    base = bar * 4
    root = roots[bar % 8]
    breakdown = bar in [8, 9]
    for beat in range(4):
        if not breakdown or beat in [0, 2]:
            boss.add(base + beat, drum('kick'), .72)
        if beat in [1, 3]:
            boss.add(base + beat, drum('snare'), .34 if not breakdown else .15)
    for tick in range(8 if bar < 12 else 16):
        subdivision = .5 if bar < 12 else .25
        if breakdown and tick % 2:
            continue
        boss.add(base + tick * subdivision, drum('hat'), .11 if tick % 2 == 0 else .065)
    # Offbeat bass leaves the kick transient clear; its envelope pumps per beat.
    for eighth in range(8):
        bass = synth(root + (12 if eighth in [3, 7] else 0), boss.beat * .46)
        times = np.arange(len(bass)) / RATE + eighth * .5 * boss.beat
        pump = .18 + .82 * np.minimum(1, (times % boss.beat) / (boss.beat * .42))
        boss.add(base + eighth * .5, bass * pump, .27 if not breakdown else .13)
    chord = [root + 24, root + 27, root + 31, root + 36]
    for tick in range(16):
        note = chord[[0, 2, 1, 3][tick % 4]]
        boss.note(base + tick * .25, note, .2, lambda n, d: synth(n, d, True), .066 if not breakdown else .036)
    if bar >= 2 and not breakdown:
        for index in range(4):
            note = lead_phrase[(bar % 4) * 8 + index * 2]
            boss.note(base + index + (.25 if index % 2 else 0), note, .63, lambda n, d: synth(n, d, True), .145)
    if bar in [3, 7, 11, 15]:
        for tick in range(4):
            boss.add(base + 3 + tick * .25, drum('snare'), .12 + tick * .035)
    if bar in [0, 4, 10, 12]:
        boss.note(base, root + 12, 3.7, strings, .1)
boss.write('boss_electronic.wav')
