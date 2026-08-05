extends Node2D
class_name MapGenerator
## 地图生成器:由固定大小箱庭(房间)组成的网格地图。
## 相邻房间之间随机开口(保证全连通),每个房间内随机生成路障(石柱 / 墙块)。

const WALL_TEX: Texture2D = preload("res://assets/sprites/wall.png")
const FLOOR_TEX: Texture2D = preload("res://assets/sprites/floor.png")
const PILLAR_TEX: Texture2D = preload("res://assets/sprites/pillar.png")

class RoomData:
	var rect: Rect2
	var top_door_x: float = -1.0
	var bottom_door_x: float = -1.0
	var left_door_y: float = -1.0
	var right_door_y: float = -1.0

	func _init(p_rect: Rect2) -> void:
		rect = p_rect


@export var room_size := Vector2(960, 720)
@export var grid_cols := 3
@export var grid_rows := 3
@export var wall_thickness := 40.0
@export var door_width := 110.0
@export var min_obstacles := 2
@export var max_obstacles := 5
@export var obstacle_margin := 70.0
@export var chest_chance := 0.7
@export var enemy_points_per_room := 4
@export var rng_seed := 0

var rng := RandomNumberGenerator.new()
var rooms: Array[RoomData] = []

## 本次生成实际使用的种子(0=随机时取随机值),供存档复现同一张地图
var used_seed := 0

## 生成结果(供主场景使用)
var map_size := Vector2.ZERO
var player_spawn := Vector2.ZERO
var save_point_pos := Vector2.ZERO
var enemy_points: Array[Vector2] = []
var patrol_targets: Array[Vector2] = []
var chest_points: Array[Vector2] = []

## 调试/验证用数据
var wall_segments: Array[Rect2] = []
var obstacle_rects: Array[Rect2] = []
var door_centers: Array[Vector2] = []


func generate() -> void:
	if rng_seed == 0:
		rng.randomize()
		used_seed = rng.randi()
	else:
		rng.seed = rng_seed
		used_seed = rng_seed

	_clear_generated()
	rooms.clear()
	_assign_doors()
	_build_floors()
	_build_walls()
	_place_obstacles()
	_compute_points()


func _clear_generated() -> void:
	for child in get_children():
		child.queue_free()
	wall_segments.clear()
	obstacle_rects.clear()
	door_centers.clear()
	enemy_points.clear()
	patrol_targets.clear()
	chest_points.clear()


func _assign_doors() -> void:
	# 建立房间网格
	for r in grid_rows:
		for c in grid_cols:
			rooms.append(RoomData.new(Rect2(c * room_size.x, r * room_size.y, room_size.x, room_size.y)))

	# 内部水平边(房间 r 与 r+1 之间的墙):随机开一个门
	for r in grid_rows - 1:
		for c in grid_cols:
			var door_x := rng.randf_range(door_width * 0.5 + 60.0, room_size.x - door_width * 0.5 - 60.0)
			rooms[r * grid_cols + c].bottom_door_x = door_x
			rooms[(r + 1) * grid_cols + c].top_door_x = door_x
	# 内部垂直边(房间 c 与 c+1 之间的墙)
	for r in grid_rows:
		for c in grid_cols - 1:
			var door_y := rng.randf_range(door_width * 0.5 + 60.0, room_size.y - door_width * 0.5 - 60.0)
			rooms[r * grid_cols + c].right_door_y = door_y
			rooms[r * grid_cols + c + 1].left_door_y = door_y

	map_size = Vector2(grid_cols * room_size.x, grid_rows * room_size.y)


func _build_floors() -> void:
	for room in rooms:
		var floor := Sprite2D.new()
		floor.texture = FLOOR_TEX
		floor.position = room.rect.get_center()
		floor.region_enabled = true
		floor.region_rect = Rect2(0, 0, room_size.x, room_size.y)
		floor.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
		floor.z_index = -10
		add_child(floor)


func _build_walls() -> void:
	var th := wall_thickness
	for room in rooms:
		var gx := room.rect.position.x
		var gy := room.rect.position.y
		# 顶墙:仅最外一排生成(内部共享边由上方房间的底墙负责)
		if gy == 0.0:
			_add_wall_segment(Vector2(gx + room_size.x * 0.5, gy), Vector2(room_size.x + th, th))
		# 底墙:每排都生成(带门洞)
		if room.bottom_door_x < 0.0:
			_add_wall_segment(Vector2(gx + room_size.x * 0.5, gy + room_size.y), Vector2(room_size.x + th, th))
		else:
			_add_wall_with_h_gap(Vector2(gx, gy + room_size.y), room_size.x + th, th, room.bottom_door_x)
		# 左墙:仅最外一列生成
		if gx == 0.0:
			_add_wall_segment(Vector2(gx, gy + room_size.y * 0.5), Vector2(th, room_size.y + th))
		# 右墙:每列都生成(带门洞)
		if room.right_door_y < 0.0:
			_add_wall_segment(Vector2(gx + room_size.x, gy + room_size.y * 0.5), Vector2(th, room_size.y + th))
		else:
			_add_wall_with_v_gap(Vector2(gx + room_size.x, gy), th, room_size.y + th, room.right_door_y)


## 水平墙段:起点 pos 为矩形左上角(含开洞),len 为总长(含两端延伸),th 为厚度
func _add_wall_with_h_gap(pos: Vector2, len: float, th: float, door_center_x: float) -> void:
	var gap_half := door_width * 0.5
	var left_w := door_center_x - gap_half
	var right_start := door_center_x + gap_half
	var right_w := len - right_start
	_add_wall_segment(pos + Vector2(left_w * 0.5, th * 0.5), Vector2(left_w, th))
	_add_wall_segment(pos + Vector2(right_start + right_w * 0.5, th * 0.5), Vector2(right_w, th))
	door_centers.append(pos + Vector2(door_center_x, th * 0.5))


func _add_wall_with_v_gap(pos: Vector2, th: float, len: float, door_center_y: float) -> void:
	var gap_half := door_width * 0.5
	var top_w := door_center_y - gap_half
	var bottom_start := door_center_y + gap_half
	var bottom_w := len - bottom_start
	_add_wall_segment(pos + Vector2(th * 0.5, top_w * 0.5), Vector2(th, top_w))
	_add_wall_segment(pos + Vector2(th * 0.5, bottom_start + bottom_w * 0.5), Vector2(th, bottom_w))
	door_centers.append(pos + Vector2(th * 0.5, door_center_y))


## 生成一段墙:中心 pos,尺寸 size(碰撞与视觉一致)
func _add_wall_segment(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := Sprite2D.new()
	visual.texture = WALL_TEX
	visual.region_enabled = true
	visual.region_rect = Rect2(0, 0, size.x, size.y)
	visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	body.add_child(visual)
	wall_segments.append(Rect2(pos - size * 0.5, size))


func _place_obstacles() -> void:
	var spawn_room := rooms[grid_cols * (grid_rows / 2) + grid_cols / 2]
	for room in rooms:
		var count := rng.randi_range(min_obstacles, max_obstacles)
		for i in count:
			var type_index := rng.randi_range(0, 2)
			var size: Vector2
			match type_index:
				0:
					size = Vector2(48, 48)
				1:
					size = Vector2(120, 40)
				_:
					size = Vector2(40, 120)
			var avoid: Array[Rect2] = obstacle_rects.duplicate()
			if room == spawn_room:
				avoid.append(Rect2(spawn_room.rect.get_center() - Vector2(140, 140), Vector2(280, 280)))
			var p := _random_room_point(room, obstacle_margin + maxf(size.x, size.y) * 0.5, avoid)
			_add_obstacle(p, size, type_index)


func _add_obstacle(pos: Vector2, size: Vector2, type_index: int) -> void:
	var body := StaticBody2D.new()
	body.position = pos
	add_child(body)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := Sprite2D.new()
	if type_index == 0:
		visual.texture = PILLAR_TEX
		visual.scale = Vector2.ONE * (size.x / 32.0)
	else:
		visual.texture = WALL_TEX
		visual.region_enabled = true
		visual.region_rect = Rect2(0, 0, size.x, size.y)
		visual.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	body.add_child(visual)
	obstacle_rects.append(Rect2(pos - size * 0.5, size))


## 在房间内随机找一个安全点(避开门口通道与指定矩形)
func _random_room_point(room: RoomData, clearance: float, avoid: Array[Rect2]) -> Vector2:
	for i in 80:
		var p := Vector2(
			room.rect.position.x + rng.randf_range(clearance, room_size.x - clearance),
			room.rect.position.y + rng.randf_range(clearance, room_size.y - clearance)
		)
		if _near_any_door(room, p, 70.0):
			continue
		var hit_avoid := false
		for rect in avoid:
			if Rect2(p - Vector2(clearance, clearance), Vector2(clearance * 2, clearance * 2)).intersects(rect):
				hit_avoid = true
				break
		if hit_avoid:
			continue
		return p
	return room.rect.get_center()


func _near_any_door(room: RoomData, p: Vector2, radius: float) -> bool:
	var gx := room.rect.position.x
	var gy := room.rect.position.y
	if room.top_door_x >= 0.0 and absf(p.y - gy) < radius and absf(p.x - (gx + room.top_door_x)) < radius:
		return true
	if room.bottom_door_x >= 0.0 and absf(p.y - (gy + room_size.y)) < radius and absf(p.x - (gx + room.bottom_door_x)) < radius:
		return true
	if room.left_door_y >= 0.0 and absf(p.x - gx) < radius and absf(p.y - (gy + room.left_door_y)) < radius:
		return true
	if room.right_door_y >= 0.0 and absf(p.x - (gx + room_size.x)) < radius and absf(p.y - (gy + room.right_door_y)) < radius:
		return true
	return false


func _compute_points() -> void:
	# 出生点:中央房间中心
	var center_room := rooms[grid_cols * (grid_rows / 2) + grid_cols / 2]
	player_spawn = center_room.rect.get_center()
	save_point_pos = center_room.rect.get_center()

	# 每房间生成若干敌人出生点与宝箱点
	for room in rooms:
		var avoid: Array[Rect2] = obstacle_rects.duplicate()
		if room == center_room:
			avoid.append(Rect2(player_spawn - Vector2(120, 120), Vector2(240, 240)))
		for i in enemy_points_per_room:
			enemy_points.append(_random_room_point(room, 80.0, avoid))
			patrol_targets.append(_random_room_point(room, 80.0, avoid))
		if rng.randf() < chest_chance:
			chest_points.append(_random_room_point(room, 90.0, avoid))
