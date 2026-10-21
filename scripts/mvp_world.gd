extends Node2D
## Three authored encounters share a traversable spine. Visuals are drawn locally;
## collision geometry uses the same rectangles as the masonry.

var player_spawn := Vector2(280, 420)
var enemy_positions: Array[Vector2] = []
var chest_positions: Array[Vector2] = []
var boss_position := Vector2(1968, 420)
var exit_position := Vector2(2208, 420)
var map_size := Vector2(2400, 840)
var rooms: Array[Rect2] = []
var depth := 1
var _seed := 1
var _floors: Array[Rect2] = []
var _walls: Array[Rect2] = []
var _pillars: Array[Vector2] = []
var _stones: Array[Dictionary] = []
var _scratches: Array[PackedVector2Array] = []
var _lights: Array[Vector2] = []

const FLOOR_TEXTURE = preload("res://assets/sprites/floor.png")
const WALL_TEXTURE = preload("res://assets/sprites/wall.png")
const PILLAR_TEXTURE = preload("res://assets/sprites/pillar.png")

const INK := Color("10141c")
const MORTAR := Color("202630")
const GOLD := Color("d9a65c")
const BONE := Color("c3bca7")

class Flame extends Node2D:
	var cool := false
	var phase := 0.0
	var tick := 0.0

	func _process(delta: float) -> void:
		phase += delta
		tick += delta
		if tick > 0.08:
			tick = 0.0
			queue_redraw()

	func _draw() -> void:
		var hue := Color("7bc4b6") if cool else Color("edb963")
		var pulse := 1.0 + sin(phase * 4.7 + position.x) * 0.05
		for i in range(8, 0, -1):
			var radius := float(i) * 11.0 * pulse
			draw_circle(Vector2.ZERO, radius, Color(hue, 0.008 + float(9 - i) * 0.001))
		draw_ellipse_local(Vector2(0, 8), Vector2(16, 6), Color(0, 0, 0, 0.3))
		draw_rect(Rect2(-9, -2, 18, 7), Color("302d2a"))
		draw_rect(Rect2(-6, -3, 12, 2), Color("74634b"))
		draw_rect(Rect2(-3, -19, 6, 17), Color(hue, 0.8))
		draw_rect(Rect2(-5, -13, 10, 9), hue)
		draw_rect(Rect2(-2, -17 - int(sin(phase * 13) * 2), 4, 10), Color("f6dfaa") if not cool else Color("c3e6d6"))
		draw_rect(Rect2(0, -23 - int(sin(phase * 8) * 3), 2, 3), Color(hue, 0.5))

	func draw_ellipse_local(center: Vector2, radius: Vector2, tint: Color) -> void:
		var points := PackedVector2Array()
		for i in range(24):
			var angle := TAU * float(i) / 24.0
			points.append(center + Vector2(cos(angle), sin(angle)) * radius)
		draw_colored_polygon(points, tint)


func build(p_depth: int, seed_value: int = 1) -> void:
	depth = p_depth
	_seed = seed_value
	z_index = -20
	rooms.assign([
		Rect2(96, 120, 640, 600),
		Rect2(832, 88, 704, 664),
		Rect2(1632, 120, 672, 600),
	])
	_floors.assign(rooms)
	_floors.append(Rect2(720, 350, 128, 140))
	_floors.append(Rect2(1520, 350, 128, 140))
	for i in rooms.size():
		var room: Rect2 = rooms[i]
		_wall(Rect2(room.position - Vector2(24, 30), Vector2(room.size.x + 48, 30)))
		_wall(Rect2(Vector2(room.position.x - 24, room.end.y), Vector2(room.size.x + 48, 30)))
		_side_wall(room.position.x - 24, room.position.y, room.end.y, i > 0)
		_side_wall(room.end.x, room.position.y, room.end.y, i < 2)
	for corridor in [Rect2(736, 326, 96, 24), Rect2(736, 490, 96, 24), Rect2(1536, 326, 96, 24), Rect2(1536, 490, 96, 24)]:
		_wall(corridor)
	_pillars.assign([Vector2(560, 230), Vector2(560, 610), Vector2(1048, 240), Vector2(1320, 600), Vector2(1768, 230), Vector2(2180, 610)])
	for p in _pillars:
		_collision(Rect2(p - Vector2(22, 19), Vector2(44, 38)))
	enemy_positions.assign([
		Vector2(1000, 390), Vector2(1210, 300), Vector2(1380, 415), Vector2(1150, 580),
		Vector2(1775, 350), Vector2(1760, 570), Vector2(2120, 270), Vector2(2180, 520),
	])
	chest_positions.assign([Vector2(610, 290), Vector2(1310, 240)])
	_lights.assign([Vector2(168, 194), Vector2(650, 628), Vector2(906, 168), Vector2(1462, 664), Vector2(1706, 196), Vector2(2228, 206), Vector2(1710, 638)])
	for p in _lights:
		var flame := Flame.new()
		flame.position = p
		flame.cool = depth > 1 and int(p.x) % 3 != 0
		add_child(flame)
	_prepare_surface()
	queue_redraw()


func _side_wall(x: float, top: float, bottom: float, doorway: bool) -> void:
	if doorway:
		_wall(Rect2(x, top, 24, 350 - top))
		_wall(Rect2(x, 490, 24, bottom - 490))
	else:
		_wall(Rect2(x, top, 24, bottom - top))


func _wall(rect: Rect2) -> void:
	_walls.append(rect)
	_collision(rect)


func _collision(rect: Rect2) -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collider := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = rect.size
	collider.shape = shape
	collider.position = rect.get_center()
	body.add_child(collider)
	add_child(body)


func _prepare_surface() -> void:
	var random := RandomNumberGenerator.new()
	random.seed = _seed + depth * 1451
	for floor_rect in _floors:
		var row := 0
		var y := floor_rect.position.y
		while y < floor_rect.end.y:
			var x := floor_rect.position.x
			while x < floor_rect.end.x:
				var width := minf(64.0, floor_rect.end.x - x)
				var height := minf(64.0, floor_rect.end.y - y)
				var tint := Color("303640") if depth == 1 else Color("29363b")
				tint = tint.lightened(random.randf_range(-0.055, 0.045))
				_stones.append({"rect": Rect2(x + 1, y + 1, width - 2, height - 2), "color": tint, "scar": random.randf() < 0.075})
				x += 64
			y += 64
			row += 1
	for i in range(38 if depth == 1 else 65):
		var room: Rect2 = rooms[random.randi_range(0, rooms.size() - 1)]
		var p := Vector2(random.randf_range(room.position.x + 60, room.end.x - 60), random.randf_range(room.position.y + 60, room.end.y - 60))
		_scratches.append(PackedVector2Array([p, p + Vector2(8, 4), p + Vector2(14, 1), p + Vector2(22, 10)]))


func _draw() -> void:
	if rooms.is_empty():
		return
	draw_rect(Rect2(Vector2(-500, -500), map_size + Vector2(1000, 1000)), INK)
	for room in _floors:
		draw_rect(room, MORTAR)
	for stone in _stones:
		var rect: Rect2 = stone.rect
		var tint: Color = stone.color
		draw_texture_rect(FLOOR_TEXTURE, rect, false, Color("c8bbaa") if depth == 1 else Color("9fbbb6"))
		draw_rect(rect, Color(tint, 0.18))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), tint.lightened(0.045), 1)
		if stone.scar:
			draw_line(rect.position + Vector2(8, 8), rect.position + Vector2(15, 8), tint.darkened(0.19), 2)
	# A deliberate inlaid navigation spine makes the connection between rooms legible.
	for room in rooms:
		draw_rect(Rect2(room.position + Vector2(24, 24), room.size - Vector2(48, 48)), Color("4b4c49") if depth == 1 else Color("42514f"), false, 2)
		draw_rect(Rect2(room.position + Vector2(32, 32), room.size - Vector2(64, 64)), Color("363c42"), false, 1)
		for corner in [room.position + Vector2(24, 24), Vector2(room.end.x - 24, room.position.y + 24), room.end - Vector2(24, 24), Vector2(room.position.x + 24, room.end.y - 24)]:
			_diamond(corner, 5, Color("77664b") if depth == 1 else Color("5d7871"))
	for x in [736, 832, 1536, 1632]:
		for offset in [-57, 57]:
			draw_rect(Rect2(x - 6, 420 + offset, 12, 3), Color("957b51"))
		for i in range(5):
			draw_rect(Rect2(x - 4, 363 + i * 24, 8, 18), Color("464750"))
	_heraldry()
	# Chamber floor seals are restrained, so arrows and enemies retain contrast.
	_seal(Vector2(350, 420), 92, Color("776747"), false)
	_seal(Vector2(1184, 420), 108, Color("49525a"), false)
	_seal(boss_position, 154, Color("775044") if depth == 1 else Color("81504f"), true)
	for scratch in _scratches:
		draw_polyline(scratch, Color("222832") if depth == 1 else Color("674345"), 1)
	# Low wall shadows anchor geometry without obscuring traversal boundaries.
	for wall in _walls:
		draw_rect(Rect2(wall.position + Vector2(0, 15), wall.size + Vector2(5, 12)), Color(0.025, 0.035, 0.045, 0.58))
	for wall in _walls:
		_masonry(wall)
	for p in _pillars:
		_pillar(p)
	_entrance()
	_exit_arch()
	# Bones/debris stay along edges, never in a doorway or under combatants.
	for p in [Vector2(430, 665), Vector2(935, 665), Vector2(1450, 270), Vector2(1830, 640), Vector2(2240, 320)]:
		_debris(p)
	# Gentle edge occlusion gives the chambers volume while leaving the center readable.
	for room in rooms:
		for i in range(5):
			var alpha := 0.025 * float(5 - i)
			draw_rect(Rect2(room.position + Vector2(0, i * 5), Vector2(room.size.x, 5)), Color(0, 0, 0, alpha))
			draw_rect(Rect2(room.position + Vector2(i * 5, 0), Vector2(5, room.size.y)), Color(0, 0, 0, alpha * 0.7))


func _masonry(rect: Rect2) -> void:
	draw_rect(rect, Color("181f29"))
	var horizontal := rect.size.x > rect.size.y
	var length := rect.size.x if horizontal else rect.size.y
	var count := int(ceil(length / 42.0))
	for i in count:
		var block: Rect2
		if horizontal:
			block = Rect2(rect.position + Vector2(i * 42 + 1, 1), Vector2(minf(40, length - i * 42 - 1), rect.size.y - 3))
		else:
			block = Rect2(rect.position + Vector2(1, i * 42 + 1), Vector2(rect.size.x - 3, minf(40, length - i * 42 - 1)))
		if block.size.x <= 0 or block.size.y <= 0:
			continue
		var tint := Color("444c57") if i % 3 != 0 else Color("3d4551")
		if depth > 1:
			tint = tint.lerp(Color("3b5353"), 0.2)
		draw_texture_rect(WALL_TEXTURE, block, false, Color("b7ac99") if depth == 1 else Color("91a6a3"))
		draw_rect(block, Color(tint, 0.2))
		draw_line(block.position + Vector2(1, 1), block.position + Vector2(block.size.x - 1, 1), Color("64707a"), 2)
		draw_line(block.position + Vector2(1, 3), block.position + Vector2(1, block.size.y), Color("505b67"), 1)
		draw_line(block.position + Vector2(1, block.size.y - 2), block.end - Vector2(1, 2), Color("242b35"), 3)


func _pillar(p: Vector2) -> void:
	draw_texture_rect(PILLAR_TEXTURE, Rect2(p - Vector2(32, 60), Vector2(64, 80)), false, Color("c7beac"))
	_diamond(p + Vector2(0, -35), 3, GOLD)


func _seal(center: Vector2, radius: float, tint: Color, ritual: bool) -> void:
	draw_arc(center, radius, 0, TAU, 96, Color(tint, 0.65), 2)
	draw_arc(center, radius - 7, 0, TAU, 96, Color(tint, 0.30), 1)
	for i in range(12 if ritual else 8):
		var angle := TAU * float(i) / (12.0 if ritual else 8.0)
		var normal := Vector2(cos(angle), sin(angle))
		draw_line(center + normal * (radius - 14), center + normal * (radius - 24), Color(tint, 0.7), 2)
		if ritual:
			_diamond(center + normal * (radius + 9), 3, Color(tint, 0.65))
	if ritual:
		for i in range(3):
			var angle := TAU * float(i) / 3.0 - PI / 2
			draw_line(center + Vector2(cos(angle), sin(angle)) * radius * 0.55, center + Vector2(cos(angle + TAU / 3), sin(angle + TAU / 3)) * radius * 0.55, Color(tint, 0.30), 2)
	else:
		_diamond(center, 13, Color(tint, 0.65))
		_diamond(center, 7, Color("303640") if depth == 1 else Color("29363b"))


func _diamond(center: Vector2, radius: float, tint: Color) -> void:
	draw_colored_polygon(PackedVector2Array([center + Vector2(0, -radius), center + Vector2(radius, 0), center + Vector2(0, radius), center + Vector2(-radius, 0)]), tint)


func _entrance() -> void:
	var origin := Vector2(144, 420)
	for i in range(6):
		draw_rect(Rect2(origin + Vector2(i * 14, -45), Vector2(12, 90)), Color("242b34").lightened(float(i) * 0.018))
		draw_line(origin + Vector2(i * 14 + 1, -45), origin + Vector2(i * 14 + 1, 45), Color("58606b"), 2)
	for y in [-58, 55]:
		draw_rect(Rect2(origin + Vector2(-4, y), Vector2(98, 3)), Color("776344"))


func _exit_arch() -> void:
	var p := exit_position
	# Readable descending staircase, distinct from a loot container or wall ornament.
	draw_rect(Rect2(p - Vector2(45, 62), Vector2(90, 124)), Color("11171f"))
	for i in range(7):
		var c := Color("414b56").darkened(float(i) * 0.085)
		draw_rect(Rect2(p + Vector2(-39, -52 + i * 16), Vector2(78, 13)), c)
		draw_line(p + Vector2(-39, -52 + i * 16), p + Vector2(39, -52 + i * 16), c.lightened(0.12), 2)
	for x in [-52, 43]:
		draw_rect(Rect2(p + Vector2(x, -72), Vector2(9, 144)), Color("71706a"))
		draw_rect(Rect2(p + Vector2(x + 2, -69), Vector2(3, 138)), Color("b69a66"))
	draw_rect(Rect2(p + Vector2(-52, -76), Vector2(104, 10)), Color("818278"))
	_diamond(p + Vector2(0, -92), 7, GOLD if depth == 1 else Color("a96261"))


func _debris(p: Vector2) -> void:
	for i in range(4):
		draw_rect(Rect2(p + Vector2(i * 9, (i % 2) * 7), Vector2(6, 3)), Color("74736c"))
	draw_rect(Rect2(p + Vector2(-10, 3), Vector2(9, 7)), Color("77766d"))
	draw_rect(Rect2(p + Vector2(-8, 5), Vector2(2, 2)), Color("202630"))
	draw_rect(Rect2(p + Vector2(-3, 5), Vector2(2, 2)), Color("202630"))


func _heraldry() -> void:
	# The old kingdom's processional carpets stop before each combat seal.
	for origin in [Vector2(255, 350), Vector2(860, 350), Vector2(1658, 350)]:
		draw_rect(Rect2(origin, Vector2(200, 140)), Color("49272c") if depth == 1 else Color("303b49"))
		# Regular two-pixel stitches and irregular worn threads give cloth its own material.
		for yy in range(4, 138, 4):
			for xx in range(3, 198, 4):
				var thread := Color("78454a") if (xx + yy) % 12 == 0 else Color("341e29")
				draw_rect(Rect2(origin + Vector2(xx, yy), Vector2(2, 1)), thread if depth == 1 else thread.lerp(Color("31515c"), 0.6))
		for y in [5, 134]:
			draw_line(origin + Vector2(0, y), origin + Vector2(200, y), Color("967044"), 2)
		for x in range(0, 200, 12):
			draw_line(origin + Vector2(x, 0), origin + Vector2(x, -4), Color("a18150"), 1)
			draw_line(origin + Vector2(x, 140), origin + Vector2(x, 144), Color("a18150"), 1)
		_diamond(origin + Vector2(100, 70), 23, Color("876442"))
		_diamond(origin + Vector2(100, 70), 17, Color("49272c"))
	for room in rooms:
		var p := Vector2(room.get_center().x, room.position.y + 18)
		draw_line(p + Vector2(-40, -9), p + Vector2(40, -9), GOLD, 3)
		draw_colored_polygon(PackedVector2Array([p+Vector2(-32,-5),p+Vector2(32,-5),p+Vector2(32,74),p+Vector2(0,96),p+Vector2(-32,74)]), Color("642d36") if depth == 1 else Color("384c60"))
		for yy in range(0, 73, 3):
			for xx in range(-29, 30, 4):
				draw_rect(Rect2(p + Vector2(xx, yy), Vector2(1, 2)), Color(0.8, 0.6, 0.4, 0.10) if (xx + yy) % 3 else Color(0, 0, 0, 0.18))
		draw_line(p + Vector2(0, 12), p + Vector2(0, 66), BONE, 3)
		draw_line(p + Vector2(-14, 29), p + Vector2(14, 29), GOLD, 3)
		_diamond(p + Vector2(0, 69), 5, GOLD)
