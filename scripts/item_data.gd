class_name ItemData
extends Resource
## 物品/装备数据定义(数据驱动,存档用 item_id)。
## 命名体系依据 docs/游戏设定与命名库.md;数值按品级(白绿蓝紫橙)梯度设计。

enum ItemType { POTION, WEAPON, ARMOR, RING }
enum PotionType { RED, BLUE }
enum ItemGrade { WHITE, GREEN, BLUE, PURPLE, ORANGE }

@export var item_type: ItemType = ItemType.POTION
@export var item_id: String = ""          ## 稳定标识(存档键,勿改名)
@export var item_name: String = "物品"
@export var description: String = ""
@export var item_grade: ItemGrade = ItemGrade.WHITE

## ---- 通用战斗属性 ----
@export var damage: float = 0.0           ## 武器攻击力
@export var defense: float = 0.0          ## 防具防御值(直接减伤量)
@export var block_reduction: float = 0.0  ## 盾牌格挡减伤比例(叠加)
@export var max_hp_bonus: float = 0.0     ## 最大生命加成
@export var max_mp_bonus: float = 0.0     ## 最大蓝量加成
@export var move_speed_bonus: float = 0.0 ## 移速加成(叠加)
@export var move_speed_penalty: float = 0.0 ## 移速惩罚(叠加,负值减移速)
@export var attack_speed_mod: float = 1.0 ## 攻速倍率(<1=更快,乘法叠加)
@export var crit_chance: float = 0.0       ## 暴击率(叠加)
@export var crit_damage_bonus: float = 0.0 ## 额外暴击倍率(基础1.5+此值)
@export var lifesteal: float = 0.0         ## 吸血比例
@export var fire_resist: float = 0.0       ## 火焰抗性(减伤比例)
@export var xp_bonus: float = 0.0          ## 经验加成比例

## ---- 药剂 ----
@export var potion_type: PotionType = PotionType.RED
## ---- 武器 ----
@export var pierce_count: int = 0
@export var arrow_speed_mult: float = 1.0 ## 弓弩:箭速倍率


# ==============================================
# 药剂(消耗品)
# ==============================================
static func red_potion() -> ItemData:
	var item := ItemData.new()
	item.item_id = "red_potion"
	item.item_type = ItemType.POTION
	item.item_name = "红药水"
	item.description = "回复35%最大生命"
	item.potion_type = PotionType.RED
	return item

static func blue_potion() -> ItemData:
	var item := ItemData.new()
	item.item_id = "blue_potion"
	item.item_type = ItemType.POTION
	item.item_name = "蓝药水"
	item.description = "回复40%最大法力"
	item.potion_type = PotionType.BLUE
	return item


# ==============================================
# 武器·弓(游侠)
# ==============================================
static func survival_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "survival_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "岔枝短弓"
	item.description = "可靠的起步武器。攻击 +5"
	item.item_grade = ItemGrade.WHITE
	item.damage = 5.0
	return item

static func recurve_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "recurve_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "斥候反曲弓"
	item.description = "快速出箭。攻击 +6，射击间隔 -20%"
	item.item_grade = ItemGrade.GREEN
	item.damage = 6.0
	item.attack_speed_mod = 0.8
	return item

static func piercing_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "piercing_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "穿骨长弓"
	item.description = "让敌人排成一线。攻击 +9，穿透1个敌人，射击间隔 +20%"
	item.item_grade = ItemGrade.BLUE
	item.damage = 9.0
	item.attack_speed_mod = 1.2
	item.pierce_count = 1
	return item

static func longbow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "longbow"
	item.item_type = ItemType.WEAPON
	item.item_name = "逐日长弓"
	item.description = "稀有长弓,精准致命。攻击力 +14,暴击率 +10%"
	item.item_grade = ItemGrade.BLUE
	item.damage = 14.0
	item.crit_chance = 0.10
	return item

static func elven_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "elven_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "月辉圣弓"
	item.description = "史诗精灵之弓,箭速如电。攻击力 +20,暴击率 +10%,箭速 1.3x"
	item.item_grade = ItemGrade.PURPLE
	item.damage = 20.0
	item.crit_chance = 0.10
	item.arrow_speed_mult = 1.3
	return item

static func dragon_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "dragon_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "龙鸣·渊光之弓"
	item.description = "传说之弓,龙吟裂空。攻击力 +30,暴击率 +15%,暴击倍率 +0.5,箭速 1.3x"
	item.item_grade = ItemGrade.ORANGE
	item.damage = 30.0
	item.crit_chance = 0.15
	item.crit_damage_bonus = 0.5
	item.arrow_speed_mult = 1.3
	return item


# ==============================================
# 武器·剑(铁卫——建模预留,当前游侠不可装备)
# ==============================================
static func iron_sword() -> ItemData:
	var item := ItemData.new()
	item.item_id = "iron_sword"
	item.item_type = ItemType.WEAPON
	item.item_name = "铁卫战剑"
	item.description = "基础战剑,坚实可靠。攻击力 +6"
	item.item_grade = ItemGrade.WHITE
	item.damage = 6.0
	return item

static func oath_sword() -> ItemData:
	var item := ItemData.new()
	item.item_id = "oath_sword"
	item.item_type = ItemType.WEAPON
	item.item_name = "守誓者之剑"
	item.description = "精良战剑,攻守兼备。攻击力 +10,防御 +2"
	item.item_grade = ItemGrade.GREEN
	item.damage = 10.0
	item.defense = 2.0
	return item


# ==============================================
# 防具(所有职业通用)
# ==============================================
static func cloth_armor() -> ItemData:
	var item := ItemData.new()
	item.item_id = "cloth_armor"
	item.item_type = ItemType.ARMOR
	item.item_name = "旧巡林衣"
	item.description = "基础防护。护甲 +1，生命上限 +10"
	item.item_grade = ItemGrade.WHITE
	item.defense = 1.0
	item.max_hp_bonus = 10.0
	return item

static func ranger_leather() -> ItemData:
	var item := ItemData.new()
	item.item_id = "ranger_leather"
	item.item_type = ItemType.ARMOR
	item.item_name = "猎人皮甲"
	item.description = "轻装走位。护甲 +1，生命上限 +15，移速 +5%"
	item.item_grade = ItemGrade.GREEN
	item.defense = 1.0
	item.max_hp_bonus = 15.0
	item.move_speed_bonus = 13.0
	return item

static func chainmail() -> ItemData:
	var item := ItemData.new()
	item.item_id = "chainmail"
	item.item_type = ItemType.ARMOR
	item.item_name = "锁子甲"
	item.description = "精良链甲,轻便灵活。防御 +3,最大生命 +25"
	item.item_grade = ItemGrade.GREEN
	item.defense = 3.0
	item.max_hp_bonus = 25.0
	return item

static func iron_plate() -> ItemData:
	var item := ItemData.new()
	item.item_id = "iron_plate"
	item.item_type = ItemType.ARMOR
	item.item_name = "守门锁甲"
	item.description = "以机动换容错。护甲 +3，生命上限 +30，移速 -8%"
	item.item_grade = ItemGrade.BLUE
	item.defense = 3.0
	item.max_hp_bonus = 30.0
	item.move_speed_penalty = -0.08
	return item

static func dragonscale() -> ItemData:
	var item := ItemData.new()
	item.item_id = "dragonscale"
	item.item_type = ItemType.ARMOR
	item.item_name = "龙鳞胸甲"
	item.description = "史诗龙鳞甲,炽焰难侵。防御 +8,最大生命 +70,火抗 +20%"
	item.item_grade = ItemGrade.PURPLE
	item.defense = 8.0
	item.max_hp_bonus = 70.0
	item.fire_resist = 0.20
	return item


# ==============================================
# 盾牌(防具)
# ==============================================
static func wooden_shield() -> ItemData:
	var item := ItemData.new()
	item.item_id = "wooden_shield"
	item.item_type = ItemType.ARMOR
	item.item_name = "木盾"
	item.description = "简易木盾。格挡减伤 30%,最大生命 +10"
	item.item_grade = ItemGrade.WHITE
	item.defense = 1.0
	item.block_reduction = 0.30
	item.max_hp_bonus = 10.0
	return item

static func iron_shield() -> ItemData:
	var item := ItemData.new()
	item.item_id = "iron_shield"
	item.item_type = ItemType.ARMOR
	item.item_name = "铁壁圆盾"
	item.description = "精良铁盾,坚实可靠。格挡减伤 40%,防御 +2,最大生命 +20"
	item.item_grade = ItemGrade.GREEN
	item.defense = 2.0
	item.block_reduction = 0.40
	item.max_hp_bonus = 20.0
	return item


# ==============================================
# 饰品·戒指/护符
# ==============================================
static func lucky_ring() -> ItemData:
	var item := ItemData.new()
	item.item_id = "lucky_ring"
	item.item_type = ItemType.RING
	item.item_name = "幸运铜戒"
	item.description = "普通铜戒,带来好运。经验获取 +10%"
	item.item_grade = ItemGrade.WHITE
	item.xp_bonus = 0.10
	return item

static func wind_ring() -> ItemData:
	var item := ItemData.new()
	item.item_id = "wind_ring"
	item.item_type = ItemType.RING
	item.item_name = "疾风之戒"
	item.description = "精良戒指,步履如风。移速 +30"
	item.item_grade = ItemGrade.GREEN
	item.move_speed_bonus = 30.0
	return item

static func guard_amulet() -> ItemData:
	var item := ItemData.new()
	item.item_id = "guard_amulet"
	item.item_type = ItemType.RING
	item.item_name = "守护石坠"
	item.description = "精良护符,坚固守护。防御 +2"
	item.item_grade = ItemGrade.GREEN
	item.defense = 2.0
	return item

static func blood_amulet() -> ItemData:
	var item := ItemData.new()
	item.item_id = "blood_amulet"
	item.item_type = ItemType.RING
	item.item_name = "血月护符"
	item.description = "稀有护符,饮血续命。攻击吸血 +3%"
	item.item_grade = ItemGrade.BLUE
	item.lifesteal = 0.03
	return item

static func sage_eye() -> ItemData:
	var item := ItemData.new()
	item.item_id = "sage_eye"
	item.item_type = ItemType.RING
	item.item_name = "贤者之眼"
	item.description = "史诗饰品,洞悉弱点。暴击倍率 +0.5"
	item.item_grade = ItemGrade.PURPLE
	item.crit_damage_bonus = 0.5
	return item


# ==============================================
# 存档还原:按 item_id 查找工厂(存档用稳定键,勿改名)
# ==============================================
static func from_name(name: String) -> ItemData:
	match name:
		"red_potion":   return red_potion()
		"blue_potion":  return blue_potion()
		"iron_sword":   return iron_sword()
		"oath_sword":   return oath_sword()
		"wooden_shield":return wooden_shield()
		"iron_shield":  return iron_shield()
		"survival_bow": return survival_bow()
		"recurve_bow":  return recurve_bow()
		"piercing_bow": return piercing_bow()
		"ranger_leather": return ranger_leather()
		"longbow":      return longbow()
		"elven_bow":    return elven_bow()
		"dragon_bow":   return dragon_bow()
		"cloth_armor":  return cloth_armor()
		"chainmail":    return chainmail()
		"iron_plate":   return iron_plate()
		"dragonscale":  return dragonscale()
		"lucky_ring":   return lucky_ring()
		"wind_ring":    return wind_ring()
		"guard_amulet": return guard_amulet()
		"blood_amulet": return blood_amulet()
		"sage_eye":     return sage_eye()
	return null
