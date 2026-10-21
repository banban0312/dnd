extends SceneTree
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	var music = game.music
	music.set_process(false)
	_check(music.process_mode == Node.PROCESS_MODE_ALWAYS, "Music keeps processing during world pause")
	_track_checks(music.exploration_player.stream, 42.6667, "exploration")
	_track_checks(music.boss_player.stream, 26.6667, "boss")
	music._process(1.0)
	_check(music.mode == "silent" and not music.exploration_player.playing and not music.boss_player.playing, "Title keeps music silent")
	game.start_run()
	_freeze_actors(game)
	var boss = game.boss
	music._process(0.25)
	_check(music.mode == "exploration" and is_equal_approx(music.exploration_gain, 0.25), "Exploration starts with one-second amplitude fade")
	music._process(0.75)
	_check(is_equal_approx(music.exploration_gain, 1) and is_equal_approx(music.exploration_player.volume_db, -18), "Exploration reaches quiet -18dB target")
	boss.awaken()
	music._process(0.4)
	_check(music.mode == "boss" and is_equal_approx(music.boss_gain, 0.4) and is_equal_approx(music.exploration_gain, 0.6), "Arena activation crossfades both tracks")
	music._process(0.6)
	_check(music.boss_player.playing and not music.exploration_player.playing and is_equal_approx(music.boss_player.volume_db, -14), "Boss reaches -14dB after exactly one second")
	for state in ["pause", "inventory", "reward", "gate"]:
		if state == "pause":
			game.ui.show_pause()
		elif state == "inventory":
			game.ui.show_inventory()
		elif state == "reward":
			game._open_chest(game.chests[0])
		else:
			game.ui.show_gate()
		music._process(0.5)
		_check(paused and music.mode == "boss" and music.boss_player.playing and music.boss_player.volume_db < -20, state + " keeps Boss track playing but ducks it")
		if state == "reward":
			game.cancel_reward()
		else:
			game.ui.close_modal()
	game.ui.show_pause()
	var toggle := _music_toggle(game.ui.modal)
	_check(toggle != null, "Actual pause menu exposes the music switch")
	toggle.button_pressed = false
	_check(music.muted and music.boss_player.volume_db <= -80, "Actual pause music switch mutes manager")
	toggle.button_pressed = true
	_check(not music.muted, "Actual pause music switch unmutes manager")
	game.ui.close_modal()
	music._process(0.5)
	_check(is_equal_approx(music.boss_player.volume_db, -14), "Resume restores Boss volume")
	music.set_muted(true)
	_check(music.muted and music.boss_player.volume_db <= -80 and music.exploration_player.volume_db <= -80, "Mute silences both music players immediately")
	music._process(1)
	_check(music.boss_player.volume_db <= -80, "Mute persists while manager runs")
	music.set_muted(false)
	_check(not music.muted and is_equal_approx(music.boss_player.volume_db, -14), "Unmute preserves mode and restores volume")
	boss.dead = true
	music._process(1)
	_check(music.mode == "exploration" and music.exploration_player.playing and not music.boss_player.playing, "Defeating Boss returns to exploration if run still active")
	game.ui.show_gate()
	game.gate_open = true
	game.descend()
	_freeze_actors(game)
	music._process(1)
	_check(game.depth == 2 and music.mode == "exploration", "Actual floor transition retains exploration without stale Boss")
	game.finish("extract")
	music._process(1)
	_check(music.mode == "silent" and not music.exploration_player.playing, "Result fades and stops music")
	game.ui.return_title()
	music._process(1)
	game.start_run()
	_freeze_actors(game)
	music._process(1)
	_check(game.music == music, "Restart reuses one manager without layering duplicate tracks")
	_check(music.mode == "exploration" and music.exploration_player.playing and not music.boss_player.playing, "New run restarts exploration without stale Boss mode")
	music.exploration_player.stop()
	music.boss_player.stop()
	paused = false
	game.queue_free()
	await process_frame
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("MVP MUSIC OK: original PCM lengths, full-track loops, sample peak/DC/seams, exact crossfade, Boss activation, pause duck, mute, result, actual floor transition and restart")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _track_checks(track: AudioStreamWAV, expected_length: float, name: String) -> void:
	_check(track != null and absf(track.get_length() - expected_length) < 0.01, name + " has the full 16-bar duration")
	_check(track.mix_rate == 44100 and track.format == AudioStreamWAV.FORMAT_16_BITS and not track.stereo, name + " is 44100Hz mono PCM16")
	_check(track.loop_mode == AudioStreamWAV.LOOP_FORWARD and track.loop_begin == 0 and track.loop_end == track.data.size() / 2, name + " loops the full PCM stream")
	var bytes := track.data
	var peak := 0
	var total := 0.0
	for index in range(0, bytes.size(), 2):
		var sample := bytes.decode_s16(index)
		peak = maxi(peak, absi(sample))
		total += sample
	var dc := total / (bytes.size() / 2) / 32768
	_check(peak > 15000 and peak < 30000, name + " has useful level and safe peak headroom")
	_check(absf(dc) < 0.001, name + " has negligible DC offset")
	_check(bytes.decode_s16(0) == 0 and bytes.decode_s16(bytes.size() - 2) == 0, name + " meets smoothly at its loop boundary")

func _check(condition: bool, description: String) -> void:
	if not condition:
		failures.append(description)

func _freeze_actors(game) -> void:
	game.player.set_physics_process(false)
	for actor in get_nodes_in_group("enemies"):
		actor.set_physics_process(false)

func _music_toggle(node: Node) -> CheckButton:
	if node is CheckButton and node.text == "播放背景音乐":
		return node
	for child in node.get_children():
		var button := _music_toggle(child)
		if button != null:
			return button
	return null
