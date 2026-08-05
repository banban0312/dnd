extends SceneTree
## 从 0x72 DungeonTilesetII 裁剪武器图标(bow/sword,用作装备/掉落图标)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var src := Image.load_from_file("res://assets/dungeontileset2/0x72_DungeonTilesetII_v1.7.png")
	var items: Array[Dictionary] = [
		{"name": "icon_bow",    "x": 289, "y": 195, "w": 14, "h": 26},
		{"name": "icon_sword",  "x": 323, "y": 10,  "w": 10, "h": 21},
	]
	for it in items:
		var img := Image.create(it.w, it.h, false, Image.FORMAT_RGBA8)
		img.blit_rect(src, Rect2i(it.x, it.y, it.w, it.h), Vector2i.ZERO)
		var path := "res://assets/sprites/%s.png" % it.name
		img.save_png(path)
		print(path, " done")
	quit(0)
