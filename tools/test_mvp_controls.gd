extends SceneTree
## Exercises physical keyboard events through the live player and focused modals.
var failures: Array[String] = []
var game

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.set_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	game.player.invuln_timer = 100.0
	await _eight_way_aim()
	for entry in [[KEY_W, "move_up"], [KEY_A, "move_left"], [KEY_S, "move_down"], [KEY_D, "move_right"], [KEY_J, "attack"], [KEY_K, "skill_1"], [KEY_L, "skill_2"], [KEY_SPACE, "dodge"], [KEY_H, "ai_chat"], [KEY_P, "skill_panel"]]:
		var event := _key(entry[0], true)
		_check(event.is_action_pressed(entry[1]), "Physical key maps to %s" % entry[1])
	for key in [KEY_Q, KEY_E, KEY_SHIFT]:
		var event := _key(key, true)
		_check(not event.is_action_pressed("attack") and not event.is_action_pressed("skill_1") and not event.is_action_pressed("skill_2") and not event.is_action_pressed("dodge"), "Removed legacy combat binding %s" % OS.get_keycode_string(key))
	_check(not _key(KEY_J, true).is_action_pressed("ai_chat"), "J no longer opens legacy AI chat")
	_check(not _key(KEY_K, true).is_action_pressed("skill_panel") and not _key(KEY_L, true).is_action_pressed("skill_panel"), "K/L no longer open legacy skill panel")
	_check(not _key(KEY_SPACE, true).is_action_pressed("ui_accept"), "Space cannot activate focused UI buttons")
	_check(_key(KEY_ENTER, true).is_action_pressed("ui_accept"), "Enter still accepts UI buttons")
	var start: Vector2 = game.player.position
	await _press(KEY_D)
	_check(game.player.position.x > start.x, "Physical D moves the live player")
	game.player.mp = game.player.max_mp
	game.player.skill_cd = 0.0
	var shots := [0]
	var record_shot := func(): shots[0] += 1
	game.player.stats_changed.connect(record_shot)
	game.player.attack_cd = 0.0
	Input.parse_input_event(_key(KEY_J, true))
	await create_timer(game.player._current_attack_interval() * 2.2).timeout
	Input.parse_input_event(_key(KEY_J, false))
	await physics_frame
	game.player.stats_changed.disconnect(record_shot)
	_check(shots[0] >= 2 and game.player.attack_cd > 0 and game.player.skill_cd == 0 and game.player.mp == game.player.max_mp, "Held physical J repeats normal attack without mana or skill cooldown")
	await _press(KEY_K)
	_check(game.player.skill_cd > 0 and game.player.mp < game.player.max_mp, "Physical K casts triple shot")
	game.player.skill_cd = 0.0
	await _press(KEY_L)
	_check(game.player.draw_speed_timer > 0, "Physical L casts draw speed")
	await _press(KEY_SPACE)
	_check(game.player.dodge_cd > 0, "Physical Space rolls")
	for mode in ["pause", "inventory", "reward"]:
		if mode == "pause":
			game.ui.show_pause()
		elif mode == "inventory":
			game.ui.show_inventory()
		else:
			game._open_chest(game.chests[0])
		var focus_button: Button = _first_button(game.ui.modal)
		_check(focus_button != null, "Modal has a focusable button: " + mode)
		focus_button.grab_focus()
		var mana: float = game.player.mp
		var count: int = game.player.backpack.size()
		game.player.attack_cd = 0.0
		game.player.skill_cd = 0.0
		game.player.dodge_cd = 0.0
		game.player.draw_speed_timer = 0.0
		for key in [KEY_SPACE, KEY_J, KEY_K, KEY_L]:
			await _press(key)
		_check(paused and game.run_state == mode, "Focused " + mode + " stays paused on Space/J/K/L")
		_check(game.player.mp == mana and game.player.attack_cd == 0 and game.player.skill_cd == 0 and game.player.draw_speed_timer == 0 and game.player.dodge_cd == 0, mode + " blocks casting and dodge")
		_check(game.player.backpack.size() == count, mode + " Space does not select/equip a reward")
		if mode == "reward":
			game.cancel_reward()
		else:
			game.ui.close_modal()
	await _boss_hud_checks()
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
		print("MVP CONTROLS OK: physical WASD/J/K/L/Space, held J normal attack, H/P isolation, removed Q/E/Shift, focus and paused modal safety, real Boss phase/ward HUD")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _key(code: int, pressed: bool) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _press(code: int) -> void:
	Input.parse_input_event(_key(code, true))
	await physics_frame
	await physics_frame
	Input.parse_input_event(_key(code, false))
	await physics_frame
	await process_frame

func _first_button(node: Node) -> Button:
	if node is Button:
		return node
	for child in node.get_children():
		var button := _first_button(child)
		if button != null:
			return button
	return null

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _boss_hud_checks() -> void:
	game.depth = 1
	game._build_floor()
	game.player.set_physics_process(false)
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	game.boss_seen = true
	var boss = game.boss
	boss.arena_active = true
	game.ui._process(0.0)
	_check(game.ui.boss_panel.visible and game.ui.boss_status.text == "I · 守望", "Live Boss HUD starts in phase I")
	boss.take_damage(boss.max_hp)
	game.ui._process(0.0)
	_check(game.ui.boss_status.text.contains("觉醒中") and game.ui.boss_status.text.contains("无敌"), "Actual phase transition HUD announces invulnerability")
	_check(game.ui.boss_fill.color == Color("84b4c2"), "Invulnerable Boss bar uses shield color")
	boss._physics_process(1.7)
	for pillar in boss.pillars.values():
		pillar.set_physics_process(false)
	game.ui._process(0.0)
	_check(game.ui.boss_status.text.contains("4 / 4") and game.ui.boss_status.text.contains("护盾无敌"), "Four live wards appear in Boss HUD")
	for count in [3, 2, 1, 0]:
		var pillar = boss.pillars.values()[0]
		pillar.take_damage(pillar.max_hp + 100)
		game.ui._process(0.0)
		if count > 0:
			_check(game.ui.boss_status.text.contains("%d / 4" % count), "Ward death updates HUD to remaining %d" % count)
		else:
			_check(game.ui.boss_status.text == "II · 狂怒 / 护盾已破", "Final ward death announces vulnerable phase II")
		_check(game.ui.boss_status.get_minimum_size().x <= 410.0, "Boss status stays within allocated text width")
	_check(game.ui.boss_fill.color == Color("b96154"), "Unshielded phase II restores damage bar color")
	await process_frame

func _eight_way_aim() -> void:
	game.player.set_physics_process(false)
	for keys in [[KEY_D], [KEY_D, KEY_S], [KEY_S], [KEY_S, KEY_A], [KEY_A], [KEY_A, KEY_W], [KEY_W], [KEY_W, KEY_D]]:
		game.player.position = game.world.player_spawn
		var expected := Vector2.ZERO
		for code in keys:
			Input.parse_input_event(_key(code, true))
			match code:
				KEY_W: expected.y -= 1
				KEY_S: expected.y += 1
				KEY_A: expected.x -= 1
				KEY_D: expected.x += 1
		expected = expected.normalized()
		Input.flush_buffered_events()
		await physics_frame
		game.player._physics_process(1.0 / 60.0)
		print("KEYBOARD_AIM expected=", expected, " input=", Input.get_vector("move_left", "move_right", "move_up", "move_down"), " actual=", game.player.facing)
		_check(game.player.facing.is_equal_approx(expected), "WASD selects aim " + str(expected))
		for code in keys:
			Input.parse_input_event(_key(code, false))
		var mouse := InputEventMouseMotion.new()
		mouse.position = Vector2(1200, 50)
		mouse.global_position = mouse.position
		Input.parse_input_event(mouse)
		Input.flush_buffered_events()
		await physics_frame
		game.player._physics_process(1.0 / 60.0)
		game.player._fire_arrow()
		var shot = get_nodes_in_group("arrows").back()
		_check(shot.direction.is_equal_approx(expected), "Real arrow retains keyboard aim after release and mouse movement " + str(expected))
		_check(is_equal_approx(shot.direction.length(), 1.0), "Diagonal arrows keep normalized speed")
		shot.free()
	game.player.set_physics_process(true)
