class_name EnemyData
## 怪物参数唯一数据源:固定敌人与刷怪器共用,改难度只动这里。

const TYPES := {
	"goblin": {
		"name": "哥布林",
		"hp": 30.0,
		"speed": 80.0,
		"chase": 140.0,
		"aggro": 220.0,
		"damage": 12.0,
		"interval": 0.8,
		"xp": 12,
		"drop": 0.35,
		"color": Color(0.35, 0.75, 0.3),
		"size": Vector2(30, 30),
		"anim": "goblin",
	},
	"skeleton": {
		"name": "骷髅怪",
		"hp": 60.0,
		"speed": 55.0,
		"chase": 105.0,
		"aggro": 260.0,
		"damage": 18.0,
		"interval": 0.9,
		"xp": 25,
		"drop": 0.35,
		"color": Color(0.82, 0.82, 0.78),
		"size": Vector2(40, 40),
		"anim": "skeleton",
	},
}


static func get_data(type: String) -> Dictionary:
	assert(TYPES.has(type), "未知怪物类型: " + type)
	return TYPES[type]


## 把类型参数一次性套到敌人实例上
static func apply_to(enemy: Enemy, type: String) -> void:
	var d := get_data(type)
	enemy.enemy_name = d.name
	enemy.max_hp = d.hp
	enemy.move_speed = d.speed
	enemy.chase_speed = d.chase
	enemy.aggro_radius = d.aggro
	enemy.contact_damage = d.damage
	enemy.attack_interval = d.interval
	enemy.xp_reward = d.xp
	enemy.drop_chance = d.drop
	enemy.body_color = d.color
	enemy.anim_character = d.anim
