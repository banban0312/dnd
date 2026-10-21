extends Node2D
## Three authored floors; persistent run equipment, no legacy save writes.
const World = preload("res://scripts/mvp_world.gd")
const Interface = preload("res://scripts/mvp_ui.gd")
const Foe = preload("res://scripts/mvp_enemy.gd")
const BossFoe = preload("res://scripts/mvp_boss.gd")
const Necromancer = preload("res://scripts/mvp_necromancer.gd")
const SpecialFoe = preload("res://scripts/mvp_special_enemy.gd")
const Music = preload("res://scripts/mvp_music.gd")
const Marker = preload("res://scripts/mvp_marker.gd")
const Rift = preload("res://scripts/mvp_rift.gd")

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
var contract_active := false
var pending_chest: Node2D
var reward_source := ""
var reward_options: Array[String] = []
var result_banked := 0
var reduced_flash := false
var arena_gate: StaticBody2D
var music: Node

func _ready() -> void:
	RenderingServer.set_default_clear_color(Color("0d1219"))
	rng.seed = seed_value
	music = Music.new()
	music.game = self
	add_child(music)
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
	contract_active = false
	pending_chest = null
	reward_source = ""
	reward_options.clear()
	result_banked = 0
	rng.seed = seed_value
	player = Player.new()
	player.mvp_block_tradeoff = true
	player.reduced_flash = reduced_flash
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
	arena_gate = null
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
		var enemy = _spawn_enemy(world.enemy_positions[i], i % 3 == 1, false, false, world.enemy_roles[i])
		var room_index: int = world.enemy_rooms[i]
		if room_index >= 0:
			enemy.encounter_rect = world.rooms[room_index]
		else:
			enemy.encounter_rect = Rect2(1280, 608, 192, 256)
	_spawn_enemy(world.boss_position, true, depth == 2, depth != 2)
	for pos in world.chest_positions:
		var chest = Marker.new()
		chest.position = pos
		contents.add_child(chest)
		chests.append(chest)
	exit_marker = Marker.new()
	exit_marker.kind = "exit"
	exit_marker.position = world.exit_position
	contents.add_child(exit_marker)
	if depth == 2 and contract_active:
		for i in world.hazard_positions.size():
			var rift := Rift.new()
			rift.position = world.hazard_positions[i]
			rift.phase_offset = i * 1.65
			contents.add_child(rift)

func _spawn_enemy(pos: Vector2, skeleton: bool, elite: bool, final_boss: bool, combat_role: String = "melee") -> Enemy:
	var special := combat_role in ["shieldbearer", "bone_weaver", "wisp", "summoned_skeleton"]
	var enemy = (Necromancer.new() if depth == 3 else BossFoe.new()) if final_boss else (SpecialFoe.new() if special else Foe.new())
	enemy.is_elite = elite
	enemy.is_boss = final_boss
	enemy.role = combat_role
	enemy.reduced_flash = reduced_flash
	enemy.position = pos
	enemy.collision_layer = 2
	enemy.collision_mask = 3
	enemy.anim_character = "ogre" if final_boss else ("skeleton" if combat_role == "ranged" or skeleton else "goblin")
	enemy.enemy_name = ("执杖骸骨大法师" if depth == 3 else "井底守望者") if final_boss else ("墓门执刑者" if elite else ("遗骨弩手" if combat_role == "ranged" else ("拾烬冲锋者" if combat_role == "charger" else "拾烬者")))
	enemy.max_hp = (720.0 if depth == 3 else 360.0) if final_boss else (150.0 if elite else (34.0 if combat_role == "ranged" else (42.0 if combat_role == "charger" else 28.0)) * (1.2 if depth > 1 else 1.0))
	enemy.contact_damage = 22.0 if final_boss else (16.0 if elite else (12.0 if combat_role == "ranged" else 13.0))
	enemy.chase_speed = 120.0 if final_boss else (85.0 if combat_role == "ranged" else 122.0)
	enemy.aggro_radius = 430.0
	if elite or final_boss:
		enemy.encounter_rect = world.rooms[2]
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

func _spawn_minion(pos: Vector2) -> Enemy:
	if run_state != "playing" or get_tree().get_nodes_in_group("necromancer_minions").size() >= 4:
		return null
	var minion := _spawn_enemy(pos, true, false, false, "summoned_skeleton")
	minion.encounter_rect = world.rooms[2]
	minion.acquire_aggro()
	if not minion.is_in_group("necromancer_minions"):
		minion.add_to_group("necromancer_minions")
	return minion

func _process(delta: float) -> void:
	if run_state != "playing" or not is_instance_valid(player):
		return
	elapsed += delta
	for chest in chests:
		chest.near = player.global_position.distance_to(chest.global_position) < 78
	exit_marker.near = player.global_position.distance_to(exit_marker.global_position) < 95
	exit_marker.unlocked = gate_open
	if is_instance_valid(boss) and not boss.dead and world.rooms[2].grow(-48).has_point(player.global_position):
		boss_seen = true
		boss.awaken()
		_lock_boss_arena()
	if Input.is_action_just_pressed("interact"):
		for chest in chests:
			if chest.near and not chest.opened:
				_open_chest(chest)
				return
		if exit_marker.near:
			if gate_open and depth < 3:
				run_state = "gate"
				ui.show_gate()
			else:
				_notify("升降梯仍在沉睡。找到本层的守门者。")


func _lock_boss_arena() -> void:
	if is_instance_valid(arena_gate) or not world.boss_gate_rect.has_area():
		return
	arena_gate = StaticBody2D.new()
	arena_gate.name = "ArenaGate"
	arena_gate.position = world.boss_gate_rect.position
	arena_gate.collision_layer = 1
	arena_gate.collision_mask = 0
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = world.boss_gate_rect.size
	shape.shape = rect
	shape.position = rect.size * 0.5
	arena_gate.add_child(shape)
	for y in range(4, int(rect.size.y), 16):
		var bar := Polygon2D.new()
		bar.polygon = PackedVector2Array([Vector2(0, y), Vector2(rect.size.x, y), Vector2(rect.size.x, y + 5), Vector2(0, y + 5)])
		bar.color = Color("8a7960")
		arena_gate.add_child(bar)
	contents.add_child(arena_gate)
	Sfx.play(SoundFactory.boss_roar(), -14.0)
	_notify("法师正在编织骨雨 · 留好闪避，举杖时及时进入金色保护罩" if depth == 3 else "圣所栅栏已落下 · 翻滚躲开重击与冲刺")

func _unhandled_input(event: InputEvent) -> void:
	if run_state == "playing":
		if event.is_action_pressed("inventory"):
			ui.show_inventory()
			get_viewport().set_input_as_handled()
		elif event.is_action_pressed("ui_cancel"):
			ui.show_pause()
			get_viewport().set_input_as_handled()

func _open_chest(chest: Node2D) -> void:
	if run_state != "playing" or not is_instance_valid(chest) or chest.opened:
		return
	if first_chest:
		pending_chest = chest
		reward_source = "starter"
		reward_options.assign(["recurve_bow", "piercing_bow"])
		run_state = "reward"
		ui.show_reward()
		return
	chest.opened = true
	var item: ItemData = _roll_equipment()
	_grant_item(item, chest.global_position)
	_grant_item(ItemData.red_potion() if depth == 1 else ItemData.blue_potion(), chest.global_position + Vector2(25, 0))
	score += 10
	Sfx.play(SoundFactory.chest(), -8.0)
	_notify("发现 %s · 按 I 比较并装备" % item.item_name)


func begin_contract() -> void:
	if run_state != "gate" or depth != 1 or not gate_open:
		return
	reward_source = "contract"
	reward_options.assign(["piercing_bow", "iron_plate"])
	run_state = "reward"
	ui.show_reward()


func claim_reward(item_id: String) -> bool:
	if run_state != "reward" or reward_source.is_empty():
		return false
	if item_id.is_empty() and reward_source != "contract":
		return false
	var reward_index := player.backpack.size()
	if not item_id.is_empty():
		if not reward_options.has(item_id):
			return false
		if player.backpack.size() >= Player.BACKPACK_SIZE:
			ui.show_reward("行囊已满：先返回并在 I 面板使用、装备或丢弃物品。")
			return false
		player.add_to_backpack(ItemData.from_name(item_id))
	var source := reward_source
	reward_source = ""
	reward_options.clear()
	if source == "starter":
		if is_instance_valid(pending_chest):
			pending_chest.opened = true
		pending_chest = null
		first_chest = false
		score += 10
		_grant_item(ItemData.red_potion(), player.position)
		run_state = "playing"
		ui.selected = reward_index
		ui.show_inventory()
		_notify("已收入行囊 · 选择新弓，点击装备此物")
	else:
		contract_active = true
		run_state = "gate"
		descend()
	return true


func cancel_reward() -> void:
	if run_state != "reward":
		return
	var source := reward_source
	reward_source = ""
	reward_options.clear()
	pending_chest = null
	if source == "contract":
		ui.show_gate()
	else:
		run_state = "playing"
		ui.show_game()

func _roll_equipment() -> ItemData:
	var blue := rng.randf() < (0.2 if depth == 1 else 0.6)
	if blue:
		return ItemData.from_name("piercing_bow") if rng.randf() < 0.5 else ItemData.iron_plate()
	return ItemData.recurve_bow() if rng.randf() < 0.5 else ItemData.from_name("ranger_leather")

func _on_enemy_died(enemy: Enemy) -> void:
	if run_state != "playing":
		return
	if enemy.is_in_group("necromancer_minions"):
		return
	kills += 1
	score += 50 if enemy.is_boss else (25 if enemy.is_elite else 3)
	if enemy.is_boss and depth == 3:
		call_deferred("finish", "victory")
		return
	if enemy.is_elite or enemy.is_boss:
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
	if depth >= 3 or not gate_open or run_state != "gate":
		return
	get_tree().paused = false
	run_state = "loading"
	depth += 1
	_build_floor()
	run_state = "playing"
	ui.show_game()
	if depth == 3:
		_notify("骸骨王庭 · 观察骨雨的缝隙；法师举杖时，四秒内进入金色保护罩")
	else:
		_notify("井契已唤醒：避开裂隙，通关累计分 ×2.5。I 装备新奖励" if contract_active else "无灯圣所 · 沿井缘前进，生命与补给不会自动恢复。")

func _on_player_died() -> void:
	call_deferred("finish", "death")

func finish(outcome: String) -> void:
	if run_state == "result":
		return
	if outcome not in ["death", "extract", "victory"]:
		return
	run_state = "result"
	var multiplier := (2.5 if contract_active else 2.0) if outcome == "victory" else 1.0
	var banked := 0 if outcome == "death" else int(score * multiplier)
	result_banked = banked
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


func discard(index: int) -> void:
	if run_state != "inventory":
		return
	player.drop_backpack_item(index)
	ui.selected = mini(ui.selected, maxi(0, player.backpack.size() - 1))
	ui.show_inventory()


func set_reduced_flash(enabled: bool) -> void:
	reduced_flash = enabled
	if is_instance_valid(player):
		player.reduced_flash = enabled
		player.modulate = Color.WHITE
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.reduced_flash = enabled
		enemy.modulate = Color.WHITE

func _notify(message: String) -> void:
	if is_instance_valid(ui):
		ui.notify(message)

func _capture_review() -> void:
	var folder := "res://_test/1080/" if "--review-1080" in OS.get_cmdline_user_args() else "res://_test/"
	DirAccess.make_dir_recursive_absolute(folder)
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_title.png")
	start_run()
	player.invuln_timer = 1000.0
	await get_tree().create_timer(0.6).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_game.png")
	_open_chest(chests[0])
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_reward.png")
	cancel_reward()
	for id in ["recurve_bow", "piercing_bow", "ranger_leather", "iron_plate"]:
		_grant_item(ItemData.from_name(id), player.position)
	ui.show_inventory()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_inventory.png")
	ui.close_modal()
	player.global_position = world.rooms[1].position + Vector2(120, 230)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await get_tree().create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_encounter.png")
	player.global_position = world.boss_position + Vector2(-110, 35)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	boss._begin_attack(player)
	await get_tree().create_timer(0.18).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_boss.png")
	player.invuln_timer = 1000.0
	boss.take_damage(10000.0)
	await get_tree().create_timer(1.75).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_boss_pillars.png")
	for pillar in get_tree().get_nodes_in_group("mvp_boss_pillars"):
		pillar.take_damage(10000.0)
	await get_tree().create_timer(0.28).timeout
	boss._begin_attack(player)
	await get_tree().create_timer(0.12).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_boss_phase2.png")
	boss._cancel_attack()
	boss.boss_move_index = 2
	boss._begin_attack(player)
	await get_tree().create_timer(0.2).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_boss_fan.png")
	boss.take_damage(10000.0)
	player.global_position = world.exit_position - Vector2(112, 0)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_well.png")
	ui.show_gate()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_gate.png")
	begin_contract()
	claim_reward("iron_plate")
	player.global_position = Vector2(1376, 992)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await get_tree().create_timer(0.1).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_depth2.png")
	gate_open = true
	ui.show_gate()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_gate3.png")
	descend()
	player.invuln_timer = 1000.0
	player.global_position = world.rooms[1].get_center() + Vector2(180, 100)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	await get_tree().create_timer(0.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_depth3.png")
	player.global_position = world.boss_position - Vector2(240, -100)
	(player.get_node("Camera2D") as Camera2D).reset_smoothing()
	boss.awaken()
	await get_tree().create_timer(2.4).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_necromancer.png")
	boss._prepare_summon()
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_summons.png")
	await get_tree().create_timer(1.3).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_boneflower.png")
	boss.take_damage(10000.0)
	await get_tree().create_timer(1.0).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_ritual.png")
	player.global_position = boss.safe_center
	await get_tree().create_timer(3.05).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(folder + "mvp_shelter.png")
	get_tree().paused = false
	print("Review captures saved")
	for voice in music.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	for sound in get_node("/root/Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()

func _smoke() -> void:
	start_run()
	await get_tree().process_frame
	assert(depth == 1 and player.hp > 0)
	assert(chests.size() > 0)
	_open_chest(chests[0])
	assert(run_state == "reward")
	assert(claim_reward("recurve_bow"))
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
	assert(is_instance_valid(boss), "First floor hosts the four-pillar Warden")
	boss.awaken()
	boss.take_damage(10000.0)
	assert(boss.shielded and boss.phase == 2, "Burst cannot skip the four pillars")
	boss._physics_process(2.0)
	assert(boss.pillars_remaining() == 4)
	for pillar in get_tree().get_nodes_in_group("mvp_boss_pillars"):
		pillar.take_damage(10000.0)
	assert(not boss.shielded)
	boss.take_damage(10000.0)
	assert(gate_open and run_state == "playing", "Warden unlocks first lift without ending run")
	ui.show_gate()
	descend()
	await get_tree().process_frame
	assert(depth == 2 and not is_instance_valid(boss))
	assert(get_tree().get_nodes_in_group("player").size() == 1)
	assert(get_tree().get_nodes_in_group("enemies").size() == world.enemy_positions.size() + 1)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy.is_elite:
			enemy.take_damage(10000.0)
	assert(gate_open)
	ui.show_gate()
	descend()
	await get_tree().process_frame
	assert(depth == 3 and is_instance_valid(boss))
	player.global_position = world.boss_position - Vector2(200, 0)
	boss.awaken()
	for threshold in 2:
		boss.take_damage(10000.0)
		assert(boss.shielded and boss.threshold_index == threshold + 1)
		player.global_position = boss.safe_center
		boss._physics_process(4.1)
		assert(not player.dead and not boss.shielded)
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
	for voice in music.get_children():
		if voice is AudioStreamPlayer:
			voice.stop()
	get_tree().paused = false
	for sound in get_node("/root/Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await get_tree().process_frame
	await get_tree().create_timer(0.25).timeout
	get_tree().quit()
