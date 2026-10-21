extends SceneTree
## Run after editor import; validates the title uses an exportable imported texture.

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var title := Control.new()
	title.set_script(load("res://scripts/mvp_title_art.gd"))
	root.add_child(title)
	var texture: Texture2D = title.get("background")
	if not texture is CompressedTexture2D or texture.get_width() <= 0:
		push_error("EXPORT PREFLIGHT FAILED: title must use an imported Texture2D resource")
		quit(1)
		return
	var available := OS.get_system_fonts()
	var chinese_font := SystemFont.new()
	chinese_font.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	var glyph_size := chinese_font.get_char_size(0x6df1, 24)
	print("EXPORT PREFLIGHT: imported title texture ", texture.get_width(), "x", texture.get_height())
	print("HOST FONT CHECK: Microsoft YaHei=", available.has("Microsoft YaHei"), "; Chinese glyph size=", glyph_size)
	print("Host font availability does not verify a clean target machine.")
	title.queue_free()
	quit(0)
