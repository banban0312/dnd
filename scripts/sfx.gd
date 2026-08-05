extends Node
## 全局音效播放器(Autoload:Sfx)。
## 每个音效使用临时 AudioStreamPlayer,播完自动释放,天然支持并发叠加。
## 这是真正的跨场景全局资源(音效总线),符合 Autoload 使用规范。

## 播放一个音效流,volume_db 为额外增益(可负)。
func play(stream: AudioStream, volume_db := 0.0) -> void:
	if stream == null:
		return
	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.volume_db = volume_db
	player.finished.connect(player.queue_free)
	add_child(player)
	player.play()
