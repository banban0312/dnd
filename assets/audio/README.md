# Original synthesized game music

These two compositions and their sounds were created specifically for **deeper and deeper**. No external recordings, samples, melodies, soundfonts, or third-party music are used.

The project owner may use, modify, redistribute, and sublicense these original compositions, recordings, and the generator, including in commercial game builds, without attribution or royalties. This permission does not change the licenses of unrelated project assets.

Reproduce from the repository root with Python 3 and NumPy:

```powershell
python tools/generate_music.py
```

The deterministic seed is `421705`. Both files are mono, 44,100 Hz, signed 16-bit PCM WAV. The generator constructs all oscillators and noise in code, mixes musical events cyclically, removes DC, normalizes to a 0.79 sample peak, and smooths the tiny loop boundary. Godot's music manager sets the full recording to loop and handles one-second transitions, quiet default levels, pause ducking, and mute.

- `exploration_medieval.wav`: 16 bars at 90 BPM, about 42.67 seconds. Plucked lute voicings, breathy woodwind phrases, low bowed tones, and quiet frame drums in D minor/modal harmony.
- `boss_electronic.wav`: 16 bars at 144 BPM, about 26.67 seconds. Four-on-the-floor percussion, pumping synth bass, sixteenth-note arpeggio, original melodic phrases, a two-bar breakdown, and a final reprise.

Keep both `.wav.import` sidecars in version control: their `compress/mode=0` preserves PCM16 and exact full-track loop sample counts. The manager owns runtime loop enablement.
