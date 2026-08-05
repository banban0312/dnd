extends SceneTree
## 开发工具:把 assets/sprites/ 下的角色条带图生成 SpriteFrames .tres 资源。
## 用法:Godot --headless --path . --script res://tools/generate_sprite_frames.gd
## 生成后 main.tscn 直接引用这些 .tres,编辑器即可预览动画帧。

const STRIPS := {
	"ranger": {
		"idle": "res://assets/sprites/player_ranger_idle.png",
		"run": "res://assets/sprites/player_ranger_run.png",
		"frame": Vector2i(16, 28),
		"fps": 9.0,
	},
	"goblin": {
		"idle": "res://assets/sprites/goblin_idle.png",
		"run": "res://assets/sprites/goblin_run.png",
		"frame": Vector2i(16, 16),
		"fps": 8.0,
	},
	"skeleton": {
		"idle": "res://assets/sprites/skeleton_idle.png",
		"run": "res://assets/sprites/skeleton_run.png",
		"frame": Vector2i(16, 16),
		"fps": 8.0,
	},
	"ogre": {
		"idle": "res://assets/sprites/ogre_idle.png",
		"run": "res://assets/sprites/ogre_run.png",
		"frame": Vector2i(32, 36),
		"fps": 8.0,
	},
}


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for character: String in STRIPS:
		var data: Dictionary = STRIPS[character]
		var frame_size: Vector2i = data.frame
		var fps: float = data.fps
		var frames := SpriteFrames.new()
		for anim in ["idle", "run"]:
			var texture: Texture2D = load(data[anim])
			var cols := texture.get_width() / frame_size.x
			frames.add_animation(anim)
			for i in cols:
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2i(i * frame_size.x, 0, frame_size.x, frame_size.y)
				frames.add_frame(anim, atlas)
			frames.set_animation_speed(anim, fps)
			frames.set_animation_loop(anim, true)
		var err := ResourceSaver.save(frames, "res://assets/sprites/%s_frames.tres" % character)
		print("%s_frames.tres -> %s (idle=%d run=%d fps=%.1f)" % [
			character, error_string(err), frames.get_frame_count("idle"), frames.get_frame_count("run"), fps,
		])
	quit(0)
