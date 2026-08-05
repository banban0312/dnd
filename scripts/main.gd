extends Node2D
class_name Main
## 主场景:管理地图生成、重生点、敌人经验结算、掉落生成、刷怪器、HUD 与重开。
## 组件(宝箱/存档点/敌人)通过信号上抛事件,不再反向调用本节点。

@onready var player: Player = $Player
@onready var spawner: Spawner = $Spawner
@onready var hud: Hud = $HUD
@onready var map_gen: MapGenerator = $MapGenerator

var respawn_point := Vector2.ZERO


func _ready() -> void:
	hud.setup(player, spawner, self)
	player.died.connect(_on_player_died)
	player.notify.connect(hud.show_message)
	spawner.enemy_spawned.connect(_on_enemy_spawned)
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.died.connect(_on_enemy_died)
		enemy.drop_requested.connect(_on_enemy_drop_requested)
	if SaveManager.has_save():
		_show_continue_menu()
	else:
		_start_new_game()
		hud.show_message("新游戏:大型地牢随机生成 · 左键连射 · Q/E 技能 · Shift 闪避 · T 刷怪开关")


## 新游戏:随机种子生成地图,玩家保持初始状态
func _start_new_game() -> void:
	map_gen.rng_seed = 0
	_setup_world()


## 继续游戏:读档恢复角色状态与地图种子
func _continue_game() -> void:
	var data := SaveManager.load_game()
	if data.is_empty():
		_start_new_game()
		return
	map_gen.rng_seed = int(data.get("rng_seed", 0))
	_setup_world()
	player.import_state(data.get("player", {}))
	respawn_point = data.get("respawn", map_gen.save_point_pos)
	hud.show_message("欢迎回来,冒险者(Lv%d)" % player.level)


## 生成地图并把玩家/敌人/宝箱/刷怪点布置到位
func _setup_world() -> void:
	map_gen.generate()
	_setup_camera()
	player.global_position = map_gen.player_spawn
	respawn_point = _pick_respawn()
	spawner.spawn_points = map_gen.enemy_points.duplicate()
	_place_fixed_enemies()
	_spawn_chests()
	_spawn_boss()


func _setup_camera() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam == null:
		return
	cam.limit_left = 0
	cam.limit_top = 0
	cam.limit_right = int(map_gen.map_size.x)
	cam.limit_bottom = int(map_gen.map_size.y)


## 将场景中手放的固定巡逻敌人移到生成器给出的安全点
func _place_fixed_enemies() -> void:
	var fixed: Array[Dictionary] = [
		{"node": $Goblin1, "type": "goblin"},
		{"node": $Goblin2, "type": "goblin"},
		{"node": $Skeleton1, "type": "skeleton"},
		{"node": $Skeleton2, "type": "skeleton"},
	]
	var idx := 0
	for entry in fixed:
		var enemy := entry.node as Enemy
		if enemy == null or idx >= map_gen.enemy_points.size():
			continue
		EnemyData.apply_to(enemy, entry.type)
		var p := map_gen.enemy_points[idx]
		enemy.global_position = p
		enemy.patrol_points = [p, map_gen.patrol_targets[idx]]
		idx += 1


func _spawn_chests() -> void:
	for pos in map_gen.chest_points:
		var chest := Chest.new()
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(36, 30)
		shape.shape = rect
		chest.add_child(shape)
		var visual := Sprite2D.new()
		visual.name = "Visual"
		visual.texture = load("res://assets/sprites/chest_closed.png")
		chest.add_child(visual)
		chest.global_position = pos
		chest.potion_requested.connect(spawn_potion)
		chest.xp_requested.connect(_on_chest_xp_requested)
		add_child(chest)


## 生成中心 Boss:独眼巨魔(注入领地/数值,连接血条/掉落/经验信号)
func _spawn_boss() -> void:
	var boss := Boss.new()
	boss.enemy_name = "独眼巨魔"
	boss.max_hp = 800.0
	boss.move_speed = 55.0
	boss.chase_speed = 120.0
	boss.contact_damage = 25.0
	boss.attack_interval = 1.2
	boss.xp_reward = 200
	boss.arena_rect = map_gen.boss_arena
	boss.home_pos = map_gen.boss_spawn
	_build_boss_body(boss)
	boss.global_position = map_gen.boss_spawn
	add_child(boss)
	boss.died.connect(_on_enemy_died)
	boss.died.connect(func(): hud.hide_boss_bar())
	boss.drop_requested.connect(_on_enemy_drop_requested)
	boss.health_changed.connect(hud.update_boss_bar)
	hud.show_boss_bar(boss)


## Boss 物理节点:碰撞体(70×70)+ 接触伤害区(64×64)
func _build_boss_body(boss: Boss) -> void:
	boss.collision_layer = Spawner.ENEMY_LAYER
	boss.collision_mask = 3
	var body_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(70, 70)
	body_shape.shape = rect
	boss.add_child(body_shape)
	var contact := Area2D.new()
	contact.name = "ContactArea"
	contact.collision_layer = 0
	contact.collision_mask = 1
	var contact_shape := CollisionShape2D.new()
	var c_rect := RectangleShape2D.new()
	c_rect.size = Vector2(64, 64)
	contact_shape.shape = c_rect
	contact.add_child(contact_shape)
	boss.add_child(contact)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("skill_panel"):
		hud.toggle_skill_panel()
	elif event.is_action_pressed("inventory"):
		hud.toggle_inventory_panel()
	elif event.is_action_pressed("restart"):
		get_tree().reload_current_scene()
	elif event is InputEventKey and event.pressed and event.keycode == KEY_T:
		spawner.set_spawning(not spawner.enabled)
		hud.refresh_debug()
		player.notify.emit("刷怪: %s" % ("开启" if spawner.enabled else "关闭"))
	elif event is InputEventKey and event.pressed and event.keycode == KEY_U:
		player.set_debug_cheats(not player.debug_no_cd)
		hud.refresh_debug()
		player.notify.emit("无限蓝+无CD: %s" % ("开启" if player.debug_no_cd else "关闭"))


## 存档点激活:记录重生点并立即写盘
## 从所有房间门洞中随机挑一个作为复活点(fallback:玩家出生点)
func _pick_respawn() -> Vector2:
	var doors: Array[Vector2] = map_gen.door_centers
	if doors.is_empty():
		return map_gen.player_spawn
	return doors[randi() % doors.size()]


func save_now() -> void:
	SaveManager.save_game(player, map_gen, respawn_point)
	player.notify.emit("已保存")


## ---- 启动菜单:继续游戏 / 新游戏 ----
func _show_continue_menu() -> void:
	get_tree().paused = true
	var layer := CanvasLayer.new()
	layer.name = "ContinueMenu"
	layer.layer = 100
	add_child(layer)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.05, 0.85)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	dim.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(dim)
	var title := Label.new()
	title.text = "Darker and Darker"
	title.position = Vector2(430, 250)
	title.size = Vector2(420, 60)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", Color(0.9, 0.72, 0.38))
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	title.add_theme_constant_override("outline_size", 6)
	title.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(title)
	var sub := Label.new()
	sub.text = "地牢深处,黑暗等待着…"
	sub.position = Vector2(430, 316)
	sub.size = Vector2(420, 30)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 16)
	sub.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	sub.add_theme_constant_override("outline_size", 3)
	sub.process_mode = Node.PROCESS_MODE_ALWAYS
	layer.add_child(sub)
	var btn_continue := _make_menu_button(layer, "继续游戏", Vector2(520, 370))
	btn_continue.pressed.connect(_on_menu_continue.bind(layer))
	var btn_new := _make_menu_button(layer, "新游戏", Vector2(520, 426))
	btn_new.pressed.connect(_on_menu_new.bind(layer))


func _make_menu_button(parent: CanvasLayer, text: String, pos: Vector2) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = Vector2(240, 44)
	btn.add_theme_font_size_override("font_size", 18)
	btn.add_theme_stylebox_override("normal", _menu_style(Color(0.11, 0.09, 0.11, 0.96)))
	btn.add_theme_stylebox_override("hover", _menu_style(Color(0.2, 0.16, 0.12, 1.0)))
	btn.add_theme_stylebox_override("pressed", _menu_style(Color(0.26, 0.2, 0.12, 1.0)))
	btn.add_theme_color_override("font_color", Color(0.9, 0.86, 0.78))
	btn.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(btn)
	return btn


func _menu_style(bg: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = Color(0.42, 0.31, 0.15)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	return sb


func _on_menu_continue(layer: CanvasLayer) -> void:
	get_tree().paused = false
	layer.queue_free()
	_continue_game()


func _on_menu_new(layer: CanvasLayer) -> void:
	get_tree().paused = false
	layer.queue_free()
	SaveManager.delete_save()
	_start_new_game()
	hud.show_message("新游戏:大型地牢随机生成 · 左键连射 · Q/E 技能 · Shift 闪避 · T 刷怪开关")


## ---- 信号回调 ----
func _on_enemy_spawned(enemy: Enemy) -> void:
	enemy.died.connect(_on_enemy_died)
	enemy.drop_requested.connect(_on_enemy_drop_requested)


func _on_enemy_died(enemy: Enemy) -> void:
	player.add_xp(enemy.xp_reward)


func _on_enemy_drop_requested(pos: Vector2, item: ItemData) -> void:
	match item.item_type:
		ItemData.ItemType.POTION:
			spawn_potion(pos, item)
		_:
			spawn_equipment(pos, item)


func _on_chest_xp_requested(amount: int) -> void:
	player.add_xp(amount)


func _on_player_died() -> void:
	respawn_point = _pick_respawn()
	player.respawn_at(respawn_point)
	save_now()
	hud.show_message("你倒下了……在门洞处复活,已保存")


func spawn_potion(pos: Vector2, item: ItemData) -> void:
	var pickup := PotionPickup.new()
	pickup.setup(item)
	pickup.global_position = pos
	add_child(pickup)


func spawn_equipment(pos: Vector2, item: ItemData) -> void:
	var pickup := EquipmentPickup.new()
	pickup.setup(item)
	pickup.global_position = pos
	add_child(pickup)
