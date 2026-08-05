class_name SoundFactory
## 程序化音效合成:无外部素材,全部运行时生成(正弦/方波/噪声扫频)。
## 首次合成后缓存复用;用法:Sfx.play(SoundFactory.shoot())

const SAMPLE_RATE := 44100

static var _cache: Dictionary = {}


## 合成一段多分段音效。segments: [{f0,f1,dur,shape}],f0→f1 线性扫频,
## shape 支持 "sine" / "square" / "noise",整体线性衰减包络。
static func _synth(segments: Array[Dictionary], volume_db := -8.0) -> AudioStreamWAV:
	var total_frames := 0
	for seg in segments:
		total_frames += int(seg["dur"] * SAMPLE_RATE)
	var data := PackedByteArray()
	data.resize(total_frames * 2)
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var frame := 0
	var phase := 0.0
	for seg in segments:
		var frames := int(seg["dur"] * SAMPLE_RATE)
		var f0: float = seg["f0"]
		var f1: float = seg["f1"]
		var shape: String = seg["shape"]
		for i in frames:
			var t := float(i) / float(frames)
			var freq := lerpf(f0, f1, t)
			phase += TAU * freq / SAMPLE_RATE
			var s := sin(phase)
			match shape:
				"square":
					s = 1.0 if s >= 0.0 else -1.0
				"noise":
					s = rng.randf_range(-1.0, 1.0)
			var v := int(clampf(s * (1.0 - t) * 0.5, -1.0, 1.0) * 32767.0)
			data.encode_s16(frame * 2, v)
			frame += 1
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = SAMPLE_RATE
	wav.stereo = false
	wav.data = data
	return wav


static func _cached(key: String, maker: Callable) -> AudioStreamWAV:
	if not _cache.has(key):
		_cache[key] = maker.call()
	return _cache[key]


## 射箭:高频下扫"嗖"
static func shoot() -> AudioStreamWAV:
	return _cached("shoot", func() -> AudioStreamWAV:
		return _synth([{"f0": 1700.0, "f1": 380.0, "dur": 0.09, "shape": "sine"}], -6.0))


## 命中敌人:噪声爆音 + 低频衰减"啪"
static func hit() -> AudioStreamWAV:
	return _cached("hit", func() -> AudioStreamWAV:
		return _synth([
			{"f0": 340.0, "f1": 120.0, "dur": 0.07, "shape": "noise"},
			{"f0": 200.0, "f1": 90.0, "dur": 0.08, "shape": "sine"},
		], -8.0))


## 玩家受击:低沉下坠
static func hurt() -> AudioStreamWAV:
	return _cached("hurt", func() -> AudioStreamWAV:
		return _synth([{"f0": 230.0, "f1": 80.0, "dur": 0.18, "shape": "sine"}], -4.0))


## 格挡:金属"当"(方波)
static func block() -> AudioStreamWAV:
	return _cached("block", func() -> AudioStreamWAV:
		return _synth([{"f0": 720.0, "f1": 480.0, "dur": 0.12, "shape": "square"}], -16.0))


## 闪避:短促噪声"呼"
static func dodge() -> AudioStreamWAV:
	return _cached("dodge", func() -> AudioStreamWAV:
		return _synth([{"f0": 420.0, "f1": 160.0, "dur": 0.12, "shape": "noise"}], -12.0))


## 升级:C5-E5-G5 上行琶音
static func upgrade() -> AudioStreamWAV:
	return _cached("upgrade", func() -> AudioStreamWAV:
		return _synth([
			{"f0": 523.0, "f1": 523.0, "dur": 0.09, "shape": "sine"},
			{"f0": 659.0, "f1": 659.0, "dur": 0.09, "shape": "sine"},
			{"f0": 784.0, "f1": 784.0, "dur": 0.18, "shape": "sine"},
		], -8.0))


## 开箱:G5-C6 上扬"叮"
static func chest() -> AudioStreamWAV:
	return _cached("chest", func() -> AudioStreamWAV:
		return _synth([
			{"f0": 880.0, "f1": 880.0, "dur": 0.06, "shape": "sine"},
			{"f0": 1175.0, "f1": 1175.0, "dur": 0.18, "shape": "sine"},
		], -8.0))


## 拾取药水:短促上扬
static func pickup() -> AudioStreamWAV:
	return _cached("pickup", func() -> AudioStreamWAV:
		return _synth([{"f0": 660.0, "f1": 990.0, "dur": 0.07, "shape": "sine"}], -8.0))


## 敌人死亡:下行"呜"
static func die() -> AudioStreamWAV:
	return _cached("die", func() -> AudioStreamWAV:
		return _synth([
			{"f0": 300.0, "f1": 220.0, "dur": 0.12, "shape": "sine"},
			{"f0": 160.0, "f1": 110.0, "dur": 0.22, "shape": "sine"},
		], -6.0))


## Boss 仇恨激活:低吼(方波下扫 + 噪声)
static func boss_roar() -> AudioStreamWAV:
	return _cached("boss_roar", func() -> AudioStreamWAV:
		return _synth([
			{"f0": 130.0, "f1": 90.0, "dur": 0.35, "shape": "square"},
			{"f0": 110.0, "f1": 70.0, "dur": 0.3, "shape": "noise"},
		], -4.0))


## Boss 死亡:沉重长音 + 震颤
static func boss_die() -> AudioStreamWAV:
	return _cached("boss_die", func() -> AudioStreamWAV:
		return _synth([
			{"f0": 160.0, "f1": 60.0, "dur": 0.5, "shape": "sine"},
			{"f0": 90.0, "f1": 40.0, "dur": 0.6, "shape": "square"},
		], -2.0))
