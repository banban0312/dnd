extends SceneTree
## Real CharacterBody2D contact cases; inputs are physical keys, not teleports.
var failures: Array[String] = []
var arena: Node2D
var player
var foe
var records: Array[Dictionary] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	arena = Node2D.new()
	root.add_child(arena)
	for role in ["melee", "ranged", "charger", "shieldbearer", "bone_weaver", "wisp", "summoned_skeleton"]:
		for side in [-1, 1]:
			for escape in ["reverse", "diagonal", "dodge"]:
				await _contact_case(role, escape, side)
	await _collision_preservation_checks()
	var report := FileAccess.open("res://_test/contact-escape-records.json", FileAccess.WRITE)
	report.store_string(JSON.stringify(records, "  "))
	report.close()
	arena.queue_free()
	await process_frame
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("MVP CONTACT ESCAPE OK: seven roles, both contact sides, reverse/diagonal/Space, no actor platform carry, walls/arrows/charge damage")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _contact_case(role: String, escape: String, side: int) -> void:
	for key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_SPACE]:
		Input.parse_input_event(_key(key, false))
	if is_instance_valid(player):
		player.queue_free()
		await process_frame
		await physics_frame
	player = load("res://scripts/player.gd").new()
	player.position = Vector2(500, 500)
	player.collision_layer = 1
	player.collision_mask = 3
	_add_body(player)
	arena.add_child(player)
	player.invuln_timer = 1000
	player.set_physics_process(false)
	player.velocity = Vector2.ZERO
	player.dodge_timer = 0
	player.dodge_cd = 0
	var special := role in ["shieldbearer", "bone_weaver", "wisp", "summoned_skeleton"]
	foe = load("res://scripts/mvp_special_enemy.gd" if special else "res://scripts/mvp_enemy.gd").new()
	foe.role = role
	foe.position = Vector2(500, 500 + side * 26.2)
	foe.collision_layer = 2
	foe.collision_mask = 3
	_add_body(foe)
	var area := Area2D.new()
	area.name = "ContactArea"
	area.collision_mask = 0
	foe.add_child(area)
	arena.add_child(foe)
	foe.acquire_aggro()
	foe.attack_cd = 100
	await physics_frame
	await physics_frame
	var distance_before: float = player.position.distance_to(foe.position)
	var enemy_start: Vector2 = foe.position
	var player_start: Vector2 = player.position
	player.set_physics_process(true)
	Input.parse_input_event(_key(KEY_D, true))
	if escape == "diagonal":
		Input.parse_input_event(_key(KEY_S if side == -1 else KEY_W, true))
	elif escape == "dodge":
		Input.parse_input_event(_key(KEY_SPACE, true))
	var max_platform := 0.0
	var player_platform := 0.0
	for frame in 38:
		await physics_frame
		max_platform = maxf(max_platform, foe.get_platform_velocity().length())
		player_platform = maxf(player_platform, player.get_platform_velocity().length())
	var distance_after: float = player.position.distance_to(foe.position)
	var measured_speed: float = foe.get_real_velocity().length()
	records.append({"role": role, "escape": escape, "side": side, "player_platform_speed": player_platform, "before": distance_before, "after": distance_after, "platform_speed": max_platform, "enemy_displacement": foe.position.distance_to(enemy_start), "player_displacement": player.position.distance_to(player_start), "enemy_real_speed": measured_speed, "enemy_requested_speed": foe.velocity.length()})
	print("CONTACT %s/%s/side%d distance %.1f -> %.1f platform enemy %.1f player %.1f" % [role, escape, side, distance_before, distance_after, max_platform, player_platform])
	_check(distance_after > distance_before + 45, role + "/" + escape + " gains separation from physical contact")
	_check(max_platform < 1, role + "/" + escape + " does not inherit moving player as a platform")
	_check(player_platform < 1, role + "/" + escape + " player does not inherit moving enemy as a platform")
	for key in [KEY_D, KEY_W, KEY_S, KEY_SPACE]:
		Input.parse_input_event(_key(key, false))
	player.set_physics_process(false)
	foe.queue_free()
	await process_frame

func _add_body(body: CharacterBody2D) -> void:
	var shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(26, 26)
	shape.shape = box
	body.add_child(shape)
	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	body.add_child(visual)

func _key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _collision_preservation_checks() -> void:
	var wall := StaticBody2D.new()
	wall.position = Vector2(650, 500)
	wall.collision_layer = 1
	var wall_shape := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = Vector2(20, 200)
	wall_shape.shape = box
	wall.add_child(wall_shape)
	arena.add_child(wall)
	player.position = Vector2(500, 500)
	player.velocity = Vector2.ZERO
	player.dodge_timer = 0
	player.set_physics_process(true)
	Input.parse_input_event(_key(KEY_D, true))
	for frame in 45:
		await physics_frame
	Input.parse_input_event(_key(KEY_D, false))
	player.set_physics_process(false)
	_check(player.position.x > 600 and player.position.x < 628, "Player still collides with the physical wall")
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 7)
	arrow.position = Vector2(550, 500)
	arena.add_child(arrow)
	for frame in 20:
		await physics_frame
	_check(not is_instance_valid(arrow), "Arrow still stops at a physical wall")
	foe = load("res://scripts/mvp_enemy.gd").new()
	foe.role = "charger"
	foe.position = Vector2(600, 200)
	foe.collision_layer = 2
	foe.collision_mask = 3
	_add_body(foe)
	var area := Area2D.new()
	area.name = "ContactArea"
	area.collision_mask = 0
	foe.add_child(area)
	arena.add_child(foe)
	foe.set_physics_process(false)
	var shot = load("res://scripts/arrow.gd").new()
	shot.setup(Vector2.RIGHT, 7)
	shot.position = Vector2(500, 200)
	arena.add_child(shot)
	for frame in 20:
		await physics_frame
	_check(is_equal_approx(foe.hp, foe.max_hp - 7), "Physical arrow still damages enemy collision layer")
	player.position = Vector2(670, 200)
	player.hp = player.max_hp
	player.invuln_timer = 0
	foe.position = Vector2(600, 200)
	foe.acquire_aggro()
	foe.locked_direction = Vector2.RIGHT
	foe.attack_state = foe.AttackState.DASH
	foe.state_time = 0.35
	foe.attack_hit = false
	foe.contact_damage = 12
	foe.set_physics_process(true)
	for frame in 16:
		await physics_frame
	_check(player.hp < player.max_hp, "Charger dash still physically hits and damages the player")
	foe.queue_free()
	wall.queue_free()
	await process_frame
