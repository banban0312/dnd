extends SceneTree
## Physics-based navigation regression. Samples a 26x26 player box every 16 px
## and sweeps every graph edge against live wall/pillar collision shapes.
## Run: Godot --headless --path . --script res://tools/test_mvp_layout.gd

const STEP := 16
var failures: Array[String] = []
var game
var query := PhysicsShapeQueryParameters2D.new()
var directions := [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.set_process(false)
	_freeze_actors()
	await physics_frame
	await physics_frame
	var first_rooms: Array = game.world.rooms.duplicate()
	var first_route: Array = game.world.route_points.duplicate()
	await _measure_floor()
	await _encounter_checks()
	game.depth = 3
	game._build_floor()
	_freeze_actors()
	await physics_frame
	await physics_frame
	await _measure_floor()
	var old_world = game.world
	var old_contents = game.contents
	var old_enemy = game.contents.get_child(0)
	var old_chest = game.chests[0]
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 1.0)
	game.add_child(arrow)
	game.depth = 2
	game._build_floor()
	_freeze_actors()
	await physics_frame
	await physics_frame
	_check(not is_instance_valid(old_world), "Old world is freed on floor transition")
	_check(not is_instance_valid(old_contents), "Old floor contents are freed")
	_check(not is_instance_valid(old_enemy), "Old enemy is freed")
	_check(not is_instance_valid(old_chest), "Old chest is freed")
	_check(not is_instance_valid(arrow), "Old arrow is freed")
	_check(first_rooms != game.world.rooms, "Floors have different room rectangles")
	_check(first_route != game.world.route_points, "Floors have different main routes")
	await _measure_floor()
	await _encounter_checks()
	game.queue_free()
	await process_frame
	if failures.is_empty():
		print("MVP LAYOUT OK: three distinct floors, physical 26x26 paths, optional side rooms, clean transition, encounter and wall isolation")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _freeze_actors() -> void:
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

func _measure_floor() -> void:
	var world = game.world
	_check(world.rooms.size() == 4, "Each floor has three main rooms and one side room")
	_check(world.room_at(world.chest_positions[0]) == 0, "First chest is in the entry room")
	_check(world.room_at(world.chest_positions[1]) == 3, "Optional chest is in room 3")
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(26, 26)
	query.shape = rectangle
	query.collision_mask = 1
	query.exclude = [game.player.get_rid()]
	var open: Dictionary = {}
	# No floor-cell dictionary is consulted: the graph comes from actual physics.
	for y in range(0, int(world.map_size.y) + 1, STEP):
		for x in range(0, int(world.map_size.x) + 1, STEP):
			var point := Vector2(x, y)
			query.transform = Transform2D(0.0, point)
			query.motion = Vector2.ZERO
			if world.get_world_2d().direct_space_state.intersect_shape(query, 1).is_empty():
				open[Vector2i(x / STEP, y / STEP)] = true
	var origin := _cell(world.player_spawn)
	_check(open.has(origin), "Spawn accepts the physical player box, floor %d at %s" % [game.depth, world.player_spawn])
	var reachable := _flood(open, origin, Rect2())
	var main_reachable := _flood(open, origin, world.rooms[3])
	var goals: Dictionary = {"first_chest": world.chest_positions[0], "side_chest": world.chest_positions[1], "guardian": world.boss_position, "exit": world.exit_position}
	for label in goals:
		var goal: Vector2 = goals[label]
		_check(reachable.has(_cell(goal)), "Floor %d physical route to %s at %s" % [game.depth, label, goal])
	for label in ["guardian", "exit"]:
		_check(main_reachable.has(_cell(goals[label])), "Floor %d reaches %s without room 3" % [game.depth, label])
	print("PHYSICAL_LAYOUT " + JSON.stringify({"depth": game.depth, "box": "26x26", "grid_px": STEP, "open_samples": open.size(), "reachable_samples": reachable.size(), "reachable_without_side_room": main_reachable.size(), "goals": str(goals)}))

func _flood(open: Dictionary, origin: Vector2i, forbidden: Rect2) -> Dictionary:
	var seen: Dictionary = {}
	if not open.has(origin):
		return seen
	var pending: Array[Vector2i] = [origin]
	seen[origin] = true
	var index := 0
	while index < pending.size():
		var cell := pending[index]
		index += 1
		for offset: Vector2i in directions:
			var next := cell + offset
			if seen.has(next) or not open.has(next):
				continue
			if forbidden.has_area() and forbidden.has_point(Vector2(next) * STEP):
				continue
			query.transform = Transform2D(0.0, Vector2(cell) * STEP)
			query.motion = Vector2(offset) * STEP
			var sweep: PackedFloat32Array = game.world.get_world_2d().direct_space_state.cast_motion(query)
			if sweep[0] < 0.999:
				continue
			seen[next] = true
			pending.append(next)
	return seen

func _encounter_checks() -> void:
	var enemy = game.contents.get_child(0)
	var room: Rect2 = game.world.rooms[1]
	var saved_player: Vector2 = game.player.position
	var saved_enemy: Vector2 = enemy.position
	enemy.position = room.position + Vector2(32, 64)
	enemy.home_position = enemy.position
	enemy._cancel_attack()
	enemy.returning_home = false
	game.player.position = enemy.position - Vector2(80, 0)
	game.player.invuln_timer = 0.0
	_check(not room.has_point(game.player.position), "Cross-room target fixture lies outside enemy encounter")
	await physics_frame
	await physics_frame
	var before: Vector2 = enemy.position
	enemy._physics_process(1.0 / 60.0)
	_check(enemy.velocity.is_zero_approx() and enemy.position.is_equal_approx(before), "Floor %d outside-room target does not pull enemy" % game.depth)
	_check(enemy.attack_state == enemy.AttackState.IDLE, "Floor %d outside-room target does not start attack" % game.depth)
	_check(not enemy._clear_shot(game.player), "Floor %d real boundary wall blocks attack ray" % game.depth)
	var hp_before: float = game.player.hp
	enemy.locked_direction = Vector2.LEFT
	enemy._resolve_strike(game.player)
	_check(is_equal_approx(game.player.hp, hp_before), "Floor %d strike cannot damage through wall" % game.depth)
	var enemy_hp: float = enemy.hp
	var shot_origin: Vector2 = game.player.position
	game.player.position = saved_player
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 10.0, 700.0, 1)
	arrow.position = shot_origin
	game.add_child(arrow)
	for _frame in range(20):
		await physics_frame
	_check(is_equal_approx(enemy.hp, enemy_hp), "Floor %d piercing arrow cannot damage through wall" % game.depth)
	_check(not is_instance_valid(arrow), "Floor %d wall terminates physical arrow" % game.depth)
	if is_instance_valid(arrow):
		arrow.free()
	enemy.position = saved_enemy
	enemy.home_position = saved_enemy
	enemy._cancel_attack()
	print("ENCOUNTER_ISOLATION depth=%d cross_room=blocked melee_wall=blocked piercing_wall=blocked" % game.depth)

func _cell(point: Vector2) -> Vector2i:
	return Vector2i(roundi(point.x / STEP), roundi(point.y / STEP))

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
