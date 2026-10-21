extends SceneTree
## Deterministic physical combat regression; this does not establish human balance.
## Godot --headless --path . --script res://tools/test_mvp_v05.gd

var failures: Array[String] = []
var game
var lab_origin := Vector2(-2500, -2500)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.set_process(false)
	_freeze()
	var probe = get_nodes_in_group("enemies")[0]
	if not _has_property(probe, "role") or not ResourceLoader.exists("res://scripts/mvp_boss.gd"):
		printerr("FAIL: V05 combat interfaces are not installed yet")
		quit(1)
		return
	await _roles_and_speed()
	await _ranged_aggro()
	await _ranged_physics()
	await _charger_physics()
	await _boss_physics()
	await _lifecycle()
	paused = false
	game.queue_free()
	await process_frame
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("MVP V05 COMBAT OK: roles, time-stable acceleration, physical projectile/wall/iframe, boss threshold/shield/four moving pillars/phase2, pause/restart/floor cleanup; human balance unmeasured")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _freeze() -> void:
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for pillar in get_nodes_in_group("mvp_boss_pillars"):
		pillar.set_physics_process(false)

func _lab_player(offset: Vector2) -> void:
	game.player.global_position = lab_origin + offset
	game.player.velocity = Vector2.ZERO
	game.player.hp = game.player.max_hp
	game.player.invuln_timer = 0.0
	game.player.blocking = false
	game.player.dodge_timer = 0.0
	game.player.dodge_cd = 0.0

func _enemy(role: String, offset := Vector2.ZERO):
	var foe = game._spawn_enemy(lab_origin + offset, false, false, false)
	foe.role = role
	foe.encounter_rect = Rect2()
	foe.home_position = foe.global_position
	foe.aggro_radius = 1000.0
	foe.attack_cd = 0.0
	foe.set_physics_process(false)
	return foe

func _frames(count: int) -> void:
	for _frame in range(count):
		await physics_frame

func _roles_and_speed() -> void:
	_lab_player(Vector2(350, 0))
	var samples: Array[float] = []
	for hz in [30, 60, 120]:
		var foe = _enemy("melee")
		foe.attack_cd = 100.0
		var previous := 0.0
		for tick in range(int(hz / 2)):
			foe._physics_process(1.0 / float(hz))
			var speed: float = foe.current_speed
			_check(speed >= previous - 0.01, "Chase speed rises smoothly instead of oscillating at %d Hz" % hz)
			if tick == 0:
				_check(speed > 0.0 and speed < foe.chase_speed * 0.5, "First chase tick accelerates without instant full speed")
			previous = speed
		samples.append(previous)
		foe.free()
	_check(absf(samples[0] - samples[2]) < 5.0, "Equal elapsed time yields comparable chase speed at 30 and 120 Hz")
	for role in ["melee", "ranged", "charger"]:
		_lab_player(Vector2(60 if role == "melee" else (170 if role == "charger" else 220), 0))
		var foe = _enemy(role)
		foe._physics_process(1.0 / 60.0)
		_check(foe.attack_state == foe.AttackState.WINDUP, role + " begins a visible warning before attacking")
		_check(foe.state_time >= 0.45, role + " warning has a readable duration")
		var hp: float = game.player.hp
		_check(is_equal_approx(hp, game.player.max_hp), role + " warning does not deal immediate damage")
		var kind: int = foe.attack_kind
		_check(kind == (2 if role == "ranged" else (1 if role == "charger" else 0)), role + " uses its own attack behavior")
		foe.free()
	print("V05 ROLES three_behaviors/warning/no_instant_damage/30_60_120Hz=checked")

func _ranged_physics() -> void:
	# Fire through the actual ranged enemy state machine, then let physics move the bolt.
	for mode in ["hit", "wall", "iframe"]:
		_lab_player(Vector2(240, 0))
		var foe = _enemy("ranged")
		foe._begin_attack(game.player)
		var barrier: StaticBody2D
		if mode == "wall":
			barrier = _wall(lab_origin + Vector2(120, 0))
		if mode == "iframe":
			game.player._try_dodge(Vector2.UP)
		var before: float = game.player.hp
		await _frames(2)
		foe._physics_process(foe.windup_duration + 0.01)
		_check(foe.attack_state == foe.AttackState.RECOVERY, "Ranged shot is followed by recovery")
		_check(get_nodes_in_group("enemy_projectiles").size() == 1, "Ranged warning creates one real projectile")
		if not get_nodes_in_group("enemy_projectiles").is_empty():
			_check(get_nodes_in_group("enemy_projectiles")[0].source_actor == foe, "Enemy projectile retains its source actor")
		await _frames(75)
		if mode == "hit":
			_check(is_equal_approx(before - game.player.hp, game.player._incoming_damage(foe.contact_damage)), "Real enemy projectile applies exactly one hit")
		else:
			_check(is_equal_approx(game.player.hp, before), "Real projectile respects " + mode)
		_check(get_nodes_in_group("enemy_projectiles").is_empty(), "Enemy projectile is consumed on " + mode)
		if is_instance_valid(barrier):
			barrier.free()
		foe.free()
	print("V05 PROJECTILE real_shot/one_hit/wall/roll_iframe/recovery=checked")

func _ranged_aggro() -> void:
	_lab_player(Vector2(650, 0))
	var foe = _enemy("melee")
	foe.aggro_radius = 100.0
	foe.encounter_rect = Rect2(lab_origin - Vector2(100, 100), Vector2(200, 200))
	foe.returning_home = true
	var before: float = foe.hp
	_check(not foe.encounter_rect.has_point(game.player.global_position) and foe.global_position.distance_to(game.player.global_position) > foe.aggro_radius, "Aggro fixture places shooter outside encounter and acquisition radius")
	_arrow(game.player.global_position - Vector2(32, 0), Vector2.LEFT, 5.0)
	await _frames(65)
	_check(is_equal_approx(foe.hp, before - 5.0), "Real distant arrow physically damages the ordinary enemy")
	_check(foe.provoked and not foe.returning_home, "Real distant hit immediately acquires persistent aggro and cancels return home")
	var start: Vector2 = foe.global_position
	foe.set_physics_process(true)
	await _frames(130)
	_check(foe.global_position.x > start.x + 100.0 and not foe.encounter_rect.has_point(foe.global_position), "Provoked enemy physically crosses its encounter boundary to chase shooter")
	_check(foe.provoked and not foe.returning_home, "Crossing encounter boundary cannot reset provoked enemy to home")
	game.player.global_position = lab_origin + Vector2(1400, 0)
	start = foe.global_position
	await _frames(60)
	_check(foe.global_position.x > start.x + 80.0 and foe.provoked and not foe.returning_home, "Pulling farther beyond leash and aggro radius preserves active pursuit")
	foe.free()
	print("V05 AGGRO real_distant_arrow/outside_encounter/return_home_cancelled/physical_boundary_crossing/persistent_long_pull=checked")

func _charger_physics() -> void:
	for mode in ["hit", "sidestep", "wall"]:
		_lab_player(Vector2(150, 0))
		var foe = _enemy("charger")
		foe._begin_attack(game.player)
		var before: float = game.player.hp
		var barrier: StaticBody2D
		if mode == "sidestep":
			# Movement after the warning locks direction must actually avoid the charge.
			game.player.position.y += 100
		elif mode == "wall":
			barrier = _wall(lab_origin + Vector2(75, 0))
		await _frames(2)
		for _frame in range(90):
			foe._physics_process(1.0 / 60.0)
			await physics_frame
		var damage: float = before - game.player.hp
		if mode == "hit":
			_check(is_equal_approx(damage, game.player._incoming_damage(foe.contact_damage)), "Charger physically hits once through the warning/dash/recovery cycle")
		else:
			_check(is_zero_approx(damage), "Physical charger respects " + mode)
		_check(foe.attack_state == foe.AttackState.RECOVERY, "Charger has an opening after its charge")
		if is_instance_valid(barrier):
			_check(foe.global_position.x < barrier.global_position.x, "Wall stops charger body movement")
			barrier.free()
		foe.free()
	print("V05 CHARGER real_body/one_hit/locked_aim_sidestep/wall/recovery=checked")

func _wall(at: Vector2) -> StaticBody2D:
	var barrier := StaticBody2D.new()
	barrier.position = at
	barrier.collision_layer = 1
	barrier.collision_mask = 0
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = Vector2(20, 160)
	collision.shape = rectangle
	barrier.add_child(collision)
	game.contents.add_child(barrier)
	return barrier

func _arrow(at: Vector2, direction: Vector2, damage: float, pierce := 0):
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(direction, damage, 700.0, pierce)
	arrow.position = at
	game.add_child(arrow)
	return arrow

func _boss_physics() -> void:
	game.depth = 1
	game._build_floor()
	_freeze()
	var boss = game.boss
	boss.global_position = lab_origin
	boss.home_position = lab_origin
	boss.encounter_rect = Rect2(lab_origin - Vector2(450, 350), Vector2(900, 700))
	boss.awaken()
	_lab_player(Vector2(-350, 250))
	await _frames(2)
	var arrow = _arrow(lab_origin + Vector2(-120, 0), Vector2.RIGHT, 10000.0, 3)
	await _frames(20)
	_check(not boss.dead and is_equal_approx(boss.hp, boss.max_hp * 0.5), "A real lethal arrow clamps Boss at the first phase threshold")
	_check(boss.shielded and boss.phase_state == "transition", "Threshold starts shielded transition")
	_check(get_nodes_in_group("mvp_boss_pillars").is_empty(), "Pillars do not appear before the transition completes")
	var threshold_hp: float = boss.hp
	if is_instance_valid(arrow):
		arrow.free()
	var blocked = _arrow(lab_origin + Vector2(-100, 0), Vector2.RIGHT, 10000.0, 4)
	await _frames(15)
	_check(is_equal_approx(boss.hp, threshold_hp) and not is_instance_valid(blocked), "Shield consumes a real piercing arrow without damage")
	boss._physics_process(1.0)
	_check(boss.phase_state == "transition" and boss.pillars_remaining() == 0, "Transition preserves a short invulnerability interval")
	boss._physics_process(0.7)
	_check(boss.phase_state == "pillars" and boss.pillars_remaining() == 4, "Transition creates exactly four pillars")
	var pillars := get_nodes_in_group("mvp_boss_pillars")
	_check(pillars.size() == 4, "Exactly four physical pillar targets exist")
	var score: int = game.score
	var kills: int = game.kills
	var misses: int = game.normal_misses
	for pillar in pillars:
		_check(not pillar.is_in_group("enemies"), "Pillar is excluded from normal enemies and kill economy")
		pillar.set_physics_process(false)
		var start: Vector2 = pillar.global_position
		pillar._physics_process(0.3)
		_check(pillar.global_position.distance_to(start) > 1.0, "Flying pillar changes actual target position")
		await _frames(2)
		var hp: float = pillar.hp
		var shot = _arrow(pillar.global_position - Vector2(70, 0), Vector2.RIGHT, 5.0, 2)
		await _frames(12)
		_check(is_equal_approx(pillar.hp, hp - 5.0), "Piercing arrow hits an actual moving pillar once")
		if is_instance_valid(shot):
			shot.free()
		var remaining: int = boss.pillars_remaining()
		_arrow(pillar.global_position - Vector2(70, 0), Vector2.RIGHT, 10000.0)
		await _frames(15)
		_check(boss.pillars_remaining() == remaining - 1, "Each pillar death decrements the objective exactly once")
		if is_instance_valid(pillar):
			pillar.take_damage(10000.0)
		_check(boss.pillars_remaining() == remaining - 1, "Repeated damage cannot double count a pillar death")
		if remaining > 1:
			_check(boss.shielded, "Boss stays invulnerable while any pillar remains")
	_check(game.score == score and game.kills == kills and game.normal_misses == misses, "Four pillar deaths give no ordinary score, kill credit or drop pity")
	_check(boss.phase == 2 and not boss.shielded and boss.phase_state == "combat", "All four pillars unlock Boss phase two")
	await _boss_fan(boss)
	_arrow(lab_origin + Vector2(-100, 0), Vector2.RIGHT, 10000.0)
	await _frames(15)
	_check(not is_instance_valid(boss) or boss.dead, "Real arrow can kill Boss after the four-pillar objective")
	_check(game.run_state == "playing" and game.gate_open, "First-floor Boss death unlocks descent without ending the run")
	print("V05 BOSS physical_arrow/clamped_threshold/shield/four_mobile_targets/pierce_once/no_loot/phase2_victory=checked")

func _boss_fan(boss) -> void:
	_lab_player(Vector2(280, 0))
	boss.boss_move_index = 2
	boss._begin_attack(game.player)
	_check(boss.attack_kind == 2 and boss.attack_state == boss.AttackState.WINDUP, "Phase two fan begins a warning")
	var aim: Vector2 = boss.locked_direction
	game.player.position.y += 120
	boss._physics_process(boss.windup_duration + 0.01)
	var bolts := get_nodes_in_group("enemy_projectiles")
	_check(bolts.size() == 3, "Phase two fan emits exactly three real projectile bodies")
	var angles: Array[float] = []
	var starts: Array[Vector2] = []
	for bolt in bolts:
		angles.append(aim.angle_to(bolt.direction))
		starts.append(bolt.global_position)
		_check(bolt.source_actor == boss, "Each fan projectile retains the Boss as source")
	angles.sort()
	if angles.size() == 3:
		for index in 3:
			_check(is_equal_approx(angles[index], [-0.26, 0.0, 0.26][index]), "Fan direction stays locked to warning aim at angle %d" % index)
	await _frames(8)
	for index in bolts.size():
		var bolt = bolts[index]
		_check(is_instance_valid(bolt), "Fan projectile remains in flight before reaching the target")
		if is_instance_valid(bolt):
			var motion: Vector2 = bolt.global_position - starts[index]
			_check(motion.length() > 10.0 and motion.normalized().dot(bolt.direction) > 0.999, "Real fan projectile travels along its locked direction")
			bolt.free()
	_check(boss.attack_state == boss.AttackState.RECOVERY, "Phase two fan leaves a recovery opening")
	print("V05 BOSS FAN three_physical_bodies/locked_after_sidestep/angles_minus026_0_plus026/actual_travel=checked")

func _lifecycle() -> void:
	for operation in ["pause", "restart", "floor"]:
		game.start_run()
		game.depth = 1
		game._build_floor()
		_freeze()
		var boss = game.boss
		boss.awaken()
		boss.take_damage(10000.0)
		boss._physics_process(1.7)
		var pillars := get_nodes_in_group("mvp_boss_pillars")
		_check(pillars.size() == 4, operation + " fixture has four live pillars")
		var foe = _enemy("ranged")
		_lab_player(Vector2(300, 0))
		foe._begin_attack(game.player)
		foe._physics_process(foe.windup_duration + 0.01)
		var bolts := get_nodes_in_group("enemy_projectiles")
		_check(not bolts.is_empty(), operation + " fixture has a live projectile")
		if operation == "pause":
			var positions: Array[Vector2] = []
			for pillar in pillars:
				positions.append(pillar.global_position)
			var projectile_position: Vector2 = bolts[0].global_position
			game.ui.show_pause()
			await _frames(8)
			for index in pillars.size():
				_check(pillars[index].global_position == positions[index], "Paused pillar movement stops")
			_check(is_instance_valid(bolts[0]) and bolts[0].global_position == projectile_position, "Paused enemy projectile stops")
			game.ui.close_modal()
			game.start_run()
		elif operation == "restart":
			game.start_run()
		else:
			game._build_floor()
		_freeze()
		await process_frame
		_check(get_nodes_in_group("mvp_boss_pillars").is_empty() and get_nodes_in_group("enemy_projectiles").is_empty(), operation + " clears all pillar and enemy projectile groups")
		for object in pillars + bolts:
			_check(not is_instance_valid(object), operation + " destroys old encounter object instances")
	print("V05 LIFECYCLE pause/restart/floor_objects_cleared=checked")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _has_property(object: Object, property: String) -> bool:
	for entry in object.get_property_list():
		if entry.name == property:
			return true
	return false
