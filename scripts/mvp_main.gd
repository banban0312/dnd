extends Node2D
## Review build: two floors, six items, no writes to legacy saves.
const World = preload("res://scripts/mvp_world.gd")
const Interface = preload("res://scripts/mvp_ui.gd")
const Foe = preload("res://scripts/mvp_enemy.gd")
const Marker = preload("res://scripts/mvp_marker.gd")

var world: Node2D
var contents: Node2D
var player: Player
var ui: CanvasLayer
var depth := 1
var run_state := "title"
var score := 0
var kills := 0
var elapsed := 0.0
var normal_misses := 0
var seed_value := 4217
var rng := RandomNumberGenerator.new()
var gate_open := false
var exit_marker: Node2D
var chests: Array[Node2D] = []
var boss: Enemy
var first_chest := true
var best_score := 0
var boss_seen := false

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0d1219"))
	rng.seed = seed_value
	_build_preview()
	ui = Interface.new()
	ui.game = self
	add_child(ui)
	ui.show_title()
	if "--smoke" in OS.get_cmdline_user_args():
		call_deferred("_smoke")
	if "--review-capture" in OS.get_cmdline_user_args():
		call_deferred("_capture_review")

func _build_preview() -> void:
	world = World.new()
	world.build(1, seed_value)
	add_child(world)
	var camera := Camera2D.new()
	camera.name = "PreviewCamera"
	camera.position = Vector2(600, 430)
	add_child(camera)

func start_run() -> void:
	get_tree().paused = false
	run_state = "loading"
	if is_instance_valid(player):
		player.free()
	if has_node("PreviewCamera"):
		get_node("PreviewCamera").queue_free()
	depth = 1
	score = 0
	kills = 0
	elapsed = 0.0
	normal_misses = 0
	first_chest = true
	rng.seed = seed_value
	player = Player.new()
	player.name = "Player"
	player.collision_layer = 1
	player.collision_mask = 3
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(26, 26)
	shape.shape = rect
	player.add_child(shape)
	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	visual.sprite_frames = AnimFactory.make_frames("ranger")
	visual.scale = Vector2(2.5, 2.5)
	visual.position.y = -15
	player.add_child(visual)
	var camera := Camera2D.new()
	camera.name = "Camera2D"
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7.0
	player.add_child(camera)
	add_child(player)
	player.quickbar = [ItemData.red_potion(), ItemData.red_potion(), ItemData.blue_potion()]
	player.notify.connect(_notify)
	player.died.connect(_on_player_died)
	player.item_dropped.connect(_drop_item)
	_build_floor()
	run_state = "playing"
	ui.show_game()
	_notify("封土回廊 · 搜寻补给，击败守门者。I 查看装备")

func _build_floor() -> void:
	# Player stays outside the disposable floor; all arrows and actors are cleared.
	for arrow in get_tree().get_nodes_in_group("arrows"):
		arrow.free()
	if is_instance_valid(contents):
		contents.free()
	if is_instance_valid(world):
		world.free()
	chests.clear()
	boss = null
	boss_seen = false
	gate_open = false
	world = World.new()
	world.build(depth, seed_value + depth * 101)
	add_child(world)
	move_child(world, 0)
	contents = Node2D.new()
	contents.name = "FloorContents"
	contents.y_sort_enabled = true
	add_child(contents)
	player.global_position = world.player_spawn
	player.velocity = Vector2.ZERO
	player.invuln_timer = 1.5
	player.attack_cd = 0.0
	player.burst_remaining = 0
	var camera := player.get_node("Camera2D") as Camera2D
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(world.map_size.x)
	camera.limit_bottom = int(world.map_size.y)
	camera.reset_smoothing()
	for i in world.enemy_positions.size():
		_spawn_enemy(world.enemy_positions[i], i % 3 == 1, false, false)
	_spawn_enemy(world.boss_position, true, depth == 1, depth == 2)
	for pos in world.chest_positions:
		var chest = Marker.new()
		chest.position = pos
		contents.add_child(chest)
		chests.append(chest)
	exit_marker = Marker.new()
	exit_marker.kind = "exit"
	exit_marker.position = world.exit_position
	contents.add_child(exit_marker)

func _spawn_enemy(pos: Vector2, skeleton: bool, elite: bool, final_boss: bool) -> Enemy:
	var enemy = Foe.new()
	enemy.is_elite = elite
	enemy.is_boss = final_boss
	enemy.position = pos
	enemy.collision_layer = 2
	enemy.collision_mask = 3
	enemy.anim_character = "ogre" if final_boss else ("skeleton" if skeleton else "goblin")
	enemy.enemy_name = "井底守望者" if final_boss else ("墓门执刑者" if elite else ("遗骨哨兵" if skeleton else "拾烬者"))
	enemy.max_hp = 260.0 if final_boss else (85.0 if elite else (38.0 if skeleton else 28.0) * (1.2 if depth == 2 else 1.0))
	enemy.contact_damage = 22.0 if final_boss else (16.0 if elite else 10.0)
	enemy.chase_speed = 92.0 if final_boss else (90.0 if skeleton else 115.0)
	enemy.aggro_radius = 430.0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(58, 58) if final_boss else Vector2(26, 26)
	shape.shape = rect
	enemy.add_child(shape)
	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	visual.sprite_frames = AnimFactory.make_frames(enemy.anim_character)
	visual.scale = Vector2.ONE * (3.6 if final_boss else (2.7 if elite else 2.0))
	visual.play("idle")
	visual.position.y = -10
	enemy.add_child(visual)
	var contact := Area2D.new()
	contact.name = "ContactArea"
	contact.collision_layer = 0
	contact.collision_mask = 0
	enemy.add_child(contact)
	enemy.died.connect(_on_enemy_died)
	contents.add_child(enemy)
	if final_boss:
		boss = enemy
	return enemy

func _process(delta: float) -> void:
	if run_state != "playing" or not is_instance_valid(player):
		return
	elapsed += delta
	for chest in chests:
		chest.near = player.global_position.distance_to(chest.global_position) < 78
	exit_marker.near = player.global_position.distance_to(exit_marker.global_position) < 95
	exit_marker.unlocked = gate_open
	if is_instance_valid(boss) and not boss.dead and player.global_position.distance_to(boss.global_position) < 430:
		boss_seen = true
	if Input.is_action_just_pressed("interact"):
		for chest in chests:
			if chest.near and not chest.opened:
				_open_chest(chest)
				return
		if exit_marker.near:
			if gate_open and depth == 1:
				run_state = "gate"
				ui.show_gate()
			else:
				_notify("升降梯仍在沉睡。找到本层的守门者。")

func _unhandled_input(event: InputEvent) -> void:
	if run_state == "playing":
		if event.is_action_pressed("inventory"):
			ui.show_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			ui.show_pause()
			get_viewport().set_input_as_handled()

func _open_chest(chest: Node2D) -> void:
	if chest.opened:
		return
	chest.opened = true
	var item: ItemData
	if first_chest:
		item = ItemData.recurve_bow()
		first_chest = false
	else:
		item = _roll_equipment()
	_grant_item(item, chest.global_position)
	_grant_item(ItemData.red_potion() if depth == 1 else ItemData.blue_potion(), chest.global_position + Vector2(25, 0))
	score += 10
	Sfx.play(SoundFactory.chest(), -8.0)
	_notify("发现 %s · 按 I 比较并装备" % item.item_name)

func _roll_equipment() -> ItemData:
	var blue := rng.randf() < (0.2 if depth == 1 else 0.6)
	if blue:
		return ItemData.from_name("piercing_bow") if rng.randf() < 0.5 else ItemData.iron_plate()
	return ItemData.recurve_bow() if rng.randf() < 0.5 else ItemData.from_name("ranger_leather")

func _on_enemy_died(enemy: Enemy) -> void:
	if run_state != "playing":
		return
	kills += 1
	score += 50 if enemy.is_boss else (25 if enemy.is_elite else 3)
	if enemy.is_boss:
		call_deferred("finish", "victory")
		return
	if enemy.is_elite:
		gate_open = true
		_grant_item(_roll_equipment(), enemy.global_position)
		_notify("守门者已倒下 · 前往房间尽头的升降梯")
	else:
		if normal_misses >= 8 or rng.randf() < 0.10:
			normal_misses = 0
			_grant_item(_roll_equipment(), enemy.global_position)
		else:
			normal_misses += 1

func _grant_item(item: ItemData, pos: Vector2) -> void:
	if item == null:
		return
	if not player.add_to_backpack(item):
		_drop_item(item, pos)
	else:
		_notify("收入行囊：%s · I 比较 / 装备" % item.item_name)

func start_equipment_review() -> void:
	start_run()
	for id in ["recurve_bow", "piercing_bow", "ranger_leather", "iron_plate"]:
		_grant_item(ItemData.from_name(id), player.global_position)
	ui.show_inventory()

func _drop_item(item: ItemData, pos: Vector2) -> void:
	var pickup := EquipmentPickup.new()
	pickup.setup(item)
	pickup.position = pos
	contents.call_deferred("add_child", pickup)

func descend() -> void:
	get_tree().paused = false
	run_state = "loading"
	depth = 2
	_build_floor()
	run_state = "playing"
	ui.show_game()
	_notify("无灯圣所 · 井底守望者正在等待。生命与补给不会自动恢复。")

func _on_player_died() -> void:
	call_deferred("finish", "death")

func finish(outcome: String) -> void:
	if run_state == "result":
		return
	run_state = "result"
	var banked := 0 if outcome == "death" else int(score * (2.0 if outcome == "victory" else 1.0))
	best_score = maxi(best_score, banked)
	ui.show_result(outcome, banked)

func equip(index: int) -> void:
	var item := player.backpack_at(index)
	if item == null:
		return
	if item.item_type == ItemData.ItemType.POTION:
		if player.add_item_to_quickbar(item):
			player.remove_from_backpack(index)
		else:
			player.use_backpack_item(index)
	else:
		var slot := "weapon" if item.item_type == ItemData.ItemType.WEAPON else "armor"
		var previous: ItemData = player.equipment[slot]
		player.remove_from_backpack(index)
		player.equip_item(slot, item)
		if previous != null:
			player.add_to_backpack(previous)
	ui.show_inventory()

func _notify(message: String) -> void:
	if is_instance_valid(ui):
		ui.notify(message)

func _capture_review() -> void:
	DirAccess.make_dir_recursive_absolute("res://_test")
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_test/mvp_title.png")
	start_run()
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_test/mvp_game.png")
	for id in ["recurve_bow", "piercing_bow", "ranger_leather", "iron_plate"]:
		_grant_item(ItemData.from_name(id), player.position)
	ui.show_inventory()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_test/mvp_inventory.png")
	ui.close_modal()
	gate_open = true
	ui.show_gate()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_test/mvp_gate.png")
	descend()
	player.global_position = world.boss_position + Vector2(-110, 35)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	boss._begin_attack(player)
	await get_tree().create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://_test/mvp_boss.png")
	get_tree().paused = false
	print("Review captures saved")
	for sound in get_node("/root/Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await get_tree().process_frame
	get_tree().quit()

func _smoke() -> void:
	start_run()
	await get_tree().process_frame
	assert(depth == 1 and player.hp > 0)
	assert(chests.size() > 0)
	_open_chest(chests[0])
	assert(player.backpack.size() >= 1)
	assert(chests[0].opened)
	var before := player.backpack.size()
	_open_chest(chests[0])
	assert(player.backpack.size() == before, "Opened chest cannot grant twice")
	# Normal input never opens an opened chest; verify marker state survives UI.
	ui.show_inventory()
	equip(0)
	assert(player.equipment.weapon.item_id == "recurve_bow")
	assert(player.backpack.size() == before)
	ui.close_modal()
	var elite: Enemy
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_elite:
			elite = enemy
	assert(is_instance_valid(elite))
	elite.take_damage(10000.0)
	assert(gate_open, "Defeating the elite unlocks the lift")
	ui.show_gate()
	descend()
	await get_tree().process_frame
	assert(depth == 2 and is_instance_valid(boss))
	assert(get_tree().get_nodes_in_group("player").size() == 1)
	assert(get_tree().get_nodes_in_group("enemies").size() == world.enemy_positions.size() + 1)
	boss.take_damage(10000.0)
	await get_tree().process_frame
	assert(run_state == "result")
	start_run()
	await get_tree().process_frame
	assert(depth == 1 and kills == 0 and normal_misses == 0)
	assert(player.equipment.weapon.item_id == "survival_bow")
	player.invuln_timer = 0
	player.take_damage(10000.0)
	await get_tree().process_frame
	assert(run_state == "result", "Death ends the run without respawning")
	await get_tree().process_frame
	print("MVP smoke OK: start, loot, equip, floor cleanup, victory, restart, death")
	get_tree().paused = false
	for sound in get_node("/root/Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()
