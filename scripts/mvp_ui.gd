extends CanvasLayer
## Deliberately quiet interface: bone, brass and ink. No developer HUD.
const PANEL_TEXTURE = preload("res://assets/sprites/wall.png")
const INK := Color("110f12")
const PAPER := Color("ddd8c9")
const MUTED := Color("aaa095")
const GOLD := Color("d6ad68")
const LINE := Color("68523b")
var game: Node2D
var root: Control
var hud: Control
var modal: Control
var hp_fill: ColorRect
var mp_fill: ColorRect
var hp_text: Label
var mp_text: Label
var objective: Label
var score_text: Label
var potion_text: Label
var boss_panel: Control
var boss_fill: ColorRect
var toast: Label
var toast_time := 0.0
var selected := 0
var serif: SystemFont
var sans: SystemFont
var skill_labels: Array[Label] = []

const TitleDrawing = preload("res://scripts/mvp_title_art.gd")

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	serif = SystemFont.new()
	serif.font_names = PackedStringArray(["Georgia", "Times New Roman"])
	sans = SystemFont.new()
	sans.font_names = PackedStringArray(["Microsoft YaHei", "Noto Sans CJK SC", "sans-serif"])
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var theme := Theme.new()
	theme.default_font = sans
	root.theme = theme
	add_child(root)
	hud = Control.new()
	hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(hud)
	_build_hud()
	modal = Control.new()
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(modal)
	toast = _label(hud, "", Vector2(280, 563), 16, GOLD, Vector2(720, 28))
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.add_theme_constant_override("outline_size", 4)
	toast.add_theme_color_override("font_outline_color", INK)

func _panel(parent: Node, pos: Vector2, dimensions: Vector2, color: Color = Color("211a1b")) -> Panel:
	var panel := Panel.new()
	panel.position = pos
	panel.size = dimensions
	var box := StyleBoxTexture.new()
	box.texture = PANEL_TEXTURE
	box.modulate_color = color.lightened(0.19)
	box.set_texture_margin_all(4)
	box.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	box.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
	panel.add_theme_stylebox_override("panel", box)
	parent.add_child(panel)
	return panel

func _label(parent: Node, text: String, pos: Vector2, font_size: int = 16, color: Color = PAPER, dimensions: Vector2 = Vector2(600, 32)) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.size = dimensions
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	parent.add_child(label)
	return label

func _rule(parent: Node, pos: Vector2, width: float, color: Color = LINE) -> void:
	var rule := ColorRect.new()
	rule.position = pos
	rule.size = Vector2(width, 1)
	rule.color = color
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rule)

func _button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, callback: Callable, primary: bool = false) -> Button:
	var button := Button.new()
	button.text = text
	button.position = pos
	button.size = dimensions
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", Color("fff0d2") if primary else PAPER)
	button.add_theme_color_override("font_hover_color", Color("fff0d2"))
	for state in ["normal", "hover", "pressed", "focus"]:
		var style := StyleBoxTexture.new()
		style.texture = PANEL_TEXTURE
		style.set_texture_margin_all(3)
		style.axis_stretch_horizontal = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE
		style.modulate_color = (Color("ffe1a0") if primary else Color("a98a68")) if state in ["hover", "pressed", "focus"] else (Color("d9b779") if primary else Color("64513f"))
		button.add_theme_stylebox_override(state, style)
	button.pressed.connect(callback)
	parent.add_child(button)
	return button

func _clear_modal(dim: bool = true) -> void:
	for child in modal.get_children():
		modal.remove_child(child)
		child.queue_free()
	modal.visible = true
	modal.mouse_filter = Control.MOUSE_FILTER_STOP
	if dim:
		var veil := ColorRect.new()
		veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		veil.color = Color(0.025, 0.04, 0.06, 0.87)
		modal.add_child(veil)

func show_title() -> void:
	_clear_modal(false)
	hud.visible = false
	var art := TitleDrawing.new()
	art.size = Vector2(1280, 720)
	art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	modal.add_child(art)
	_label(modal, "S W O R D S   ·   S O R C E R Y   ·   T H E   A B Y S S", Vector2(78, 97), 12, GOLD)
	_rule(modal, Vector2(80, 143), 80, GOLD)
	var first := _label(modal, "DEEPER", Vector2(74, 181), 83, PAPER)
	first.add_theme_font_override("font", serif)
	var second := _label(modal, "& DEEPER", Vector2(77, 270), 70, PAPER)
	second.add_theme_font_override("font", serif)
	_label(modal, "龙眠之下 · 深渊远征", Vector2(83, 377), 24, GOLD)
	_label(modal, "王国已成灰烬。地底的古老誓约，仍在等待回应。", Vector2(83, 424), 15, MUTED)
	_button(modal, "踏入地城    →", Vector2(83, 493), Vector2(256, 52), func(): game.call_deferred("start_run"), true)
	_button(modal, "冒险者指南", Vector2(355, 493), Vector2(196, 52), show_help)
	_button(modal, "军械库  /  试穿与比较装备", Vector2(83, 561), Vector2(468, 36), func(): game.call_deferred("start_equipment_review"))
	_rule(modal, Vector2(83, 624), 468)
	_label(modal, "两层禁地    /    遗失圣物    /    地宫守望者", Vector2(83, 640), 13, MUTED)
	_label(modal, "THE ASHEN KINGDOM     ·     ART PLAYTEST 0.2", Vector2(83, 671), 10, GOLD)
	_label(modal, "BENEATH THE KINGDOM, SOMETHING WAKES", Vector2(682, 661), 11, GOLD, Vector2(560, 26)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _build_hud() -> void:
	var brand := _label(hud, "deeper and deeper", Vector2(32, 22), 23)
	brand.add_theme_font_override("font", serif)
	_label(hud, "[ I ] 装备     [ ESC ] 暂停", Vector2(997, 25), 12, MUTED, Vector2(260, 25))
	_rule(hud, Vector2(32, 63), 1216, Color("42474c"))
	objective = _label(hud, "", Vector2(34, 76), 14, GOLD)
	score_text = _label(hud, "", Vector2(1040, 76), 13, PAPER, Vector2(206, 25))
	score_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var status := _panel(hud, Vector2(32, 599), Vector2(276, 89), Color(0.045, 0.065, 0.09, 0.94))
	_label(status, "THE WAYFARER / 游侠", Vector2(14, 9), 11, MUTED)
	var hp_bg := ColorRect.new()
	hp_bg.position = Vector2(14, 38)
	hp_bg.size = Vector2(248, 12)
	hp_bg.color = Color("362327")
	status.add_child(hp_bg)
	hp_fill = ColorRect.new()
	hp_fill.size = Vector2(248, 12)
	hp_fill.color = Color("b96358")
	hp_bg.add_child(hp_fill)
	hp_text = _label(status, "", Vector2(14, 24), 10, PAPER, Vector2(248, 16))
	hp_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	var mp_bg := ColorRect.new()
	mp_bg.position = Vector2(14, 65)
	mp_bg.size = Vector2(248, 5)
	mp_bg.color = Color("24333e")
	status.add_child(mp_bg)
	mp_fill = ColorRect.new()
	mp_fill.size = Vector2(248, 5)
	mp_fill.color = Color("77a1aa")
	mp_bg.add_child(mp_fill)
	mp_text = _label(status, "", Vector2(14, 72), 9, MUTED)
	var commands := [["Q", "连射"], ["E", "疾射"], ["SHIFT", "翻滚"]]
	for i in commands.size():
		var card := _panel(hud, Vector2(458 + i * 94, 618), Vector2(82, 69), Color("141d27"))
		_label(card, commands[i][0], Vector2(0, 6), 13, GOLD, Vector2(82, 22)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		var label := _label(card, commands[i][1], Vector2(0, 35), 12, MUTED, Vector2(82, 22))
		label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		skill_labels.append(label)
	potion_text = _label(hud, "", Vector2(874, 624), 13, PAPER, Vector2(374, 54))
	potion_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_label(hud, "WASD 移动   ·   鼠标瞄准 / 左键射击   ·   F 交互", Vector2(390, 694), 11, MUTED, Vector2(600, 20)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_panel = _panel(hud, Vector2(423, 112), Vector2(434, 51), Color("141b23"))
	_label(boss_panel, "井 底 守 望 者", Vector2(0, 5), 13, PAPER, Vector2(434, 22)).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	boss_fill = ColorRect.new()
	boss_fill.position = Vector2(12, 34)
	boss_fill.size = Vector2(410, 5)
	boss_fill.color = Color("b96154")
	boss_panel.add_child(boss_fill)
	boss_panel.hide()

func show_game() -> void:
	modal.hide()
	hud.show()
	get_tree().paused = false

func notify(text: String) -> void:
	toast.text = text
	toast_time = 4.5
	toast.modulate.a = 1.0

func _process(delta: float) -> void:
	if not is_instance_valid(game.player):
		return
	var p: Player = game.player
	hp_fill.size.x = 248 * clampf(p.hp / p.max_hp, 0, 1)
	mp_fill.size.x = 248 * clampf(p.mp / p.max_mp, 0, 1)
	hp_text.text = "%d / %d" % [ceili(p.hp), int(p.max_hp)]
	mp_text.text = "法力  %d / %d" % [int(p.mp), int(p.max_mp)]
	objective.text = ("I  /  封土回廊    ·    " + ("升降梯已唤醒，前往东侧出口" if game.gate_open else "击败东侧房间的守门者")) if game.depth == 1 else "II  /  无灯圣所    ·    找到并击败井底守望者"
	score_text.text = "战利品 %03d   /   %02d:%02d" % [game.score, int(game.elapsed) / 60, int(game.elapsed) % 60]
	var potions: Array[String] = []
	for i in 3:
		var item: ItemData = p.quickbar[i]
		potions.append("[%d] %s" % [i + 1, "—" if item == null else ("红药" if item.potion_type == ItemData.PotionType.RED else "蓝药")])
	potion_text.text = "    ".join(potions) + "\n背包补给可按 I 使用 / 补入快捷栏"
	skill_labels[0].text = "%.1fs" % p.skill_cd if p.skill_cd > 0 else "连射"
	skill_labels[1].text = "疾射中" if p.draw_speed_timer > 0 else "疾射"
	skill_labels[2].text = "%.1fs" % p.dodge_cd if p.dodge_cd > 0 else "翻滚"
	boss_panel.visible = game.boss_seen and is_instance_valid(game.boss) and not game.boss.dead
	if boss_panel.visible:
		boss_fill.size.x = 410 * clampf(game.boss.hp / game.boss.max_hp, 0, 1)
	toast_time = maxf(0, toast_time - delta)
	toast.modulate.a = minf(1, toast_time)

func show_gate() -> void:
	game.run_state = "gate"
	get_tree().paused = true
	_clear_modal()
	var panel := _panel(modal, Vector2(326, 166), Vector2(628, 390))
	_label(panel, "T H E   N E X T   D E S C E N T", Vector2(40, 29), 12, GOLD)
	_label(panel, "下面，还有什么？", Vector2(40, 72), 32)
	_label(panel, "你已唤醒升降梯。带走收获，或者继续。", Vector2(40, 132), 16, MUTED)
	_rule(panel, Vector2(40, 182), 548)
	_label(panel, "现在撤离", Vector2(40, 200), 16, PAPER)
	_label(panel, "记录 %d 分。安全结束本次冒险。" % game.score, Vector2(40, 230), 14, MUTED)
	_label(panel, "继续下潜 · 第二层", Vector2(40, 267), 16, GOLD)
	_label(panel, "更高蓝装概率 / 终战双倍计分 / 死亡失去本局收益", Vector2(40, 298), 13, MUTED)
	_button(panel, "带着收获离开", Vector2(40, 335), Vector2(252, 40), func(): game.call_deferred("finish", "extract"))
	_button(panel, "继续下潜    ↓", Vector2(308, 335), Vector2(280, 40), func(): game.call_deferred("descend"), true)

func show_result(outcome: String, banked: int) -> void:
	get_tree().paused = true
	_clear_modal()
	var panel := _panel(modal, Vector2(330, 133), Vector2(620, 452))
	var title := "你抵达了井底。" if outcome == "victory" else ("火光，留在了身后。" if outcome == "death" else "带着余火归来。")
	_label(panel, "A D V E N T U R E   /   C O M P L E T E", Vector2(42, 30), 12, GOLD)
	_label(panel, title, Vector2(42, 77), 32)
	_label(panel, "死亡结束了本次冒险，但深处仍在等待。" if outcome == "death" else "这次冒险的收获，已经属于你。", Vector2(42, 131), 15, MUTED)
	_rule(panel, Vector2(42, 183), 536)
	_label(panel, "%03d" % banked, Vector2(42, 202), 59, GOLD)
	_label(panel, "本局有效战利品", Vector2(45, 273), 13, MUTED)
	_label(panel, "深度  %s\n击败  %d 个敌人\n用时  %02d:%02d\n本次启动最佳  %d" % ["II" if game.depth == 2 else "I", game.kills, int(game.elapsed) / 60, int(game.elapsed) % 60, game.best_score], Vector2(340, 207), 15, PAPER, Vector2(240, 122))
	_rule(panel, Vector2(42, 340), 536)
	_button(panel, "再下一次    ↓", Vector2(42, 371), Vector2(256, 46), func(): game.call_deferred("start_run"), true)
	_button(panel, "返回标题", Vector2(314, 371), Vector2(264, 46), return_title)

func show_inventory() -> void:
	game.run_state = "inventory"
	get_tree().paused = true
	_clear_modal()
	var panel := _panel(modal, Vector2(90, 74), Vector2(1100, 572))
	_label(panel, "THE WAYFARER'S KIT", Vector2(30, 21), 12, GOLD)
	_label(panel, "行囊与装备", Vector2(30, 49), 28)
	_label(panel, "选择物品比较，再决定是否替换。", Vector2(30, 95), 14, MUTED)
	_button(panel, "关闭 [I / ESC]", Vector2(912, 26), Vector2(158, 38), close_modal)
	_rule(panel, Vector2(30, 132), 1040)
	var p: Player = game.player
	_label(panel, "手持 / " + p.equipment.weapon.item_name, Vector2(30, 151), 15, PAPER)
	_label(panel, "护甲 / " + p.equipment.armor.item_name, Vector2(334, 151), 15, PAPER)
	_label(panel, "攻击 %d  ·  射击间隔 %.2fs  ·  移速 %d" % [int(p.base_attack_damage + p.equipment.weapon.damage), p.attack_interval * p.gear_attack_speed_mod, int(p._current_speed())], Vector2(30, 188), 13, MUTED)
	_rule(panel, Vector2(30, 222), 620)
	_label(panel, "背包  %02d / 20" % p.backpack.size(), Vector2(30, 236), 12, GOLD)
	selected = clampi(selected, 0, maxi(0, p.backpack.size() - 1))
	for i in mini(p.backpack.size(), 20):
		var item: ItemData = p.backpack[i]
		var x := 30 + (i % 4) * 157
		var y := 269 + (i / 4) * 45
		var button := _button(panel, item.item_name, Vector2(x, y), Vector2(149, 38), _select_item.bind(i), i == selected)
		button.add_theme_font_size_override("font_size", 12)
	if p.backpack.is_empty():
		_label(panel, "行囊尚空。\n靠近琥珀色补给匣，按 F 搜寻。", Vector2(46, 300), 17, MUTED, Vector2(570, 90))
	var side := _panel(panel, Vector2(685, 154), Vector2(385, 374), Color("111922"))
	if not p.backpack.is_empty():
		var item: ItemData = p.backpack[selected]
		var grade_names := ["普通", "精良", "稀有", "史诗", "传说"]
		_label(side, grade_names[item.item_grade] + "  /  " + ("补给" if item.item_type == ItemData.ItemType.POTION else ("武器" if item.item_type == ItemData.ItemType.WEAPON else "护甲")), Vector2(23, 21), 12, GOLD)
		_label(side, item.item_name, Vector2(23, 54), 24, PAPER, Vector2(345, 40))
		var desc := _label(side, item.description, Vector2(23, 110), 14, MUTED, Vector2(335, 105))
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		var comparison := "药剂会优先补入空快捷栏；栏位满时直接使用。"
		if item.item_type != ItemData.ItemType.POTION:
			var slot := "weapon" if item.item_type == ItemData.ItemType.WEAPON else "armor"
			var old: ItemData = p.equipment[slot]
			comparison = "替换：%s\n" % old.item_name
			if slot == "weapon":
				comparison += "攻击 %+d   /   间隔 %+.0f%%" % [int(item.damage - old.damage), (item.attack_speed_mod - old.attack_speed_mod) * 100]
			else:
				comparison += "生命 %+.0f   /   护甲 %+.0f\n移速变化 %+.0f" % [item.max_hp_bonus - old.max_hp_bonus, item.defense - old.defense, item.move_speed_bonus + p.base_speed * item.move_speed_penalty - old.move_speed_bonus - p.base_speed * old.move_speed_penalty]
		_label(side, comparison, Vector2(23, 225), 13, PAPER, Vector2(340, 70))
		_button(side, "使用 / 补入快捷栏" if item.item_type == ItemData.ItemType.POTION else "装备此物", Vector2(23, 313), Vector2(339, 40), func(): game.equip(selected), true)
	_label(panel, "装备替换不会自动恢复生命。背包满时，掉落仍留在地面。", Vector2(30, 535), 12, MUTED)

func _select_item(index: int) -> void:
	selected = index
	show_inventory()

func show_pause() -> void:
	game.run_state = "pause"
	get_tree().paused = true
	_clear_modal()
	var panel := _panel(modal, Vector2(422, 200), Vector2(436, 312))
	_label(panel, "留住这一点火。", Vector2(35, 35), 29)
	_label(panel, "冒险已暂停", Vector2(35, 86), 14, MUTED)
	_button(panel, "继续冒险", Vector2(35, 134), Vector2(366, 44), close_modal, true)
	_button(panel, "操作说明", Vector2(35, 192), Vector2(175, 42), show_help)
	_button(panel, "返回标题", Vector2(226, 192), Vector2(175, 42), return_title)
	_label(panel, "本测试版不保存中途进度。", Vector2(35, 262), 12, MUTED)

func show_help() -> void:
	var from_title: bool = game.run_state == "title"
	if not from_title:
		game.run_state = "pause"
	get_tree().paused = true
	_clear_modal()
	var panel := _panel(modal, Vector2(302, 133), Vector2(676, 454))
	_label(panel, "先看清，再向下。", Vector2(36, 31), 30)
	_label(panel, "WASD 移动       鼠标瞄准 / 左键射击       右键格挡\n\nSHIFT 翻滚       Q 连射       E 疾射\n\nF 搜寻宝箱 / 使用升降梯       I 装备与补给\n\n1 / 2 / 3 使用对应快捷药剂       ESC 暂停", Vector2(36, 105), 16, PAPER, Vector2(610, 202))
	_label(panel, "红色蓄力轮廓是攻击预警。翻滚离开危险区域。\n第一层可撤离；第二层击败Boss通关。死亡失去本局收益。", Vector2(36, 310), 14, MUTED, Vector2(610, 66))
	_button(panel, "明白了", Vector2(36, 388), Vector2(604, 42), show_title if from_title else close_modal, true)

func close_modal() -> void:
	if game.run_state not in ["inventory", "pause", "gate"]:
		return
	game.run_state = "playing"
	show_game()

func return_title() -> void:
	game.run_state = "title"
	# Keep the existing world frozen behind the title; new run resets everything.
	get_tree().paused = true
	show_title()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and game.run_state in ["inventory", "pause", "gate"]:
		close_modal()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("inventory") and game.run_state == "inventory":
		close_modal()
		get_viewport().set_input_as_handled()
