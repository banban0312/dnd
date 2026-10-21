extends Node
## Run as a scene so project autoloads are available.

func _ready() -> void:
	call_deferred("_run")

func _run() -> void:
	var game = load("res://main.tscn").instantiate()
	add_child(game)
	await get_tree().process_frame
	var menu = game.get_node_or_null("ContinueMenu")
	if menu != null:
		# J must not open a second pause owner before choosing a game.
		game.hud.ai_chat_panel.open()
		if game.hud.ai_chat_panel.visible:
			printerr("FAIL: AI chat opens over the startup menu and can resume an uninitialized world")
			get_tree().quit(1)
			return
		assert(get_tree().paused, "Startup menu must keep the world paused")
		if "--new" in OS.get_cmdline_user_args():
			# Exercise new-world initialization without deleting the user's save.
			get_tree().paused = false
			menu.queue_free()
			game._start_new_game()
		else:
			game._on_menu_continue(menu)
	await get_tree().process_frame
	assert(not get_tree().paused, "Starting the game must resume simulation")
	assert(game.map_gen.rooms.size() == 9, "Starting must generate all nine rooms")
	assert(game.player.hp > 0, "Player must start alive")
	assert(get_tree().get_nodes_in_group("enemies").size() >= 5, "Enemies and boss must spawn")
	game.hud.ai_chat_panel.open()
	assert(game.hud.ai_chat_panel.visible and get_tree().paused, "Chat must pause a running game")
	game.hud.ai_chat_panel.close()
	assert(not get_tree().paused, "Closing chat must resume a running game")
	for i in range(120):
		await get_tree().physics_frame
	print("Startup smoke OK")
	get_tree().quit()
