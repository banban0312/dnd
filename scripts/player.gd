extends CharacterBody2D
class_name Player
## 玩家角色:游侠。移动、翻滚闪避、弓箭射击、Q 三连发、E 拉弓加速、快捷栏与装备。

signal stats_changed
signal inventory_changed
signal died
signal notify(text: String)
signal item_dropped(item: ItemData, pos: Vector2)

const BACKPACK_SIZE := 20
const QUICKBAR_SIZE := 3

## 基础数值
@export var base_speed: float = 260.0
@export var max_hp: float = 100.0
@export var max_mp: float = 50.0
@export var base_attack_damage: float = 10.0
@export var attack_interval: float = 0.5
@export var arrow_speed: float = 700.0
@export var dodge_speed: float = 700.0
@export var dodge_duration: float = 0.2
@export var dodge_cooldown: float = 1.0
@export var dodge_iframes: float = 0.4

## 技能常量(可调)
const TRIPLE_MP_COST := 15.0
const TRIPLE_COOLDOWN := 4.0
const TRIPLE_BURST_GAP := 0.12
const DRAW_SPEED_MP_COST := 10.0
const DRAW_SPEED_COOLDOWN := 5.0
const DRAW_SPEED_DURATION := 3.0
const DRAW_SPEED_FACTOR := 0.4
const QUICKBAR_SIZE := 3
const BOB_SPEED := 11.0
const BOB_AMOUNT := 3.0
const RECOIL_TIME := 0.12
const RECOIL_DIST := 5.0
## 视觉基准偏移:让 16x28 的角色脚底对齐 40x40 碰撞盒底部
const VISUAL_OFFSET := Vector2(0, -15)

var hp: float
var mp: float
## 基础最大生命(不含装备加成),升级时累加
var base_max_hp: float = 100.0
## 由装备叠加的战斗属性(每帧 _recalc_stats 重新计算)
var gear_attack_speed_mod: float = 1.0
var gear_move_speed_bonus: float = 0.0
var gear_crit_chance: float = 0.0
var gear_crit_damage: float = 1.5  # 基础暴击倍率 + 装备额外倍率
var gear_lifesteal: float = 0.0
var gear_xp_bonus: float = 0.0
var gear_fire_resist: float = 0.0
var level := 1
var xp := 0
var xp_to_next := 50
var skill_points := 0
var skill_levels: Dictionary[String, int] = {"triple": 1, "draw": 1}
var quickbar: Array[ItemData] = [null, null, null]
var equipment: Dictionary[String, ItemData] = {"weapon": null, "armor": null}
var backpack: Array[ItemData] = []

var attack_cd := 0.0
var burst_remaining := 0
var burst_timer := 0.0
var draw_speed_timer := 0.0
var skill_cd := 0.0
var dodge_timer := 0.0
var dodge_cd := 0.0
var invuln_timer := 0.0
var dodge_dir := Vector2.RIGHT
var facing := Vector2.DOWN
var blocking := false
var dead := false
## 测试工具开关:无限蓝量 / 技能无冷却
var debug_infinite_mp := false
var debug_no_cd := false
var bob_timer := 0.0
var recoil_timer := 0.0
var visual_sprite: AnimatedSprite2D


func _ready() -> void:
	base_max_hp = max_hp
	equipment.weapon = ItemData.survival_bow()
	equipment.armor = ItemData.cloth_armor()
	_recalc_stats()
	hp = max_hp
	mp = max_mp
	add_to_group("player")
	visual_sprite = $Visual as AnimatedSprite2D
	if visual_sprite.sprite_frames == null:
		visual_sprite.sprite_frames = AnimFactory.make_frames("ranger")
	visual_sprite.play("idle")
	_setup_shadow()
	stats_changed.emit()
	inventory_changed.emit()


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	if dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return

	var move_dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	blocking = Input.is_action_pressed("block")

	if dodge_timer > 0.0:
		velocity = dodge_dir * dodge_speed
	else:
		velocity = move_dir * _current_speed()
		if move_dir != Vector2.ZERO:
			facing = move_dir
	_update_facing(move_dir)

	if Input.is_action_pressed("attack"):
		_try_shoot()
	if Input.is_action_just_pressed("skill_1"):
		_try_triple_shot()
	if Input.is_action_just_pressed("skill_2"):
		_try_draw_speed()
	if Input.is_action_just_pressed("dodge"):
		_try_dodge(move_dir)
	for i in QUICKBAR_SIZE:
		if Input.is_action_just_pressed("use_item_%d" % (i + 1)):
			_use_quick_item(i)

	if burst_remaining > 0:
		burst_timer -= delta
		if burst_timer <= 0.0:
			_fire_arrow()
			burst_remaining -= 1
			burst_timer = TRIPLE_BURST_GAP

	move_and_slide()
	_update_visual_effects(delta)


func _tick_timers(delta: float) -> void:
	attack_cd = maxf(0.0, attack_cd - delta)
	if draw_speed_timer > 0.0:
		draw_speed_timer = maxf(0.0, draw_speed_timer - delta)
		if draw_speed_timer == 0.0:
			notify.emit("拉弓加速结束")
			stats_changed.emit()
	skill_cd = maxf(0.0, skill_cd - delta)
	dodge_cd = maxf(0.0, dodge_cd - delta)
	dodge_timer = maxf(0.0, dodge_timer - delta)
	invuln_timer = maxf(0.0, invuln_timer - delta)
	if modulate != Color.WHITE:
		modulate = modulate.lerp(Color.WHITE, 0.25)


func _current_speed() -> float:
	return base_speed + gear_move_speed_bonus


## ---- 射击(左键,弓) ----
func _try_shoot() -> void:
	if dead or (attack_cd > 0.0 and not debug_no_cd):
		return
	if equipment.weapon == null:
		notify.emit("没有装备武器!")
		return
	_fire_arrow()
	attack_cd = _current_attack_interval()
	stats_changed.emit()


## 测试工具:一键切换"无限蓝 + 无 CD"
func set_debug_cheats(enabled: bool) -> void:
	debug_infinite_mp = enabled
	debug_no_cd = enabled
	if enabled:
		mp = max_mp
		skill_cd = 0.0
		attack_cd = 0.0
		dodge_cd = 0.0
	stats_changed.emit()


func _current_attack_interval() -> float:
	var base := attack_interval * gear_attack_speed_mod
	if draw_speed_timer > 0.0:
		var factor: float = maxf(0.25, DRAW_SPEED_FACTOR - 0.05 * float(skill_levels.draw - 1))
		return base * factor
	return base


func _fire_arrow() -> void:
	var aim := get_global_mouse_position() - global_position
	if aim.length() <= 0.01:
		aim = facing
	else:
		facing = aim.normalized()
	recoil_timer = RECOIL_TIME
	Sfx.play(SoundFactory.shoot(), -4.0)
	var arrow := Arrow.new()
	arrow.setup(facing, attack_damage(), arrow_speed * _arrow_speed_mult())
	arrow.global_position = global_position + facing * 34.0
	get_parent().add_child(arrow)


## ---- 动效:行走浮动 / 朝向翻转 / 射箭后坐力 / 闪避翻滚 ----
func _setup_shadow() -> void:
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = preload("res://assets/sprites/shadow.png")
	shadow.position = Vector2(0, 6)
	shadow.z_index = -1
	add_child(shadow)


func _update_facing(move_dir: Vector2) -> void:
	if visual_sprite == null:
		return
	var dir_x := move_dir.x
	if absf(dir_x) < 0.01:
		dir_x = get_global_mouse_position().x - global_position.x
	if absf(dir_x) > 0.05:
		visual_sprite.flip_h = dir_x < 0.0


func _update_visual_effects(delta: float) -> void:
	if visual_sprite == null:
		return
	var moving := velocity.length() > 20.0 and not dead
	var target_anim := "run" if moving else "idle"
	if visual_sprite.animation != target_anim:
		visual_sprite.play(target_anim)
	var bob_y := 0.0
	var bob_rot := 0.0
	if moving:
		bob_timer += delta * BOB_SPEED
		bob_y = sin(bob_timer) * BOB_AMOUNT
		bob_rot = sin(bob_timer * 0.5) * 0.07
	var recoil_offset := Vector2.ZERO
	if recoil_timer > 0.0:
		recoil_timer -= delta
		recoil_offset = -facing * RECOIL_DIST * maxf(recoil_timer / RECOIL_TIME, 0.0)
	visual_sprite.position = visual_sprite.position.lerp(VISUAL_OFFSET + recoil_offset + Vector2(0, bob_y), 0.35)
	if dodge_timer > 0.0:
		visual_sprite.rotation += delta * TAU / dodge_duration
	else:
		visual_sprite.rotation = lerpf(visual_sprite.rotation, bob_rot, 0.2)


func attack_damage() -> float:
	var dmg := base_attack_damage
	if equipment.weapon != null:
		dmg += equipment.weapon.damage
	# 暴击判定:按装备暴击率翻倍
	if gear_crit_chance > 0.0 and randf() < gear_crit_chance:
		dmg *= gear_crit_damage
		notify.emit("暴击! ×%.1f" % gear_crit_damage)
	return dmg


## 武器特殊效果:箭矢飞行速度倍率(精灵弓 1.5x,其余 1.0)
func _arrow_speed_mult() -> float:
	if equipment.weapon != null:
		return equipment.weapon.arrow_speed_mult
	return 1.0


## ---- 装备系统 ----
func equipment_max_hp_bonus() -> float:
	var bonus := 0.0
	for item in equipment.values():
		if item is ItemData:
			bonus += item.max_hp_bonus
	return bonus


## 装备/替换指定栏位(weapon / armor),并重算属性
func equip_item(slot: String, item: ItemData) -> void:
	if not equipment.has(slot):
		return
	equipment[slot] = item
	_recalc_stats()
	inventory_changed.emit()
	stats_changed.emit()


func unequip_item(slot: String) -> void:
	if not equipment.has(slot):
		return
	equipment[slot] = null
	_recalc_stats()
	inventory_changed.emit()
	stats_changed.emit()


func _recalc_stats() -> void:
	max_hp = base_max_hp + equipment_max_hp_bonus()
	hp = minf(hp, max_hp)
	# 装备附加属性(逐件累加)
	var atk_spd := 1.0
	gear_move_speed_bonus = 0.0
	gear_crit_chance = 0.0
	gear_crit_damage = 1.5
	gear_lifesteal = 0.0
	gear_xp_bonus = 0.0
	gear_fire_resist = 0.0
	for item in equipment.values():
		if item == null:
			continue
		atk_spd *= item.attack_speed_mod
		gear_move_speed_bonus += item.move_speed_bonus * (1.0 + item.move_speed_penalty)
		gear_crit_chance += item.crit_chance
		gear_crit_damage += item.crit_damage_bonus
		gear_lifesteal += item.lifesteal
		gear_xp_bonus += item.xp_bonus
		gear_fire_resist += item.fire_resist
	gear_attack_speed_mod = clampf(atk_spd, 0.4, 3.0)
	gear_crit_chance = clampf(gear_crit_chance, 0.0, 0.8)


## ---- Q 技能:三连发 ----
func _try_triple_shot() -> void:
	if dead or (skill_cd > 0.0 and not debug_no_cd):
		if skill_cd > 0.0 and not debug_no_cd:
			notify.emit("技能冷却中(%.1fs)" % skill_cd)
		return
	if not debug_infinite_mp and mp < TRIPLE_MP_COST:
		notify.emit("蓝量不足")
		return
	if not debug_infinite_mp:
		mp -= TRIPLE_MP_COST
	skill_cd = TRIPLE_COOLDOWN
	_fire_arrow()
	burst_remaining = skill_levels.triple + 1
	burst_timer = TRIPLE_BURST_GAP
	notify.emit("三连发!连射 %d 支箭" % (burst_remaining + 1))
	stats_changed.emit()


## ---- E 技能:拉弓加速 ----
func _try_draw_speed() -> void:
	if dead or (skill_cd > 0.0 and not debug_no_cd):
		if skill_cd > 0.0 and not debug_no_cd:
			notify.emit("技能冷却中(%.1fs)" % skill_cd)
		return
	if not debug_infinite_mp and mp < DRAW_SPEED_MP_COST:
		notify.emit("蓝量不足")
		return
	if not debug_infinite_mp:
		mp -= DRAW_SPEED_MP_COST
	skill_cd = DRAW_SPEED_COOLDOWN
	draw_speed_timer = DRAW_SPEED_DURATION
	notify.emit("拉弓加速!3 秒内攻击频率大幅提升")
	stats_changed.emit()


func upgrade_skill(skill_name: String) -> void:
	if skill_points <= 0:
		notify.emit("没有可用技能点")
		return
	if not skill_levels.has(skill_name):
		return
	skill_points -= 1
	skill_levels[skill_name] += 1
	notify.emit("技能 %s 提升至 Lv%d" % [skill_name, skill_levels[skill_name]])
	stats_changed.emit()


## ---- 受击与格挡(右键,通用) ----
func take_damage(amount: float, _source: Node = null) -> void:
	if dead or invuln_timer > 0.0:
		return
	var final_amount := amount
	if blocking:
		var reduction := 0.5
		var armor_def := 0.0
		if equipment.armor != null:
			reduction = maxf(0.5, equipment.armor.block_reduction)
			armor_def = equipment.armor.defense
		final_amount = (amount - armor_def) * (1.0 - reduction)
	final_amount = maxf(0.0, final_amount)
	hp -= final_amount
	modulate = Color(1.0, 0.45, 0.45)
	Sfx.play(SoundFactory.block() if blocking else SoundFactory.hurt(), -4.0)
	DamagePopup.spawn(get_parent(), global_position + Vector2(0, -30),
		str(int(final_amount)), Color(1.0, 0.45, 0.45))
	stats_changed.emit()
	if hp <= 0.0:
		_die()


## ---- 翻滚/闪避 ----
func _try_dodge(move_dir: Vector2) -> void:
	if dodge_cd > 0.0 and not debug_no_cd:
		return
	dodge_dir = move_dir if move_dir != Vector2.ZERO else facing
	dodge_timer = dodge_duration
	dodge_cd = dodge_cooldown
	invuln_timer = dodge_iframes
	Sfx.play(SoundFactory.dodge(), -10.0)
	notify.emit("闪避!(无敌 %.1fs)" % dodge_iframes)


## ---- 背包(通用存储,装备/药水拾取默认进背包) ----
func add_to_backpack(item: ItemData) -> bool:
	if backpack.size() >= BACKPACK_SIZE:
		return false
	backpack.append(item)
	inventory_changed.emit()
	return true


func backpack_at(index: int) -> ItemData:
	if index < 0 or index >= backpack.size():
		return null
	return backpack[index]


func remove_from_backpack(index: int) -> ItemData:
	if index < 0 or index >= backpack.size():
		return null
	var item: ItemData = backpack[index]
	backpack.remove_at(index)
	inventory_changed.emit()
	return item


## 丢弃背包物品(信号上抛,由主场景做掉落)
func drop_backpack_item(index: int) -> bool:
	var item := remove_from_backpack(index)
	if item == null:
		return false
	item_dropped.emit(item, global_position)
	notify.emit("丢弃 %s" % item.item_name)
	return true


## 使用背包物品(药水回血/蓝,消耗品)
func use_backpack_item(index: int) -> bool:
	var item := backpack_at(index)
	if item == null:
		return false
	if item.item_type == ItemData.ItemType.POTION:
		if item.potion_type == ItemData.PotionType.RED:
			hp = max_hp
			notify.emit("使用 %s,生命值恢复至满" % item.item_name)
		else:
			mp = max_mp
			notify.emit("使用 %s,蓝量恢复至满" % item.item_name)
		backpack.remove_at(index)
		Sfx.play(SoundFactory.pickup(), -6.0)
		inventory_changed.emit()
		stats_changed.emit()
		return true
	return false


## ---- 快捷栏(仅掉落消耗品) ----
func add_item_to_quickbar(item: ItemData) -> bool:
	for i in QUICKBAR_SIZE:
		if quickbar[i] == null:
			quickbar[i] = item
			inventory_changed.emit()
			return true
	return false


func _use_quick_item(index: int) -> void:
	var item: ItemData = quickbar[index]
	if item == null:
		return
	if item.item_type == ItemData.ItemType.POTION:
		if item.potion_type == ItemData.PotionType.RED:
			hp = max_hp
			notify.emit("使用红药水,生命值恢复至满")
		elif item.potion_type == ItemData.PotionType.BLUE:
			mp = max_mp
			notify.emit("使用蓝药水,蓝量恢复至满")
	quickbar[index] = null
	Sfx.play(SoundFactory.pickup(), -6.0)
	inventory_changed.emit()
	stats_changed.emit()


## ---- 等级与经验 ----
func add_xp(amount: int) -> void:
	xp += int(amount * (1.0 + gear_xp_bonus))
	var leveled := false
	while xp >= xp_to_next:
		xp -= xp_to_next
		level += 1
		skill_points += 1
		base_max_hp += 10.0
		max_mp += 5.0
		_recalc_stats()
		hp = max_hp
		mp = max_mp
		xp_to_next = 50 + (level - 1) * 30
		leveled = true
	if leveled:
		Sfx.play(SoundFactory.upgrade(), -6.0)
		notify.emit("升级!达到 %d 级,获得 1 个技能点(按 K 分配)" % level)
	stats_changed.emit()


## ---- 死亡与重生 ----
func _die() -> void:
	dead = true
	velocity = Vector2.ZERO
	Sfx.play(SoundFactory.die(), -4.0)
	notify.emit("你倒下了…")
	died.emit()


## ---- 存档:状态导入导出(供 SaveManager) ----
func export_state() -> Dictionary:
	var qb: Array[String] = []
	for i in QUICKBAR_SIZE:
		qb.append(_item_id(quickbar[i]))
	return {
		"level": level,
		"xp": xp,
		"skill_points": skill_points,
		"skill_levels": skill_levels.duplicate(),
		"base_max_hp": base_max_hp,
		"max_mp": max_mp,
		"hp": hp,
		"mp": mp,
		"weapon": _item_id(equipment.weapon),
		"armor": _item_id(equipment.armor),
		"quickbar": qb,
		"backpack": _export_backpack(),
	}


func import_state(data: Dictionary) -> void:
	level = int(data.get("level", 1))
	xp = int(data.get("xp", 0))
	skill_points = int(data.get("skill_points", 0))
	skill_levels = (data.get("skill_levels", {"triple": 1, "draw": 1}) as Dictionary[String, int]).duplicate()
	base_max_hp = float(data.get("base_max_hp", max_hp))
	max_mp = float(data.get("max_mp", 50.0))
	equipment.weapon = ItemData.from_name(str(data.get("weapon", "")))
	equipment.armor = ItemData.from_name(str(data.get("armor", "")))
	_recalc_stats()
	hp = clampf(float(data.get("hp", max_hp)), 0.0, max_hp)
	mp = clampf(float(data.get("mp", max_mp)), 0.0, max_mp)
	var qb: Array = data.get("quickbar", [null, null, null])
	for i in QUICKBAR_SIZE:
		quickbar[i] = ItemData.from_name(str(qb[i])) if i < qb.size() and qb[i] != null else null
	backpack.clear()
	var bk: Array = data.get("backpack", [])
	for id in bk:
		var restored := ItemData.from_name(str(id))
		if restored != null:
			backpack.append(restored)
	stats_changed.emit()
	inventory_changed.emit()


## 物品存档 ID:null → 空串,否则取 item_id
func _item_id(item: ItemData) -> String:
	if item == null:
		return ""
	return item.item_id


func _export_backpack() -> Array[String]:
	var out: Array[String] = []
	for item in backpack:
		out.append(_item_id(item))
	return out


func respawn_at(pos: Vector2) -> void:
	dead = false
	hp = max_hp
	mp = max_mp
	draw_speed_timer = 0.0
	burst_remaining = 0
	invuln_timer = 1.0
	global_position = pos
	stats_changed.emit()
