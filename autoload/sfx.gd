extends Node
## 音效系統（Autoload：Sfx）
## 所有音效在啟動時以程式合成（正弦波 + 包絡線），零音檔資產、零授權問題。
## 全域按鈕音由 Main 統一掛勾；遊戲事件音由各畫面呼叫 Sfx.play("名稱")。
## 設定的「音效開關」存在存檔 settings.sound。

const MIX_RATE := 22050

var _streams: Dictionary = {}
var _pool: Array[AudioStreamPlayer] = []


func _ready() -> void:
	_streams = {
		# 名稱: 音符序列 [[頻率, 長度秒], ...]
		"tap": _tone_seq([[880.0, 0.05]], 0.18),
		"stone": _tone_seq([[196.0, 0.05], [147.0, 0.06]], 0.5),
		"error": _tone_seq([[165.0, 0.08], [131.0, 0.12]], 0.35),
		"win": _tone_seq([[523.25, 0.11], [659.25, 0.11], [783.99, 0.22]], 0.3),
		"lose": _tone_seq([[392.0, 0.12], [311.13, 0.12], [261.63, 0.22]], 0.28),
		"achievement": _tone_seq([[659.25, 0.09], [880.0, 0.09], [1046.5, 0.2]], 0.25),
	}
	for i in 6:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_pool.append(p)


func enabled() -> bool:
	return bool(SaveManager.section("settings").get("sound", true))


func set_enabled(on: bool) -> void:
	SaveManager.section("settings")["sound"] = on
	SaveManager.save()


func play(sound: String) -> void:
	if not enabled() or not _streams.has(sound):
		return
	for p in _pool:
		if not p.playing:
			p.stream = _streams[sound]
			p.play()
			return


## 合成一段音符序列：正弦波 + 快速起音、指數衰減包絡
func _tone_seq(notes: Array, volume: float) -> AudioStreamWAV:
	var total := 0.0
	for n in notes:
		total += float(n[1])
	var samples := PackedFloat32Array()
	samples.resize(int(total * MIX_RATE) + 1)
	var offset := 0
	for n in notes:
		var freq := float(n[0])
		var dur := float(n[1])
		var length := int(dur * MIX_RATE)
		for i in length:
			var t := float(i) / MIX_RATE
			var env := exp(-5.0 * t / dur) * minf(1.0, t * 500.0)
			samples[offset + i] = sin(TAU * freq * t) * env * volume
		offset += length
	return _make_wav(samples)


func _make_wav(samples: PackedFloat32Array) -> AudioStreamWAV:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32767.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = MIX_RATE
	wav.data = data
	return wav
