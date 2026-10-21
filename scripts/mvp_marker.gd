extends Node2D
## World-space interaction art. Actual reward decisions belong to the run.
const CHEST_CLOSED = preload("res://assets/sprites/chest_closed.png")
const CHEST_OPEN = preload("res://assets/sprites/chest_open.png")
var kind := "chest"
var opened := false
var unlocked := false
var near := false
var time := 0.0
var caption: Label

func _ready() -> void:
	caption = Label.new()
	caption.position = Vector2(-130, -68)
	caption.size = Vector2(260, 28)
	caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	caption.add_theme_font_size_override("font_size", 14)
	caption.add_theme_color_override("font_color", Color("e4c991"))
	caption.add_theme_constant_override("outline_size", 5)
	caption.add_theme_color_override("font_outline_color", Color("10151c"))
	add_child(caption)

func _process(delta: float) -> void:
	time += delta
	caption.visible = near
	caption.text = ("[F] 打开补给匣" if not opened else "已经搜寻过了") if kind == "chest" else ("[F] 前往深处" if unlocked else "击败守门者以唤醒升降梯")
	queue_redraw()

func _draw() -> void:
	if kind == "chest":
		draw_ellipse_shadow()
		draw_texture_rect(CHEST_OPEN if opened else CHEST_CLOSED, Rect2(-32, -36, 64, 64), false)
		if not opened:
			var pulse := 0.4 + sin(time * 2.0) * 0.12
			draw_circle(Vector2(0, -31), 3, Color(0.92, 0.70, 0.31, pulse))
	else:
		var tint := Color("d6aa61") if unlocked else Color("65707d")
		for x in [-58, 58]:
			draw_rect(Rect2(x - 5, -45, 10, 12), tint)
		if unlocked:
			var offset := Vector2(0, -18 + sin(time * 2) * 3)
			draw_line(offset - Vector2(0, 14), offset + Vector2(0, 8), tint, 3)
			draw_polyline(PackedVector2Array([offset + Vector2(-8, 1), offset + Vector2(0, 9), offset + Vector2(8, 1)]), tint, 3)

func draw_ellipse_shadow() -> void:
	draw_set_transform(Vector2(0, 19), 0, Vector2(1.5, 0.45))
	draw_circle(Vector2.ZERO, 23, Color(0, 0, 0, 0.35))
	draw_set_transform(Vector2.ZERO)
