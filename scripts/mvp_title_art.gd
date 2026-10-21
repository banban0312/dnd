extends Control
## Pixel illustration and a separate animated ember layer. Never filter the source art.
var clock := 0.0
var background: Texture2D

func _ready() -> void:
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Direct image loading also supports first launch before editor import.
	var source := Image.load_from_file("res://assets/pixel_title.png")
	if source != null:
		background = ImageTexture.create_from_image(source)

func _process(delta: float) -> void:
	clock += delta
	queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color("0c0e14"))
	if background != null:
		draw_texture_rect(background, Rect2(Vector2.ZERO, size), false)
	# A translucent reading field retains the stone texture behind menu lettering.
	for i in range(35):
		var opacity := 0.36 if i < 24 else 0.36 * (1.0 - float(i - 24) / 11.0)
		draw_rect(Rect2(i * 20, 0, 20, size.y), Color(0.025, 0.025, 0.04, opacity))
	for i in range(35):
		var x := 710 + fmod(i * 73.7, 530)
		var y := fposmod(i * 39.1 - clock * (9 + i % 7), 690)
		draw_rect(Rect2(floor(x / 2) * 2, floor(y / 2) * 2, 2, 2), Color(0.95, 0.62, 0.28, 0.28 + 0.2 * sin(clock + i)))
	draw_rect(Rect2(25, 25, 1230, 670), Color(0.66, 0.49, 0.28, 0.65), false, 1)
