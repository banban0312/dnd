extends CharacterBody2D
## Slow, straight bone sparks. Each spark owns its lifetime and physical hit.
const LIMIT := 160
signal blossomed(petals: Array)
var direction := Vector2.RIGHT
var speed := 165.0
var damage := 11.0
var lifetime := 0.0
var source_actor: Node
var is_seed := false
var is_petal := false
var seed_state := "flight"
var seed_time := 0.0
var burst_count := 0
const SEED_FLIGHT := 0.9
const SEED_WARNING := 0.45

func setup(aim: Vector2, amount: float, velocity_speed: float, source: Node) -> void:
	direction = aim.normalized()
	damage = amount
	speed = velocity_speed
	source_actor = source

func _ready() -> void:
	if get_tree().get_nodes_in_group("necromancer_projectiles").size() >= LIMIT:
		queue_free()
		return
	add_to_group("enemy_projectiles")
	add_to_group("necromancer_projectiles")
	collision_layer = 0
	collision_mask = 1
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(9, 9)
	collision.shape = rectangle
	add_child(collision)
	rotation = direction.angle()

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= 6.0 or not is_instance_valid(source_actor) or source_actor.dead or source_actor.shielded:
		queue_free()
		return
	if is_seed and seed_state == "warning":
		seed_time += delta
		queue_redraw()
		if seed_time >= SEED_WARNING:
			_blossom()
		return
	if is_seed and seed_state == "spent":
		return
	var travel_delta := delta
	if is_seed:
		travel_delta = minf(delta, maxf(0.0, SEED_FLIGHT - seed_time))
		seed_time += delta
	var hit := move_and_collide(direction * speed * travel_delta)
	if hit != null:
		var target := hit.get_collider()
		if target is Player:
			target.take_damage(damage, source_actor)
		queue_free()
		return
	if is_seed and seed_time >= SEED_FLIGHT:
		seed_state = "warning"
		seed_time = 0.0
		queue_redraw()

func _blossom() -> void:
	if not is_seed or seed_state == "spent" or burst_count > 0:
		return
	if is_queued_for_deletion() or not is_instance_valid(source_actor) or source_actor.dead or source_actor.shielded:
		queue_free()
		return
	burst_count += 1
	seed_state = "spent"
	var existing := get_tree().get_nodes_in_group("necromancer_projectiles").size()
	var petals: Array = []
	for blade in 8:
		# Pairs make eight open, forked petals. Wide spaces between petals remain passable.
		for split in [-0.07, 0.07]:
			if existing >= LIMIT:
				break
			var petal = get_script().new()
			petal.setup(direction.rotated(blade * TAU / 8.0 + split), damage, 135.0, source_actor)
			petal.is_petal = true
			petal.position = global_position
			get_parent().add_child(petal)
			petals.append(petal)
			existing += 1
	blossomed.emit(petals)
	queue_free()

func _draw() -> void:
	# Hard pixel edges, no blur, additive glow, or smooth gradient.
	if is_seed:
		var radius := 12.0
		if seed_state == "warning":
			radius = 16.0 + floorf(clampf(seed_time / SEED_WARNING, 0, 1) * 4.0) * 4.0
		for blade in 8:
			var outward := Vector2.RIGHT.rotated(blade * TAU / 8.0)
			var sideways := outward.orthogonal()
			var tip := (outward * radius / 2.0).round() * 2.0
			var left := (outward * radius * 0.4 + sideways * 4.0).round()
			var right := (outward * radius * 0.4 - sideways * 4.0).round()
			draw_colored_polygon(PackedVector2Array([Vector2.ZERO, left, tip, right]), Color("b69a63") if seed_state == "warning" else Color("526f69"))
		draw_rect(Rect2(-6, -6, 12, 12), Color("203c42"))
		draw_rect(Rect2(-4, -4, 8, 8), Color("d7cdb0"))
		draw_rect(Rect2(-2, -2, 4, 4), Color("f0e4c3") if seed_state == "warning" else Color("83b8a0"))
		return
	draw_rect(Rect2(-8, -3, 13, 6), Color("203c42"))
	draw_rect(Rect2(-5, -4, 9, 8), Color("b69a63") if is_petal else Color("6eaaa0"))
	draw_rect(Rect2(-3, -2, 6, 4), Color("d4d9b2"))
	draw_rect(Rect2(3, -1, 3, 2), Color("f1dfab"))
