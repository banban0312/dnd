extends SceneTree
## 将 IvoryRed armor spritesheet(96x144)拆成 54 个 16x16 单独图标

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var src := Image.load_from_file("res://assets/sprites/ivoryred_armor_sheet.png")
	if src == null:
		printerr("ivoryred_armor_sheet.png not found")
		quit(1)
		return
	const SZ := 16
	var cols := src.get_width() / SZ
	var rows := src.get_height() / SZ
	for y in rows:
		for x in cols:
			var icon := Image.create(SZ, SZ, false, Image.FORMAT_RGBA8)
			icon.blit_rect(src, Rect2i(x * SZ, y * SZ, SZ, SZ), Vector2i.ZERO)
			var path := "res://assets/sprites/ivr_r%02d_c%02d.png" % [y, x]
			icon.save_png(path)
	print("exported %dx%d icons → %d files" % [cols, rows, cols * rows])
	quit(0)
