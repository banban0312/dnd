extends SceneTree
## 工具:从 0x72 DungeonTilesetII v1.7 大图裁剪 ogre(食人魔)idle/run 条带。
## 用法:Godot --headless --path . --script res://tools/crop_ogre_frames.gd

func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var src_path := "res://assets/dungeontileset2/0x72_DungeonTilesetII_v1.7.png"
	var src := Image.load_from_file(src_path)
	if src == null:
		printerr("Fail to load:", src_path)
		quit(1)
		return

	var fw := 32
	var fh := 36
	var y := 380

	# idle: x=16,48,80,112
	var idle := Image.create(fw * 4, fh, false, Image.FORMAT_RGBA8)
	for i in 4:
		idle.blit_rect(src, Rect2i(16 + fw * i, y, fw, fh), Vector2i(i * fw, 0))

	# run: x=144,176,208,240
	var run := Image.create(fw * 4, fh, false, Image.FORMAT_RGBA8)
	for i in 4:
		run.blit_rect(src, Rect2i(144 + fw * i, y, fw, fh), Vector2i(i * fw, 0))

	idle.save_png("res://assets/sprites/ogre_idle.png")
	run.save_png("res://assets/sprites/ogre_run.png")
	print("ogre_idle.png + ogre_run.png done (128x36)")
	quit(0)
