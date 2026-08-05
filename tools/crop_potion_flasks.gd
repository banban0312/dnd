extends SceneTree
## 从 0x72 DungeonTilesetII 裁剪 flask_red/flask_blue 药水图(覆盖旧 DCSS 素材)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var src := Image.load_from_file("res://assets/dungeontileset2/0x72_DungeonTilesetII_v1.7.png")
	const SZ := 16
	for item in [{"name": "red", "x": 288, "y": 352}, {"name": "blue", "x": 304, "y": 352}]:
		var img := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(item.x, item.y, SZ, SZ), Vector2i.ZERO)
		var path := "res://assets/sprites/potion_" + item.name + ".png"
		img.save_png(path)
		print(path, " done")
	quit(0)
