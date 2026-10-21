extends Enemy
## A floating, shootable boss ward. No ordinary enemy membership or loot.
const Shot = preload("res://scripts/mvp_enemy_projectile.gd")
var anchor := Vector2.ZERO
var arena := Rect2()
var slot := 0
var clock := 0.0
var shot_cd := 3.0

func _init() -> void:
	collision_layer = 2
	collision_mask = 0
	max_hp = 38.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(36, 48)
	shape.shape = rect
	add_child(shape)
	var area := Area2D.new()
	area.name = "ContactArea"
	area.collision_layer = 0
	area.collision_mask = 0
	add_child(area)

func _ready() -> void:
	hp = max_hp
	cached_player = get_tree().get_first_node_in_group("player") as Player
	add_to_group("mvp_boss_pillars")
	shot_cd += slot * 0.8
	queue_redraw()

func _physics_process(delta: float) -> void:
	if dead:
		return
	clock += delta
	hit_flash = maxf(0, hit_flash - delta)
	if hit_flash <= 0:
		modulate = Color.WHITE
	var phase := clock * 1.1 + slot * PI * 0.5
	global_position = (anchor + Vector2(sin(phase) * 42, cos(phase * 0.8) * 24)).clamp(arena.position + Vector2(64, 64), arena.end - Vector2(64, 64))
	shot_cd -= delta
	if shot_cd <= 0.0:
		shot_cd = 4.6
		if is_instance_valid(cached_player) and not cached_player.dead:
			var shot := Shot.new()
			shot.setup(global_position.direction_to(cached_player.global_position), 9.0, 235.0, self)
			shot.position = global_position
			get_parent().add_child(shot)
	queue_redraw()

func _roll_drop() -> void:
	pass

func _draw() -> void:
	if dead:
		return
	draw_set_transform(Vector2(0, 34), 0, Vector2(1, 0.28))
	draw_circle(Vector2.ZERO, 27, Color(0, 0, 0, 0.6))
	draw_set_transform(Vector2.ZERO)
	var texture := preload("res://assets/sprites/wall.png")
	draw_texture_rect(texture, Rect2(-18, -24, 36, 48), false, Color("9bbfc0"))
	draw_rect(Rect2(-20, -26, 40, 6), Color("8e9b96"))
	draw_rect(Rect2(-20, 20, 40, 6), Color("536d72"))
	draw_line(Vector2(0, -16), Vector2(0, 13), Color("e5c781"), 3)
	draw_arc(Vector2.ZERO, 31, 0, TAU, 32, Color("6faaa8"), 1)
	if shot_cd < 0.8:
		draw_arc(Vector2.ZERO, 34, 0, TAU * (1 - shot_cd / 0.8), 24, Color("ed9a69"), 3)
	draw_rect(Rect2(-24, -37, 48, 4), Color("17232a"))
	draw_rect(Rect2(-24, -37, 48 * maxf(0, hp / max_hp), 4), Color("c9b47c"))
