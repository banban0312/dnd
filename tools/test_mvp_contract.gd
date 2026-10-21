extends SceneTree
## Transaction/lifecycle regression using real MVP scenes and reward methods.
## Run: Godot --headless --path . --script res://tools/test_mvp_contract.gd

var failures: Array[String] = []
var game
var items

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	items = load("res://scripts/item_data.gd")
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	await _starter_checks()
	await _normal_descent_checks()
	await _contract_full_checks()
	for selection in ["piercing_bow", "iron_plate", ""]:
		await _contract_choice_checks(selection)
	await _rift_checks()
	await _death_and_reset_checks()
	paused = false
	game.queue_free()
	await process_frame
	# Headless checks can finish before one-shot audio completes naturally.
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("MVP CONTRACT OK: starter and contract transactions, both rewards and skip, full bags, normal descent, cumulative scoring, rift timing/hit/dodge/pause, death and reset")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _fresh() -> void:
	game.start_run()
	_freeze()
	await process_frame
	_check(not game.contract_active and game.result_banked == 0 and game.reward_source.is_empty(), "New run resets contract, result and pending reward")
	_check(get_nodes_in_group("mvp_rifts").is_empty(), "New run has no old rifts")

func _freeze() -> void:
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	for rift in get_nodes_in_group("mvp_rifts"):
		rift.set_physics_process(false)

func _unlock() -> void:
	var found := false
	for enemy in get_nodes_in_group("enemies"):
		if enemy.is_elite or enemy.is_boss:
			enemy.take_damage(10000.0)
			if enemy.is_boss and enemy.shielded:
				enemy._physics_process(2.0)
				for pillar in get_nodes_in_group("mvp_boss_pillars"):
					pillar.take_damage(10000.0)
				enemy.take_damage(10000.0)
			found = true
			break
	_check(found and game.gate_open, "Defeating actual guardian unlocks the gate")
	game.ui.show_gate()

func _fill_bag() -> void:
	game.player.backpack.clear()
	for _index in range(game.player.BACKPACK_SIZE):
		game.player.add_to_backpack(items.red_potion())

func _starter_checks() -> void:
	await _fresh()
	var chest = game.chests[0]
	game._open_chest(chest)
	_check(game.run_state == "reward" and paused and not chest.opened, "First chest opens paused choice without consumption")
	_check(not game.claim_reward("") and not game.claim_reward("dragon_bow"), "Starter rejects skip and unoffered items")
	game.cancel_reward()
	_check(game.run_state == "playing" and not paused and not chest.opened and game.first_chest, "Starter cancellation returns to play without consuming chest")
	_fill_bag()
	var before: Array = game.player.backpack.duplicate()
	var score_before: int = game.score
	var contents_before: int = game.contents.get_child_count()
	game._open_chest(chest)
	_check(not game.claim_reward("recurve_bow"), "Full starter bag rejects reward")
	_check(game.player.backpack == before and game.score == score_before and not chest.opened and game.first_chest, "Rejected starter transaction preserves bag, score and chest")
	_check(game.contents.get_child_count() == contents_before, "Rejected starter reward does not create a floor drop")
	game.cancel_reward()
	_check(game.run_state == "playing" and not paused, "Full starter bag can return to play")
	game.player.backpack.clear()
	game._open_chest(chest)
	_check(game.claim_reward("recurve_bow"), "Starter can reopen and claim after capacity is freed")
	_check(chest.opened and not game.first_chest and game.player.backpack[0].item_id == "recurve_bow", "Selected starter bow is committed once")
	game.ui.close_modal()
	var awarded: Array = game.player.backpack.duplicate()
	var awarded_score: int = game.score
	game._open_chest(chest)
	_check(not game.claim_reward("piercing_bow"), "Claim cannot be replayed after first chest")
	_check(game.player.backpack == awarded and game.score == awarded_score, "Repeated interaction does not duplicate starter reward")
	print("REWARD_STARTER cancel/reopen/full_bag/invalid/once=OK")

func _normal_descent_checks() -> void:
	await _fresh()
	game.descend()
	_check(game.depth == 1, "Cannot descend while playing before gate")
	game.ui.show_gate()
	game.descend()
	game.begin_contract()
	_check(game.depth == 1 and not game.contract_active and game.reward_source.is_empty(), "Locked gate rejects normal and contract descent")
	game.ui.close_modal()
	_unlock()
	game.player.hp = 33.0
	game.player.mp = 12.0
	var weapon = game.player.equipment.weapon
	var armor = game.player.equipment.armor
	game.descend()
	_freeze()
	_check(game.depth == 2 and not game.contract_active and not paused, "Normal gate descent reaches second floor")
	_check(get_nodes_in_group("mvp_rifts").is_empty(), "Normal descent creates no rifts")
	_check(is_equal_approx(game.player.hp, 33.0) and is_equal_approx(game.player.mp, 12.0) and game.player.equipment.weapon == weapon and game.player.equipment.armor == armor, "Normal descent preserves health, mana and equipment")
	game.score = 111
	game.finish("victory")
	_check(game.result_banked == 222, "Normal victory banks cumulative score at x2")
	print("NORMAL_DESCENT gate/provisions/no_rift/x2=OK")

func _contract_full_checks() -> void:
	await _fresh()
	_unlock()
	_fill_bag()
	var before: Array = game.player.backpack.duplicate()
	var old_world = game.world
	var score_before: int = game.score
	game.begin_contract()
	_check(game.reward_source == "contract" and game.run_state == "reward", "Contract opens reward choice")
	_check(not game.claim_reward("iron_plate"), "Full contract bag rejects item")
	_check(game.player.backpack == before and game.world == old_world and game.depth == 1 and not game.contract_active and game.score == score_before, "Rejected contract leaves inventory, floor, score and contract unchanged")
	game.cancel_reward()
	_check(game.run_state == "gate" and game.reward_source.is_empty(), "Full contract bag can return to gate")
	game.ui.close_modal()
	_check(game.run_state == "playing" and not paused, "Gate can return to inventory management")
	game.ui.show_gate()
	game.begin_contract()
	_check(game.claim_reward(""), "Full bag can explicitly skip contract reward")
	_freeze()
	_check(game.depth == 2 and game.contract_active and game.player.backpack == before, "Skipping reward preserves full bag and enters contract floor")
	_check(get_nodes_in_group("mvp_rifts").size() == 2, "Skipped reward still creates both contract rifts")
	print("REWARD_CONTRACT_FULL reject/cancel/skip=OK")

func _contract_choice_checks(selection: String) -> void:
	await _fresh()
	_unlock()
	game.player.hp = 37.0
	game.player.mp = 7.0
	game.player.equip_item("weapon", items.recurve_bow())
	game.player.equip_item("armor", items.ranger_leather())
	var weapon = game.player.equipment.weapon
	var armor = game.player.equipment.armor
	var before: int = game.player.backpack.size()
	game.begin_contract()
	_check(not game.claim_reward("recurve_bow"), "Contract rejects unavailable reward")
	_check(game.claim_reward(selection), "Contract commits offered choice or skip: " + selection)
	_freeze()
	_check(game.depth == 2 and game.contract_active and game.reward_source.is_empty(), "Contract reward and transition commit together")
	_check(is_equal_approx(game.player.hp, 37.0) and is_equal_approx(game.player.mp, 7.0) and game.player.equipment.weapon == weapon and game.player.equipment.armor == armor, "Contract keeps health, mana and equipped items")
	_check(game.player.backpack.size() == before + (0 if selection.is_empty() else 1), "Contract grants exactly one item or none for skip")
	if not selection.is_empty():
		_check(game.player.backpack[before].item_id == selection, "Chosen contract item survives floor replacement")
	_check(get_nodes_in_group("mvp_rifts").size() == 2, "Contract produces exactly two rifts")
	var bag_after: Array = game.player.backpack.duplicate()
	game.begin_contract()
	_check(not game.claim_reward(selection), "Contract cannot be claimed again on second floor")
	_check(game.player.backpack == bag_after, "Duplicate contract call grants nothing")
	# New score is added after descent, so this detects banking the gate snapshot.
	var gate_score: int = game.score
	game.score += 37
	game.finish("victory")
	_check(game.result_banked == int((gate_score + 37) * 2.5), "Contract x2.5 applies to final cumulative score")
	var banked: int = game.result_banked
	game.finish("victory")
	_check(game.result_banked == banked, "Repeated finish cannot multiply banked result again")
	print("CONTRACT_CHOICE selection=%s retained/once/two_rifts/cumulative_x2.5=OK" % ("skip" if selection.is_empty() else selection))

func _rift_checks() -> void:
	await _fresh()
	_unlock()
	game.begin_contract()
	game.claim_reward("")
	_freeze()
	var rifts := get_nodes_in_group("mvp_rifts")
	var rift = rifts[0]
	_check(is_equal_approx(rift.WINDUP, 1.0) and is_equal_approx(rift.ACTIVE, 0.35) and is_equal_approx(rift.REST, 2.0), "Rift timing is 1.0 windup / 0.35 active / 2.0 rest")
	_check(is_equal_approx(absf(rifts[0].phase_offset - rifts[1].phase_offset), 1.65), "Two rifts use staggered phase offsets")
	game.player.position = rift.position
	game.player.blocking = false
	game.player.invuln_timer = 0.0
	game.player.hp = game.player.max_hp
	var before: float = game.player.hp
	rift.clock = 0.99
	rift.hit_this_cycle = false
	rift._physics_process(0.0)
	_check(is_equal_approx(game.player.hp, before), "Windup deals no damage")
	rift.clock = 1.0
	rift._physics_process(0.0)
	_check(game.player.hp < before and rift.hit_this_cycle, "Active rift damages player and marks cycle hit")
	var after_first: float = game.player.hp
	rift._physics_process(0.2)
	_check(is_equal_approx(game.player.hp, after_first), "Active cycle cannot hit twice")
	rift.clock = 3.34
	rift._physics_process(0.02)
	_check(not rift.hit_this_cycle and rift.clock < 0.02 and is_equal_approx(game.player.hp, after_first), "Rest wraps to new windup and clears hit marker")
	rift.clock = 1.0
	rift._physics_process(0.0)
	_check(game.player.hp < after_first, "Next rift cycle may hit once again")
	game.player.dodge_cd = 0.0
	game.player._try_dodge(Vector2.RIGHT)
	before = game.player.hp
	rift.clock = 1.0
	rift.hit_this_cycle = false
	rift._physics_process(0.0)
	_check(is_equal_approx(game.player.hp, before) and not rift.hit_this_cycle, "Real dodge invulnerability avoids active rift")
	game.player._tick_timers(0.35)
	rift.clock = 1.34
	rift._physics_process(0.0)
	_check(is_equal_approx(game.player.hp, before), "Dodge iframe window can cover full active duration")
	game.player.invuln_timer = 1.5
	rift.clock = 1.0
	rift._physics_process(0.0)
	_check(is_equal_approx(game.player.hp, before), "Floor spawn protection blocks rift damage")
	rift.clock = 0.2
	rift.set_physics_process(true)
	game.ui.show_pause()
	var paused_clock: float = rift.clock
	for _frame in range(5):
		await physics_frame
	_check(is_equal_approx(rift.clock, paused_clock), "Paused scene does not advance enabled rift physics")
	rift.set_physics_process(false)
	game.ui.close_modal()
	_check(not paused, "Closing pause resumes play")
	print("RIFT timing/windup/single_hit/reset/dodge/spawn_protection/pause=OK")

func _death_and_reset_checks() -> void:
	var old_rifts := get_nodes_in_group("mvp_rifts")
	game.score = 123
	game.player.invuln_timer = 0.0
	game.player.take_damage(10000.0)
	await process_frame
	_check(game.run_state == "result" and game.result_banked == 0, "Death banks zero despite contract and accumulated score")
	await _fresh()
	_check(game.score == 0 and game.depth == 1 and game.first_chest, "New run resets score, depth and starter entitlement")
	for rift in old_rifts:
		_check(not is_instance_valid(rift), "New run destroys each old rift")
	game.score = 123
	game.finish("extract")
	_check(game.result_banked == 123, "Extraction banks x1")
	print("RESULT death_zero/restart_clears/extract_x1=OK")

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
