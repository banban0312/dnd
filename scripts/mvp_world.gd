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
var room_names: Array[String] = []
var enemy_rooms: Array[int] = []
var enemy_roles: Array[String] = []
var hazard_positions: Array[Vector2] = []
var route_points: Array[Vector2] = []
var well_rect := Rect2()
var boss_gate_rect := Rect2()
var _walkable: Dictionary = {}
var _seed := 1
var _floors: Array[Rect2] = []
var _walls: Array[Rect2] = []
var _pillars: Array[Vector2] = []
var _stones: Array[Dictionary] = []
var _scratches: Array[PackedVector2Array] = []
var _lights: Array[Vector2] = []
var _cover_blocks: Array[Rect2] = []

const FLOOR_TEXTURE = preload("res://assets/sprites/floor.png")
const WALL_TEXTURE = preload("res://assets/sprites/wall.png")
const PILLAR_TEXTURE = preload("res://assets/sprites/pillar.png")

const INK := Color("10141c")
const MORTAR := Color("202630")
const GOLD := Color("d9a65c")
const BONE := Color("c3bca7")

class Flame extends Node2D:
	var cool := false
	var spectral := false
	var phase := 0.0
	var tick := 0.0

	func _process(delta: float) -> void:
		phase += delta
		tick += delta
		if tick > 0.08:
			tick = 0.0
			queue_redraw()

	func _draw() -> void:
		var hue := Color("c7a3f1") if spectral else (Color("7bc4b6") if cool else Color("edb963"))
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
	if depth == 1:
		map_size = Vector2(2528, 1440)
		rooms.assign([Rect2(96, 256, 576, 512), Rect2(832, 256, 640, 512), Rect2(1664, 256, 736, 608), Rect2(960, 960, 512, 352)])
		room_names.assign(["入口补给庭", "断旗交战厅", "绞盘守卫厅", "封印侧室 · 可选"])
		_floors.assign(rooms)
		# Two entrances into the central courtyard allow a flank against its archers.
		_floors.append_array([Rect2(640, 320, 224, 160), Rect2(640, 608, 224, 128), Rect2(1440, 416, 256, 192), Rect2(1152, 736, 192, 256), Rect2(1440, 1088, 160, 160), Rect2(1472, 544, 160, 704)])
		_cover_blocks.assign([Rect2(1088, 416, 128, 192)])
		player_spawn = Vector2(288, 512)
		boss_position = Vector2(2048, 480)
		exit_position = Vector2(2288, 768)
		chest_positions.assign([Vector2(544, 416), Vector2(1216, 1184)])
		enemy_positions.assign([Vector2(1008, 416), Vector2(1264, 656), Vector2(1376, 384), Vector2(1824, 704), Vector2(2208, 592), Vector2(1072, 1072), Vector2(1328, 1184), Vector2(1360, 1040)])
		enemy_rooms.assign([1, 1, 1, 2, 2, 3, 3, 3])
		enemy_roles.assign(["melee", "charger", "ranged", "charger", "ranged", "melee", "ranged", "charger"])
		_pillars.assign([Vector2(960, 320), Vector2(1376, 704)])
		_lights.assign([Vector2(160, 320), Vector2(608, 704), Vector2(896, 320), Vector2(1408, 704), Vector2(1728, 320), Vector2(2336, 800), Vector2(1024, 1248)])
		# Both paths merge west of one gate; the four-ward arena has no obstacles.
		well_rect = Rect2(1888, 1024, 224, 160)
		boss_gate_rect = Rect2(1632, 416, 32, 192)
		route_points.assign([player_spawn, Vector2(576, 400), Vector2(752, 400), Vector2(992, 352), Vector2(1280, 352), Vector2(1376, 512), Vector2(1568, 512), boss_position, Vector2(2048, 768), exit_position])
	elif depth == 2:
		map_size = Vector2(2528, 1600)
		rooms.assign([Rect2(96, 96, 576, 448), Rect2(832, 96, 704, 512), Rect2(1536, 864, 864, 608), Rect2(288, 736, 576, 448)])
		room_names.assign(["落井平台", "断桥外廊", "井环圣所", "遗骨祈祷室 · 可选"])
		_floors.assign(rooms)
		# The upper gallery and lower reward route reconnect on the west of the sanctuary.
		# The lower walkway wraps BELOW the shaft instead of drawing floor across it.
		_floors.append_array([Rect2(640, 256, 224, 192), Rect2(1280, 576, 192, 800), Rect2(1408, 864, 160, 192), Rect2(448, 512, 192, 256), Rect2(704, 1152, 160, 224), Rect2(832, 1216, 480, 160)])
		_cover_blocks.assign([Rect2(1056, 96, 96, 224), Rect2(1248, 416, 96, 192), Rect2(544, 864, 96, 128)])
		player_spawn = Vector2(288, 320)
		boss_position = Vector2(2016, 1152)
		exit_position = Vector2(2256, 1408)
		chest_positions.assign([Vector2(544, 224), Vector2(544, 1056)])
		enemy_positions.assign([Vector2(960, 256), Vector2(1184, 448), Vector2(1408, 224), Vector2(416, 832), Vector2(416, 1056), Vector2(736, 1024), Vector2(1728, 1024), Vector2(2224, 1328)])
		enemy_rooms.assign([1, 1, 1, 3, 3, 3, 2, 2])
		enemy_roles.assign(["ranged", "melee", "ranged", "charger", "melee", "charger", "ranged", "melee"])
		_pillars.assign([Vector2(928, 160), Vector2(1440, 544)])
		_lights.assign([Vector2(160, 160), Vector2(608, 480), Vector2(896, 160), Vector2(1472, 544), Vector2(352, 1120), Vector2(1600, 928), Vector2(2336, 1408)])
		well_rect = Rect2(960, 768, 224, 416)
		boss_gate_rect = Rect2(1504, 864, 32, 192)
		hazard_positions.assign([Vector2(1120, 352), Vector2(1840, 1328)])
		route_points.assign([player_spawn, Vector2(752, 352), Vector2(992, 352), Vector2(1184, 352), Vector2(1376, 352), Vector2(1376, 960), Vector2(1632, 960), boss_position])
	else:
		# An ascent through a split ossuary contrasts with the first two horizontal runs.
		map_size = Vector2(2816, 1856)
		rooms.assign([Rect2(96, 992, 576, 512), Rect2(832, 736, 736, 640), Rect2(1792, 192, 896, 768), Rect2(960, 1536, 576, 256)])
		room_names.assign(["余烬升降台", "白骨回庭", "缚星王座", "失名者骨库 · 可选"])
		_floors.assign(rooms)
		_floors.append_array([Rect2(640, 1152, 224, 192), Rect2(1536, 768, 288, 192), Rect2(1280, 1344, 192, 224), Rect2(768, 1600, 224, 128), Rect2(768, 1280, 160, 448)])
		_cover_blocks.assign([Rect2(960, 736, 96, 192), Rect2(1376, 1152, 96, 224)])
		player_spawn = Vector2(288, 1248)
		boss_position = Vector2(2240, 576)
		exit_position = Vector2(2560, 320)
		chest_positions.assign([Vector2(544, 1120), Vector2(1216, 1664)])
		enemy_positions.assign([Vector2(960, 1088), Vector2(1408, 896), Vector2(1200, 800), Vector2(1056, 1664), Vector2(1408, 1664), Vector2(1296, 1736), Vector2(1936, 768), Vector2(2496, 736)])
		enemy_rooms.assign([1, 1, 1, 3, 3, 3, 2, 2])
		enemy_roles.assign(["shieldbearer", "bone_weaver", "wisp", "shieldbearer", "wisp", "charger", "bone_weaver", "wisp"])
		_pillars.assign([Vector2(896, 800), Vector2(1504, 1312)])
		_lights.assign([Vector2(160, 1056), Vector2(608, 1440), Vector2(896, 1312), Vector2(1504, 800), Vector2(1024, 1728), Vector2(1856, 256), Vector2(2624, 896)])
		well_rect = Rect2(1120, 928, 160, 224)
		boss_gate_rect = Rect2(1760, 768, 32, 192)
		hazard_positions.assign([Vector2(1280, 1248), Vector2(2400, 800)])
		route_points.assign([player_spawn, Vector2(752, 1248), Vector2(1024, 1248), Vector2(1312, 1248), Vector2(1312, 1024), Vector2(1440, 864), Vector2(1696, 864), Vector2(1856, 864), boss_position, exit_position])
	# A union of snapped floor cells generates both visible walls and collision.
	# Doorways and optional loops therefore cannot disagree with the floor art.
	_build_boundaries()
	_collision(well_rect)
	for cover in _cover_blocks:
		_wall(cover)
	for p in _pillars:
		_collision(Rect2(p - Vector2(22, 19), Vector2(44, 38)))
	for p in _lights:
		var flame := Flame.new()
		flame.position = p
		flame.cool = depth > 1 and int(p.x) % 3 != 0
		flame.spectral = depth == 3
		add_child(flame)
	_prepare_surface()
	for i in rooms.size():
		var label := Label.new()
		label.text = room_names[i]
		label.position = rooms[i].position + Vector2(40, 112)
		label.add_theme_font_size_override("font_size", 16)
		label.add_theme_color_override("font_color", Color("b6a17c") if depth == 1 else Color("8ba9ad"))
		label.add_theme_constant_override("outline_size", 5)
		label.add_theme_color_override("font_outline_color", INK)
		add_child(label)
	queue_redraw()


func _build_boundaries() -> void:
	for rect in _floors:
		for y in range(int(rect.position.y / 32), int(rect.end.y / 32)):
			for x in range(int(rect.position.x / 32), int(rect.end.x / 32)):
				var center := Vector2(x * 32 + 16, y * 32 + 16)
				var blocked := well_rect.has_point(center)
				for cover in _cover_blocks:
					blocked = blocked or cover.has_point(center)
				if not blocked:
					_walkable[Vector2i(x, y)] = true
	var boundary: Dictionary = {}
	for cell: Vector2i in _walkable:
		for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
			var neighbor: Vector2i = cell + offset
			if not _walkable.has(neighbor):
				boundary[neighbor] = true
	for cell: Vector2i in boundary:
		_wall(Rect2(Vector2(cell) * 32, Vector2(32, 32)))


func room_at(point: Vector2) -> int:
	for i in rooms.size():
		if rooms[i].has_point(point):
			return i
	return -1


func is_walkable(point: Vector2) -> bool:
	return _walkable.has(Vector2i(floori(point.x / 32), floori(point.y / 32)))


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
				var tint := Color("342e40") if depth == 3 else (Color("303640") if depth == 1 else Color("29363b"))
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
		draw_texture_rect(FLOOR_TEXTURE, rect, false, Color("bdb0cc") if depth == 3 else (Color("c8bbaa") if depth == 1 else Color("9fbbb6")))
		draw_rect(rect, Color(tint, 0.68))
		draw_line(rect.position, rect.position + Vector2(rect.size.x, 0), tint.lightened(0.045), 1)
		if stone.scar:
			draw_line(rect.position + Vector2(8, 8), rect.position + Vector2(15, 8), tint.darkened(0.19), 2)
	# A deliberate inlaid navigation spine makes the connection between rooms legible.
	for room in rooms:
		draw_rect(Rect2(room.position + Vector2(24, 24), room.size - Vector2(48, 48)), Color("4b4c49") if depth == 1 else Color("42514f"), false, 2)
		draw_rect(Rect2(room.position + Vector2(32, 32), room.size - Vector2(64, 64)), Color("363c42"), false, 1)
		for corner in [room.position + Vector2(24, 24), Vector2(room.end.x - 24, room.position.y + 24), room.end - Vector2(24, 24), Vector2(room.position.x + 24, room.end.y - 24)]:
			_diamond(corner, 5, Color("77664b") if depth == 1 else Color("5d7871"))
	_heraldry()
	_draw_tactical_marks()
	# Chamber floor seals are restrained, so arrows and enemies retain contrast.
	_seal(player_spawn + Vector2(64, 0), 72, Color("776747"), false)
	_seal(rooms[1].get_center(), 92, Color("49525a"), false)
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
	_draw_well()
	_exit_arch()
	# Bones/debris stay along edges, never in a doorway or under combatants.
	for room in rooms:
		_debris(room.end - Vector2(90, 55))
	# Gentle edge occlusion gives the chambers volume while leaving the center readable.
	for room in rooms:
		for i in range(5):
			var alpha := 0.025 * float(5 - i)
			draw_rect(Rect2(room.position + Vector2(0, i * 5), Vector2(room.size.x, 5)), Color(0, 0, 0, alpha))
			draw_rect(Rect2(room.position + Vector2(i * 5, 0), Vector2(5, room.size.y)), Color(0, 0, 0, alpha * 0.7))


func _draw_tactical_marks() -> void:
	# Small repeated inlays mark route choices without covering combat telegraphs.
	var paths: Array[PackedVector2Array] = []
	if depth == 1:
		paths.append(PackedVector2Array([Vector2(560, 432), Vector2(752, 400), Vector2(960, 400)]))
		paths.append(PackedVector2Array([Vector2(560, 656), Vector2(752, 672), Vector2(960, 672)]))
		paths.append(PackedVector2Array([Vector2(1248, 800), Vector2(1248, 928)]))
		paths.append(PackedVector2Array([Vector2(1504, 1168), Vector2(1552, 1168), Vector2(1552, 656)]))
	elif depth == 2:
		paths.append(PackedVector2Array([Vector2(688, 352), Vector2(800, 352)]))
		paths.append(PackedVector2Array([Vector2(544, 576), Vector2(544, 688)]))
		paths.append(PackedVector2Array([Vector2(784, 1200), Vector2(784, 1296), Vector2(1376, 1296), Vector2(1376, 1104)]))
	else:
		paths.append(PackedVector2Array([Vector2(688, 1248), Vector2(1024, 1248), Vector2(1312, 1248), Vector2(1312, 896), Vector2(1696, 864)]))
		paths.append(PackedVector2Array([Vector2(1376, 1424), Vector2(1376, 1504)]))
		paths.append(PackedVector2Array([Vector2(928, 1664), Vector2(848, 1664), Vector2(848, 1408)]))
		# Rib-like ivory inlays frame the court while keeping its two traversal arcs clear.
		for y in range(800, 1344, 64):
			for x in [864, 1536]:
				draw_line(Vector2(x, y), Vector2(x + (18 if x == 864 else -18), y - 14), Color("9b929a", 0.65), 3)
		_seal(boss_position, 240, Color("9279ac"), true)
		_seal(boss_position, 204, Color("72668b"), false)
	for path in paths:
		for segment in range(path.size() - 1):
			var start: Vector2 = path[segment]
			var finish: Vector2 = path[segment + 1]
			var distance := start.distance_to(finish)
			var direction := start.direction_to(finish)
			for step in range(0, int(distance), 40):
				var p := start + direction * float(step)
				_diamond(p, 3, Color("a390bb") if depth == 3 else (Color("9a8055") if depth == 1 else Color("5c9291")))
	# The large empty sanctuary floor is a deliberate four-column combat arena.
	if depth == 1:
		for offset in [Vector2(-240, -128), Vector2(240, -128), Vector2(-240, 128), Vector2(240, 128)]:
			_seal(rooms[2].get_center() + offset, 36, Color("617c7b"), false)
	if depth > 1:
		for i in range(3):
			draw_rect(well_rect.grow(22 + i * 7), Color("527774", 0.35 - i * 0.08), false, 2)


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
	var origin := player_spawn - Vector2(144, 0)
	for i in range(6):
		draw_rect(Rect2(origin + Vector2(i * 14, -45), Vector2(12, 90)), Color("242b34").lightened(float(i) * 0.018))
		draw_line(origin + Vector2(i * 14 + 1, -45), origin + Vector2(i * 14 + 1, 45), Color("58606b"), 2)
	for y in [-58, 55]:
		draw_rect(Rect2(origin + Vector2(-4, y), Vector2(98, 3)), Color("776344"))


func _draw_well() -> void:
	# Layered stone and receding chain make the shaft part of the playable world.
	var rim := well_rect.grow(16)
	draw_rect(rim, Color("0c1016"))
	for i in range(5):
		var inset := float(i) * 9.0
		var band := Rect2(well_rect.position + Vector2(inset, inset), well_rect.size - Vector2(inset * 2, inset * 2))
		if band.size.y <= 0:
			break
		draw_texture_rect(WALL_TEXTURE, band, true, Color("676655").darkened(float(i) * 0.14))
		draw_rect(band.grow(-5), Color("0b131c").lightened(float(4 - i) * 0.012))
	for x in [rim.position.x, rim.end.x - 16]:
		draw_texture_rect(WALL_TEXTURE, Rect2(x, rim.position.y, 16, rim.size.y), true, Color("9d937f"))
	for y in [rim.position.y, rim.end.y - 16]:
		draw_texture_rect(WALL_TEXTURE, Rect2(rim.position.x, y, rim.size.x, 16), true, Color("9d937f"))
	var center := well_rect.get_center()
	for x in [center.x - 46, center.x + 46]:
		for y in range(int(well_rect.position.y) + 8, int(well_rect.end.y) - 8, 12):
			draw_rect(Rect2(x, y, 5, 9), Color("7d827c").darkened(float(y - well_rect.position.y) / maxf(1, well_rect.size.y) * 0.7), false, 1)
	draw_line(Vector2(center.x - 72, rim.position.y - 5), Vector2(center.x + 72, rim.position.y - 5), Color("6e6251"), 7)
	draw_arc(Vector2(center.x, rim.position.y - 5), 19, 0, TAU, 20, GOLD.darkened(0.35), 4)


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
	for i in range(3):
		var origin: Vector2 = rooms[i].get_center() - Vector2(100, 70)
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
