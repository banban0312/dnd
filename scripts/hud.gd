extends CanvasLayer
class_name Hud
## HUD:暗黑史诗风状态栏/装备栏/技能栏/测试工具(纯代码构建 UI)。

const BAR_WIDTH := 260.0

## 主题色:暗底 + 暗金描边
const C_PANEL := Color(0.055, 0.045, 0.075, 0.97)
const C_GOLD := Color(0.72, 0.55, 0.25)
const C_GOLD_DIM := Color(0.42, 0.31, 0.15)
const C_TEXT := Color(0.9, 0.86, 0.78)
const C_TITLE := Color(0.9, 0.72, 0.38)

var player: Player
var spawner: Spawner
## 主场景引用(用于手动存档)
var main_ref: Main

var level_label: Label
var hp_bar: ColorRect
var hp_label: Label
var mp_bar: ColorRect
var mp_label: Label
var xp_bar: ColorRect
var xp_label: Label
var buff_label: Label
var quick_label: Label
var equip_label: Label
var message_label: Label
var message_timer := 0.0
var skill_panel: Control
var inventory_panel: Control
var skill_points_label: Label
var skill_speed_label: Label
var skill_regen_label: Label
var inv_quick_label: Label
var inv_weapon_label: Label
var inv_armor_label: Label
var debug_panel: Control
var spawn_button: Button
var cheat_button: Button
var enemy_count_label: Label
var debug_tick := 0.0


func setup(p_player: Player, p_spawner: Spawner = null, p_main: Main = null) -> void:
	player = p_player
	spawner = p_spawner
	main_ref = p_main
	_build_ui()
	player.stats_changed.connect(_refresh_stats)
	player.inventory_changed.connect(_refresh_inventory)
	_refresh_stats()
	_refresh_inventory()
	refresh_debug()


func _process(delta: float) -> void:
	if message_timer > 0.0:
		message_timer -= delta
		message_label.modulate.a = clampf(message_timer, 0.0, 1.0)
		if message_timer <= 0.0:
			message_label.visible = false
	debug_tick += delta
	if debug_tick >= 0.25:
		debug_tick = 0.0
		refresh_debug()


func show_message(text: String) -> void:
	message_label.text = text
	message_label.visible = true
	message_label.modulate.a = 1.0
	message_timer = 3.0


func toggle_skill_panel() -> void:
	skill_panel.visible = not skill_panel.visible
	_refresh_stats()


func toggle_inventory_panel() -> void:
	inventory_panel.visible = not inventory_panel.visible
	_refresh_inventory()


func refresh_debug() -> void:
	if spawner == null:
		return
	spawn_button.text = "刷怪: %s" % ("开启" if spawner.enabled else "关闭")
	enemy_count_label.text = "场上敌人: %d" % get_tree().get_nodes_in_group("enemies").size()
	if cheat_button != null and player != null:
		cheat_button.text = "无限蓝+无CD: %s" % ("开启" if player.debug_no_cd else "关闭")


func _build_ui() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	## 状态面板
	var status_panel := _make_panel(root, Vector2(16, 12), Vector2(300, 196), "角色状态")
	level_label = _make_label(status_panel, "Lv 1 · 游侠", Vector2(14, 34), 18)
	level_label.add_theme_color_override("font_color", C_TITLE)
	hp_bar = _make_bar(status_panel, Vector2(14, 58), Color(0.72, 0.14, 0.1))
	hp_label = _make_label(status_panel, "HP 100/100", Vector2(14, 56), 13)
	mp_bar = _make_bar(status_panel, Vector2(14, 82), Color(0.2, 0.42, 0.82))
	mp_label = _make_label(status_panel, "MP 50/50", Vector2(14, 80), 13)
	xp_bar = _make_bar(status_panel, Vector2(14, 106), Color(0.72, 0.56, 0.2))
	xp_label = _make_label(status_panel, "经验 0/50", Vector2(14, 104), 12)
	buff_label = _make_label(status_panel, "", Vector2(14, 126), 13)
	buff_label.add_theme_color_override("font_color", Color(1.0, 0.85, 0.35))
	quick_label = _make_label(status_panel, "快捷栏: [1]空 [2]空 [3]空", Vector2(14, 148), 13)
	equip_label = _make_label(status_panel, "武器: 无 | 防具: 无", Vector2(14, 170), 13)

	## 世界消息
	message_label = _make_label(root, "", Vector2(0, 655), 19)
	message_label.size = Vector2(1280, 32)
	message_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message_label.add_theme_color_override("font_color", C_TITLE)
	message_label.add_theme_constant_override("outline_size", 4)
	message_label.visible = false

	_build_skill_panel(root)
	_build_inventory_panel(root)
	_build_debug_panel(root)


func _build_skill_panel(parent: Control) -> void:
	skill_panel = _make_panel(parent, Vector2(440, 190), Vector2(400, 280), "技能 · 游侠")
	skill_panel.visible = false
	skill_points_label = _make_label(skill_panel, "技能点: 0", Vector2(14, 42), 16)
	skill_points_label.add_theme_color_override("font_color", C_TITLE)
	skill_speed_label = _make_label(skill_panel, "Q 三连发 Lv1", Vector2(14, 74), 14)
	skill_regen_label = _make_label(skill_panel, "E 拉弓加速 Lv1", Vector2(14, 100), 14)
	_make_button(skill_panel, "升级三连发", Vector2(272, 68), Vector2(114, 30), _on_upgrade_triple)
	_make_button(skill_panel, "升级拉弓", Vector2(272, 94), Vector2(114, 30), _on_upgrade_draw)
	_make_label(skill_panel, "按 K 关闭面板", Vector2(14, 240), 12)


func _build_inventory_panel(parent: Control) -> void:
	inventory_panel = _make_panel(parent, Vector2(440, 150), Vector2(400, 330), "背包与装备")
	inventory_panel.visible = false
	inv_quick_label = _make_label(inventory_panel, "快捷栏(掉落物):", Vector2(14, 42), 14)
	inv_weapon_label = _make_label(inventory_panel, "武器: 无", Vector2(14, 68), 14)
	inv_armor_label = _make_label(inventory_panel, "防具: 无", Vector2(14, 92), 14)
	_make_label(inventory_panel, "武器选择(测试):", Vector2(14, 124), 13)
	var bows: Array[ItemData] = [
		ItemData.survival_bow(),
		ItemData.recurve_bow(),
		ItemData.longbow(),
		ItemData.elven_bow(),
	]
	for i in bows.size():
		_make_button(inventory_panel, bows[i].item_name, Vector2(14 + i * 95, 146), Vector2(90, 30),
			_on_equip_bow.bind(bows[i]))
	_make_label(inventory_panel, "按 I 关闭面板 · 1/2/3 用药水", Vector2(14, 196), 12)
	_make_label(inventory_panel, "装备默认增加最大生命,精灵弓额外加速箭矢", Vector2(14, 218), 11)


func _build_debug_panel(parent: Control) -> void:
	debug_panel = _make_panel(parent, Vector2(1016, 16), Vector2(248, 214), "测试工具")
	spawn_button = _make_button(debug_panel, "刷怪: 开启", Vector2(12, 38), Vector2(224, 30), _on_spawn_toggle_pressed)
	cheat_button = _make_button(debug_panel, "无限蓝+无CD: 关闭", Vector2(12, 72), Vector2(224, 30), _on_cheat_toggle_pressed)
	var save_button := _make_button(debug_panel, "手动存档", Vector2(12, 106), Vector2(224, 30), _on_save_pressed)
	enemy_count_label = _make_label(debug_panel, "场上敌人: 0", Vector2(12, 146), 13)
	_make_label(debug_panel, "T 刷怪 · U 无限蓝无CD · 存档点自动保存", Vector2(12, 170), 11)
	save_button.tooltip_text = "立即把当前进度写入本地存档"


func _refresh_stats() -> void:
	if player == null:
		return
	level_label.text = "Lv %d · 游侠" % player.level
	hp_label.text = "HP %d/%d" % [int(player.hp), int(player.max_hp)]
	hp_bar.size.x = (BAR_WIDTH - 2.0) * clampf(player.hp / player.max_hp, 0.0, 1.0)
	mp_label.text = "MP ∞" if player.debug_infinite_mp else "MP %d/%d" % [int(player.mp), int(player.max_mp)]
	mp_bar.size.x = (BAR_WIDTH - 2.0) * clampf(player.mp / player.max_mp, 0.0, 1.0)
	xp_label.text = "经验 %d/%d" % [player.xp, player.xp_to_next]
	xp_bar.size.x = (BAR_WIDTH - 2.0) * clampf(float(player.xp) / float(player.xp_to_next), 0.0, 1.0)
	buff_label.text = "拉弓加速中" if player.draw_speed_timer > 0.0 else ""
	if skill_points_label != null:
		skill_points_label.text = "技能点: %d" % player.skill_points
		skill_speed_label.text = "Q 三连发 Lv%d:连射 %d 支箭" % [player.skill_levels.triple, player.skill_levels.triple + 2]
		skill_regen_label.text = "E 拉弓加速 Lv%d:3s 内攻击频率提升" % player.skill_levels.draw


func _refresh_inventory() -> void:
	if player == null:
		return
	var parts: Array[String] = []
	for i in player.QUICKBAR_SIZE:
		var item: ItemData = player.quickbar[i]
		parts.append("[%d]%s" % [i + 1, "空" if item == null else item.item_name])
	quick_label.text = "快捷栏: " + "  ".join(parts)
	var weapon_name: String = "无" if player.equipment.weapon == null else player.equipment.weapon.item_name
	var armor_name: String = "无" if player.equipment.armor == null else player.equipment.armor.item_name
	equip_label.text = "武器: %s | 防具: %s" % [weapon_name, armor_name]
	if inv_quick_label != null:
		inv_quick_label.text = "快捷栏(掉落物): " + "  ".join(parts)
		inv_weapon_label.text = "武器: %s(%s)" % [weapon_name, _weapon_desc()]
		inv_armor_label.text = "防具: %s(%s)" % [armor_name, _armor_desc()]


func _weapon_desc() -> String:
	if player.equipment.weapon == null:
		return "无"
	var weapon: ItemData = player.equipment.weapon
	var text := "攻击 +%d" % int(weapon.damage)
	if weapon.arrow_speed_mult > 1.0:
		text += " · 箭速 x%.1f" % weapon.arrow_speed_mult
	return text


func _armor_desc() -> String:
	if player.equipment.armor == null:
		return "无"
	var armor: ItemData = player.equipment.armor
	var text := "防御 +%d" % int(armor.defense)
	if armor.max_hp_bonus > 0.0:
		text += " · 生命 +%d" % int(armor.max_hp_bonus)
	return text


func _on_upgrade_triple() -> void:
	player.upgrade_skill("triple")


func _on_upgrade_draw() -> void:
	player.upgrade_skill("draw")


func _on_spawn_toggle_pressed() -> void:
	if spawner == null:
		return
	spawner.set_spawning(not spawner.enabled)
	refresh_debug()


func _on_equip_bow(item: ItemData) -> void:
	if player == null:
		return
	player.equip_item("weapon", item)
	_refresh_inventory()
	player.notify.emit("装备了 %s: %s" % [item.item_name, _weapon_desc()])


func _on_cheat_toggle_pressed() -> void:
	if player == null:
		return
	player.set_debug_cheats(not player.debug_no_cd)
	refresh_debug()
	_refresh_stats()


func _on_save_pressed() -> void:
	if main_ref != null:
		main_ref.save_now()


## ---- 主题控件工厂 ----
func _make_panel(parent: Control, pos: Vector2, size: Vector2, title: String) -> Control:
	var panel := Control.new()
	panel.position = pos
	panel.size = size
	parent.add_child(panel)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _box_style(C_PANEL))
	panel.add_child(bg)
	if title != "":
		var title_label := _make_label(panel, title, Vector2(12, 6), 16)
		title_label.add_theme_color_override("font_color", C_TITLE)
		var line := ColorRect.new()
		line.position = Vector2(10, 26)
		line.size = Vector2(size.x - 20, 1)
		line.color = C_GOLD_DIM
		panel.add_child(line)
		var gem := ColorRect.new()
		gem.position = Vector2(10, 21)
		gem.size = Vector2(5, 5)
		gem.rotation = PI * 0.25
		gem.color = C_GOLD
		panel.add_child(gem)
	return panel


func _make_button(parent: Control, text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_stylebox_override("normal", _box_style(Color(0.11, 0.09, 0.11, 0.96)))
	btn.add_theme_stylebox_override("hover", _box_style(Color(0.2, 0.16, 0.12, 1.0)))
	btn.add_theme_stylebox_override("pressed", _box_style(Color(0.26, 0.2, 0.12, 1.0)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_TITLE)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _make_label(parent: Control, text: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


func _make_bar(parent: Control, pos: Vector2, color: Color) -> ColorRect:
	var bg := Panel.new()
	bg.position = pos
	bg.size = Vector2(BAR_WIDTH, 16)
	bg.add_theme_stylebox_override("panel", _box_style(Color(0.1, 0.08, 0.1, 0.95)))
	parent.add_child(bg)
	var fill := ColorRect.new()
	fill.position = Vector2(1, 1)
	fill.size = Vector2(BAR_WIDTH - 2.0, 14)
	fill.color = color
	bg.add_child(fill)
	var shine := ColorRect.new()
	shine.position = Vector2(1, 1)
	shine.size = Vector2(BAR_WIDTH - 2.0, 3)
	shine.color = Color(1, 1, 1, 0.13)
	bg.add_child(shine)
	return fill


func _box_style(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb
