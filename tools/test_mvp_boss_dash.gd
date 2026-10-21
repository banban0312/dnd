extends SceneTree
## Actual 58x58 boss versus 26x26 player collision; do not replace with distance mocks.
## Run: Godot --headless --path . --script res://tools/test_mvp_boss_dash.gd

var failures: Array[String] = []
var game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.depth = 1
	game._build_floor()
	game.set_process(false)
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	await _arena_checks()
	await _dash_case("cardinal_hit_once", Vector2.RIGHT, 0.0, false, false)
	await _dash_case("diagonal_hit_once", Vector2(1, 1).normalized(), 0.0, false, false)
	await _dash_case("outside_warning", Vector2.RIGHT, 80.0, false, false)
	await _dash_case("wall_blocks", Vector2.RIGHT, 0.0, true, false)
	await _dash_case("dodge_invulnerability", Vector2.RIGHT, 0.0, false, true)
	game.queue_free()
	await process_frame
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("MVP BOSS DASH OK: cardinal/diagonal physical hit once, outside warning safe, wall blocks, dodge invulnerability")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _arena_checks() -> void:
	var boss = game.boss
	game.player.position = Vector2(game.world.boss_gate_rect.position.x - 24, game.world.boss_gate_rect.get_center().y)
	game._process(0.0)
	_check(not boss.can_be_shot() and not is_instance_valid(game.arena_gate), "Boss is sealed before crossing the inner threshold")
	_check(not boss.arena_active and not boss.provoked, "Querying sealed Boss vulnerability does not awaken or provoke it")
	var hp_before: float = boss.hp
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 1000.0, 700.0, 1)
	arrow.position = boss.position - Vector2(150, 0)
	game.add_child(arrow)
	for frame in range(25):
		await physics_frame
	_check(is_equal_approx(boss.hp, hp_before), "A real arrow cannot damage the sealed boss")
	_check(not is_instance_valid(arrow), "The sealed boss terminates the incoming real arrow")
	_check(boss.arena_active and boss.provoked, "A real sealed hit still awakens and provokes Boss")
	_check(not boss.can_be_shot() and not is_instance_valid(game.arena_gate), "Awakened Boss stays protected from shooter outside arena without locking player out")
	var repeat_arrow = load("res://scripts/arrow.gd").new()
	repeat_arrow.setup(Vector2.RIGHT, 1000.0, 700.0, 1)
	repeat_arrow.position = boss.position - Vector2(150, 0)
	game.add_child(repeat_arrow)
	for frame in range(25):
		await physics_frame
	_check(is_equal_approx(boss.hp, hp_before) and not is_instance_valid(repeat_arrow), "Repeated arrows from outside arena cannot damage an awakened Boss")
	game.player.position = game.world.rooms[2].position + Vector2(96, 128)
	game._process(0.0)
	_check(boss.can_be_shot() and is_instance_valid(game.arena_gate), "Entering the inner platform awakens boss and creates gate")
	var inside_arrow = load("res://scripts/arrow.gd").new()
	inside_arrow.setup(Vector2.RIGHT, 10.0, 700.0)
	inside_arrow.position = boss.position - Vector2(150, 0)
	game.add_child(inside_arrow)
	for frame in range(25):
		await physics_frame
	_check(is_equal_approx(boss.hp, hp_before - 10.0), "Entering arena allows real player arrows to damage Boss")
	await physics_frame
	await physics_frame
	var gate_center: Vector2 = game.world.boss_gate_rect.get_center()
	var ray := PhysicsRayQueryParameters2D.create(gate_center - Vector2(60, 0), gate_center + Vector2(60, 0), 1)
	ray.exclude = [game.player.get_rid()]
	var collision: Dictionary = game.get_world_2d().direct_space_state.intersect_ray(ray)
	_check(not collision.is_empty() and collision.get("collider") == game.arena_gate, "The visible gate has collision across the open doorway")
	game.player.position = gate_center + Vector2(80, 0)
	for frame in range(30):
		game.player.velocity = Vector2(-240, 0)
		game.player.move_and_slide()
		await physics_frame
	_check(game.player.position.x >= game.world.boss_gate_rect.end.x + 12.0, "A real 26px player body cannot walk back through the locked gate")
	print("BOSS_ARENA sealed_arrow=provokes_no_damage outside_repeat=blocked inside_arrow=damages gate_ray=blocked player_exit=blocked")

func _dash_case(label: String, direction: Vector2, lateral: float, wall_blocks: bool, invulnerable: bool) -> void:
	var boss = game.boss
	var player = game.player
	var origin: Vector2 = game.world.boss_position
	boss.awaken()
	boss._cancel_attack()
	boss.returning_home = false
	boss.global_position = origin
	boss.home_position = origin
	boss.velocity = Vector2.ZERO
	player.global_position = origin + direction * 150.0
	player.velocity = Vector2.ZERO
	player.hp = player.max_hp
	player.invuln_timer = 0.0
	player.dodge_cd = 0.0
	player.dodge_timer = 0.0
	player.blocking = false
	boss.boss_move_index = 1
	boss._begin_attack(player)
	# Move after the windup locks its direction, just as a player evades the warning.
	player.global_position += direction.orthogonal() * lateral
	var barrier: StaticBody2D
	if wall_blocks:
		barrier = StaticBody2D.new()
		barrier.position = origin + Vector2(74, 0)
		barrier.collision_layer = 1
		barrier.collision_mask = 0
		var collider := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(16, 180)
		collider.shape = rectangle
		barrier.add_child(collider)
		game.contents.add_child(barrier)
	await physics_frame
	await physics_frame
	var before: float = player.hp
	var expected_damage: float = player._incoming_damage(boss.contact_damage)
	for frame in range(90):
		if invulnerable:
			if frame == 48:
				# Exercise actual roll invulnerability at the end of the 0.8s warning.
				player._try_dodge(Vector2.UP)
			player._tick_timers(1.0 / 60.0)
		boss._physics_process(1.0 / 60.0)
		await physics_frame
	var damage: float = before - player.hp
	if lateral > 0.0 or wall_blocks or invulnerable:
		_check(is_zero_approx(damage), label + " should not damage the player")
	else:
		_check(is_equal_approx(damage, expected_damage), label + " should apply exactly one real contact hit")
	if wall_blocks:
		_check(boss.global_position.x < barrier.global_position.x - 36.0, "Wall stops the physical dash body")
		barrier.free()
	print("BOSS_DASH case=%s damage=%.1f distance=%.2f" % [label, damage, boss.global_position.distance_to(player.global_position)])

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
