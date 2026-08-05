class_name ItemData
extends Resource
## 物品数据定义(数据驱动):掉落药水与装备均由此类定义。

enum ItemType { POTION, WEAPON, ARMOR }
enum PotionType { RED, BLUE }

@export var item_type: ItemType = ItemType.POTION
@export var item_id: String = "" ## 稳定标识(存档用),与工厂函数名一致
@export var item_name: String = "物品"
@export var description: String = ""
@export var potion_type: PotionType = PotionType.RED
@export var damage: float = 0.0 ## 武器攻击力
@export var defense: float = 0.0 ## 防具防御
@export var block_reduction: float = 0.0 ## 防具(盾)格挡减伤比例
@export var arrow_speed_mult: float = 1.0 ## 武器特殊效果:箭矢飞行速度倍率
@export var max_hp_bonus: float = 0.0 ## 装备基础属性:最大生命加成


static func red_potion() -> ItemData:
	var item := ItemData.new()
	item.item_id = "red_potion"
	item.item_type = ItemType.POTION
	item.item_name = "红药水"
	item.description = "使用后生命值恢复至满"
	item.potion_type = PotionType.RED
	return item


static func blue_potion() -> ItemData:
	var item := ItemData.new()
	item.item_id = "blue_potion"
	item.item_type = ItemType.POTION
	item.item_name = "蓝药水"
	item.description = "使用后蓝量恢复至满"
	item.potion_type = PotionType.BLUE
	return item


static func iron_sword() -> ItemData:
	var item := ItemData.new()
	item.item_id = "iron_sword"
	item.item_type = ItemType.WEAPON
	item.item_name = "铁剑"
	item.description = "基础武器,攻击力 +6"
	item.damage = 6.0
	return item


static func wooden_shield() -> ItemData:
	var item := ItemData.new()
	item.item_id = "wooden_shield"
	item.item_type = ItemType.ARMOR
	item.item_name = "木盾"
	item.description = "防御 +2,最大生命 +10,格挡时减免 80% 伤害"
	item.defense = 2.0
	item.block_reduction = 0.8
	item.max_hp_bonus = 10.0
	return item


## 生存弓:游侠基础武器,伤害最低
static func survival_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "survival_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "生存弓"
	item.description = "游侠基础武器,攻击力 +6"
	item.damage = 6.0
	return item


## 反曲弓:伤害中档
static func recurve_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "recurve_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "反曲弓"
	item.description = "弓身反曲,蓄力更足,攻击力 +12"
	item.damage = 12.0
	return item


## 长弓:伤害高
static func longbow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "longbow"
	item.item_type = ItemType.WEAPON
	item.item_name = "长弓"
	item.description = "弓臂修长,威力强大,攻击力 +18"
	item.damage = 18.0
	return item


## 精灵弓:特殊武器,伤害最高,且箭矢飞行速度提升 50%
static func elven_bow() -> ItemData:
	var item := ItemData.new()
	item.item_id = "elven_bow"
	item.item_type = ItemType.WEAPON
	item.item_name = "精灵弓"
	item.description = "精灵工艺的魔法弓,攻击力 +24,箭矢飞行速度 x1.5"
	item.damage = 24.0
	item.arrow_speed_mult = 1.5
	return item


static func cloth_armor() -> ItemData:
	var item := ItemData.new()
	item.item_id = "cloth_armor"
	item.item_type = ItemType.ARMOR
	item.item_name = "布衣"
	item.description = "防御 +1,最大生命 +15"
	item.defense = 1.0
	item.block_reduction = 0.0
	item.max_hp_bonus = 15.0
	return item


## 按工厂函数名还原物品(存档/读档用)。未知名称返回 null。
static func from_name(name: String) -> ItemData:
	match name:
		"red_potion":
			return red_potion()
		"blue_potion":
			return blue_potion()
		"iron_sword":
			return iron_sword()
		"wooden_shield":
			return wooden_shield()
		"survival_bow":
			return survival_bow()
		"recurve_bow":
			return recurve_bow()
		"longbow":
			return longbow()
		"elven_bow":
			return elven_bow()
		"cloth_armor":
			return cloth_armor()
	return null
