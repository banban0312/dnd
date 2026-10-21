extends RefCounted
## Design prototype only. Effects are specifications, not live Player abilities.
## Item IDs and rolled stats must be persisted before integrating into gameplay.

const SLOTS := ["weapon", "armor", "trinket"]
const GRADES := ["white", "green", "blue", "purple", "orange"]

static func items() -> Array[Dictionary]:
	return [
		_entry("dd_scout_bow", "岔枝短弓", "weapon", "white", 1, {"damage": 5.0}, "", "可靠的起步武器"),
		_entry("dd_swift_bow", "斥候反曲弓", "weapon", "green", 1, {"damage": 7.0, "attack_interval_mult": 0.90}, "", "快速射击"),
		_entry("dd_bone_bow", "穿骨长弓", "weapon", "blue", 1, {"damage": 9.0, "attack_interval_mult": 1.15}, "pierce_one", "箭穿透一个敌人，射击间隔增加15%"),
		_entry("dd_watch_bow", "守望者", "weapon", "blue", 2, {"damage": 11.0}, "focus_third", "同目标第三次命中额外增伤40%，换目标重置"),
		_entry("dd_ember_bow", "余烬连弓", "weapon", "purple", 2, {"damage": 12.0}, "skill_haste", "Q结束后2秒内普攻间隔缩短20%，不可刷新自身"),
		_entry("dd_echo_bow", "无底回声", "weapon", "orange", 3, {"damage": 14.0}, "echo_third", "第三次普攻追加一支50%伤害回声箭，回声不触发回声"),
		_entry("dd_linen", "旧巡林衣", "armor", "white", 1, {"defense": 1.0, "max_hp": 10.0}, "", "基础防护"),
		_entry("dd_leather", "猎人皮甲", "armor", "green", 1, {"defense": 2.0, "max_hp": 15.0, "move_speed_pct": 0.04}, "", "轻便防护"),
		_entry("dd_iron", "守门锁甲", "armor", "blue", 1, {"defense": 4.0, "max_hp": 25.0, "move_speed_pct": -0.08}, "", "用走位能力换容错"),
		_entry("dd_shadow", "影步披风", "armor", "blue", 2, {"defense": 2.0, "max_hp": 15.0}, "dodge_next", "翻滚结束后2秒内下一次普攻增伤25%，只消费一次"),
		_entry("dd_candle", "守烛法衣", "armor", "purple", 2, {"defense": 3.0, "max_hp": 20.0}, "potion_guard", "喝红药后获得8点护盾，持续4秒，不叠加"),
		_entry("dd_oath", "深井誓约", "armor", "orange", 3, {"defense": 4.0, "max_hp": 30.0}, "last_candle", "本局一次：致命伤保留1生命并无敌1秒；换装不重置"),
		_entry("dd_copper", "铜叶坠", "trinket", "white", 1, {"max_mp": 5.0}, "", "补给型饰品"),
		_entry("dd_wind", "风铃戒", "trinket", "green", 1, {"move_speed_pct": 0.05, "crit_chance": 0.03}, "", "移动与精确射击"),
		_entry("dd_hunt", "猎手印戒", "trinket", "blue", 1, {"crit_chance": 0.06}, "elite_hunter", "对精英和Boss造成额外8%伤害"),
		_entry("dd_still", "静息石", "trinket", "blue", 2, {"max_mp": 8.0}, "kill_mana", "击杀恢复2法力，冷却0.5秒；召唤物不计"),
		_entry("dd_blood", "血烛护符", "trinket", "purple", 2, {"max_hp": -10.0}, "lifesteal", "按实际有效伤害吸血2%，每秒最多回复3生命"),
		_entry("dd_deep", "深处之眼", "trinket", "orange", 3, {"crit_chance": 0.08}, "depth_power", "每下降一层获得5%伤害，第三层最高10%"),
	]

static func _entry(id: String, title: String, slot: String, grade: String,
		min_depth: int, stats: Dictionary, effect: String, description: String) -> Dictionary:
	return {"id": id, "name": title, "slot": slot, "grade": grade,
		"min_depth": min_depth, "stats": stats, "effect_id": effect,
		"description": description, "weight": 1.0}

static func pool(depth: int, grade: String, slot: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for item in items():
		if item.min_depth <= depth and item.grade == grade and (slot.is_empty() or item.slot == slot):
			result.append(item)
	return result

static func find_item(id: String) -> Dictionary:
	for item in items():
		if item.id == id:
			return item
	return {}
