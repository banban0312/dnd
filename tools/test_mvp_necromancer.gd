extends SceneTree
## Physical regression for floor-three caster; no claims about human balance.
var failures: Array[String] = []
var game
var boss

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	await _thresholds_and_shelter()
	await _lethal_cases()
	await _barrage()
	await _bone_lotus()
	await _summons()
	await _pause_cleanup()
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
		print("NECROMANCER OK: real arrows/two thresholds/shelter/full-body lethal bypass/regular rotating gap/cap/lifetime/four summons/pause/restart/floor cleanup; human balance unmeasured")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _fresh() -> void:
	game.start_run()
	game.depth = 3
	game._build_floor()
	boss = game.boss
	game.player.set_physics_process(false)
	for foe in get_nodes_in_group("enemies"):
		foe.set_physics_process(false)
	game.player.position = boss.position - Vector2(220, 0)
	game.player.invuln_timer = 0.0
	game.player.blocking = false
	boss.awaken()
	await _frames(2)
	_check(boss.get_script().resource_path.ends_with("mvp_necromancer.gd"), "Third floor uses the real necromancer script")
	_check(boss.visual_sprite == null or not boss.visual_sprite.visible, "Old ogre visual is hidden")

func _frames(count: int) -> void:
	for _index in count:
		await physics_frame

func _shot(damage: float):
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, damage, 700.0, 3)
	arrow.position = boss.position - Vector2(100, 0)
	game.add_child(arrow)
	await _frames(15)
	if is_instance_valid(arrow):
		arrow.free()

func _thresholds_and_shelter() -> void:
	await _fresh()
	boss._emit_wave()
	_check(get_nodes_in_group("necromancer_projectiles").size() == 19, "Caster emits a real first volley")
	await _shot(10000.0)
	_check(not boss.dead and is_equal_approx(boss.hp, boss.max_hp * 2.0 / 3.0), "First real lethal arrow clamps health at two thirds")
	_check(boss.shielded and boss.phase_state == "ritual" and boss.ritual_time == 4.0, "Threshold starts four-second invulnerable staff rite")
	_check(get_nodes_in_group("necromancer_projectiles").is_empty(), "Ritual clears existing barrage")
	var safe: Vector2 = boss.safe_center
	_check(safe.distance_to(game.player.position) < game.player._current_speed() * 4.0, "Shelter can be reached inside ritual deadline by ordinary movement")
	_check(boss.encounter_rect.grow(-boss.safe_radius).has_point(safe), "Whole shelter fits inside arena")
	await _shot(10000.0)
	_check(is_equal_approx(boss.hp, boss.max_hp * 2.0 / 3.0), "Ritual shield prevents skipping second health threshold")
	boss._emit_wave()
	_check(get_nodes_in_group("necromancer_projectiles").is_empty(), "Ritual pauses offensive volleys")
	game.player.position = safe
	var hp: float = game.player.hp
	boss._physics_process(3.99)
	_check(boss.phase_state == "ritual" and not game.player.dead, "Shelter deadline does not resolve early")
	boss._physics_process(0.02)
	_check(not game.player.dead and game.player.hp == hp and not boss.shielded, "Fully sheltered player survives explosion without damage")
	_check(boss.phase_state == "recovery", "Explosion gives an output recovery window")
	boss._physics_process(1.9)
	_check(boss.phase_state == "recovery" and get_nodes_in_group("necromancer_projectiles").is_empty(), "Post-ritual recovery does not immediately refill arena")
	game.player.position = boss.position - Vector2(220, 0)
	await _shot(10000.0)
	_check(is_equal_approx(boss.hp, boss.max_hp / 3.0) and boss.phase_state == "ritual" and boss.phase == 3, "Second real lethal arrow clamps at one third and starts second ritual")
	_check(boss.safe_center.distance_to(safe) > 1.0, "Second ritual relocates shelter deterministically")
	game.player.position = boss.safe_center
	boss._physics_process(4.01)
	_check(not game.player.dead, "Second shelter survives second global explosion")
	await _shot(10000.0)
	_check(not is_instance_valid(boss) or boss.dead, "Third lethal arrow can finish Boss after both rituals")
	_check(game.run_state == "result", "Final caster defeat completes real run")
	print("NECRO THRESHOLDS real_arrows/2of3/1of3/no_skip/two_shelters/recovery/victory=checked")

func _lethal_cases() -> void:
	for mode in ["outside_iframe", "body_crosses_edge"]:
		await _fresh()
		boss.take_damage(10000.0)
		game.player.position = boss.safe_center + Vector2(150 if mode == "outside_iframe" else boss.safe_radius - 5, 0)
		game.player.invuln_timer = 100.0
		game.player.blocking = true
		game.player._try_dodge(Vector2.UP)
		boss._physics_process(4.01)
		_check(game.player.dead and game.player.hp == 0.0, "Shelter check is lethal even during dodge/guard/invulnerability: " + mode)
		await process_frame
		_check(game.run_state == "result", "Unsheltered death uses real result flow: " + mode)
	print("NECRO LETHAL outside_roll_guard_iframe/whole_collision_body_required=checked")

func _barrage() -> void:
	await _fresh()
	boss._emit_wave()
	var first := get_nodes_in_group("necromancer_projectiles")
	_check(first.size() == 19, "First ring leaves five missing slots from 24")
	var first_directions: Array[Vector2] = []
	for bolt in first:
		first_directions.append(bolt.direction)
		_check(bolt.speed <= 200.0, "Barrage remains slow enough to read")
		_check(absf(bolt.direction.angle()) >= PI * 0.249, "First wave preserves the advertised opening")
	boss._emit_wave()
	_check(get_nodes_in_group("necromancer_projectiles").size() == 22, "Second volley alternates to three bone-lotus seeds")
	boss._emit_wave()
	var both := get_nodes_in_group("necromancer_projectiles")
	_check(both.size() == 41, "Third volley returns to the regular ring")
	for index in first.size():
		_check(is_equal_approx(first_directions[index].angle_to(both[index + first.size() + 3].direction), PI / 12.0), "Regular opening rotates exactly 15 degrees between ring waves")
	var start: Vector2 = first[0].position
	await _frames(5)
	_check(is_instance_valid(first[0]) and first[0].position.distance_to(start) > 5.0, "Real bone sparks travel under physics")
	for _index in 20:
		boss._emit_wave()
	_check(get_nodes_in_group("necromancer_projectiles").size() <= 160, "Repeated volleys cannot exceed hard cap of 160 live projectiles")
	for bolt in get_nodes_in_group("necromancer_projectiles"):
		bolt._physics_process(6.1)
	await process_frame
	_check(get_nodes_in_group("necromancer_projectiles").is_empty(), "Every bone spark expires by six seconds")
	print("NECRO BARRAGE physical/19of24/15deg_rotation/readable_speed/160_cap/6sec_lifetime=checked")

func _bone_lotus() -> void:
	await _fresh()
	game.player.position = boss.position - Vector2(350, 0)
	boss.wave_index = 1
	boss._emit_wave()
	var seeds := get_nodes_in_group("necromancer_projectiles")
	_check(seeds.size() == 3, "Bone-lotus volley fires exactly three real seed bodies")
	var blooms: Array = []
	var seed_starts: Array[Vector2] = []
	for seed in seeds:
		_check(seed.is_seed and not seed.is_petal, "Secondary explosion belongs only to seed bodies")
		seed_starts.append(seed.position)
		var axis: Vector2 = seed.direction
		seed.blossomed.connect(func(petals: Array): blooms.append({"axis": axis, "petals": petals}))
	await _frames(60)
	var stopped: Array[Vector2] = []
	for index in seeds.size():
		var seed = seeds[index]
		_check(is_instance_valid(seed) and seed.seed_state == "warning", "Seed flies for 0.9 seconds then enters flower warning")
		if is_instance_valid(seed):
			_check(seed.position.distance_to(seed_starts[index]) > 80.0, "Seed really travels before secondary explosion")
			stopped.append(seed.position)
	await _frames(5)
	for index in seeds.size():
		_check(is_instance_valid(seeds[index]) and seeds[index].position == stopped[index], "Flower warning holds seed stationary")
	_check(blooms.is_empty(), "Stopped flower warning lasts before any child bullets appear")
	await _frames(20)
	_check(blooms.size() == 3, "Each real timed seed blossoms exactly once")
	var petals := get_nodes_in_group("necromancer_projectiles")
	_check(petals.size() == 48, "Three secondary explosions produce eight forked petals each, 48 bullets total")
	for bloom in blooms:
		_check(bloom.petals.size() == 16, "A blossom has exactly eight two-branch petals")
		for index in bloom.petals.size():
			var petal = bloom.petals[index]
			var expected: Vector2 = bloom.axis.rotated(int(index / 2) * TAU / 8.0 + (-0.07 if index % 2 == 0 else 0.07))
			_check(petal.direction.dot(expected) > 0.99999, "Petal directions stay fixed and symmetric about eight axes")
			_check(petal.is_petal and not petal.is_seed, "Secondary petal is terminal and cannot recursively burst")
			petal._blossom()
	await _frames(25)
	_check(blooms.size() == 3 and get_nodes_in_group("necromancer_projectiles").size() == 48, "Terminal petal flight never creates another generation")
	# Mix fresh seeds with still-flying petals; both must disappear during the rite.
	boss._emit_wave()
	boss.take_damage(10000.0)
	await process_frame
	_check(get_nodes_in_group("necromancer_projectiles").is_empty(), "Ritual clears seed bodies and their second-generation petals together")
	await _fresh()
	for _index in 50:
		boss._emit_wave()
	for bolt in get_nodes_in_group("necromancer_projectiles"):
		if bolt.is_seed:
			bolt._blossom()
	_check(get_nodes_in_group("necromancer_projectiles").size() <= 160, "Secondary explosion obeys shared 160-object cap under saturation")
	boss._die()
	await process_frame
	_check(get_nodes_in_group("necromancer_projectiles").is_empty(), "Boss death clears seeds and petals as well as rings")
	print("NECRO LOTUS timed_real_flight/0.45s_stationary_warning/three_bursts/8_forked_axes/no_recursion/shared_cap/ritual_death_cleanup=checked")

func _summons() -> void:
	await _fresh()
	for _cycle in 4:
		var before: int = get_nodes_in_group("necromancer_minions").size()
		boss._prepare_summon()
		_check(get_nodes_in_group("necromancer_minions").size() == before, "Summon warning does not instantly create enemies")
		if before < 4:
			_check(not boss.summon_points.is_empty() and boss.summon_warning >= 1.0, "Skeleton spawn receives a visible ground-warning window")
		boss._complete_summon()
		for minion in get_nodes_in_group("necromancer_minions"):
			minion.set_physics_process(false)
		_check(get_nodes_in_group("necromancer_minions").size() <= 4, "Summons obey four-skeleton limit")
	_check(get_nodes_in_group("necromancer_minions").size() == 4, "Real game spawn interface creates four skeletons")
	boss.take_damage(10000.0)
	await process_frame
	_check(get_nodes_in_group("necromancer_minions").is_empty(), "Ritual removes summoned attackers before shelter check")
	print("NECRO SUMMON ground_warning/actual_game_interface/four_limit/ritual_cleanup=checked")

func _pause_cleanup() -> void:
	await _fresh()
	boss._emit_wave()
	var bolt = get_nodes_in_group("necromancer_projectiles")[0]
	var start: Vector2 = bolt.position
	game.ui.show_pause()
	await _frames(8)
	_check(is_instance_valid(bolt) and bolt.position == start, "Pause freezes real barrage movement")
	game.ui.close_modal()
	boss.take_damage(10000.0)
	boss.set_physics_process(true)
	game.player.position = boss.safe_center
	game.ui.show_pause()
	var time: float = boss.ritual_time
	await _frames(8)
	_check(boss.ritual_time == time, "Pause freezes four-second ritual deadline")
	game.ui.close_modal()
	var old_boss = boss
	game.start_run()
	await process_frame
	_check(not is_instance_valid(old_boss), "Restart destroys previous caster and shelter draw state")
	_check(get_nodes_in_group("necromancer_projectiles").is_empty() and get_nodes_in_group("necromancer_minions").is_empty(), "Restart clears caster encounter objects")
	await _fresh()
	boss._emit_wave()
	boss._prepare_summon()
	boss._complete_summon()
	var old_objects := get_nodes_in_group("necromancer_projectiles") + get_nodes_in_group("necromancer_minions")
	game._build_floor()
	await process_frame
	for object in old_objects:
		_check(not is_instance_valid(object), "Floor replacement frees each old caster projectile and skeleton")
	print("NECRO LIFECYCLE pause_bullets/pause_ritual/restart/floor_disposal=checked")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
