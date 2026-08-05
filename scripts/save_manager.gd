class_name SaveManager
extends RefCounted
## 本地存档读写(ConfigFile → res://save/save.cfg)。
## 存档保存在项目目录下,开发期可直接查看/删除;
## 注意:导出发布后 res:// 只读,正式版需改回 user:// 或 OS 可写路径。
## 存档内容:角色状态(等级/经验/技能/装备/快捷栏)+ 地图种子 + 重生点。
## 存档点触碰时写入;启动时主场景根据存档弹"继续游戏/新游戏"菜单。

const SAVE_DIR := "res://save"
const SAVE_PATH := "res://save/save.cfg"


static func has_save() -> bool:
	return FileAccess.file_exists(SAVE_PATH)


static func delete_save() -> void:
	if has_save():
		DirAccess.remove_absolute(SAVE_PATH)


static func save_game(player: Player, map_gen: MapGenerator, respawn: Vector2) -> void:
	# 确保存档目录存在(res:// 在开发模式下可写)
	if not DirAccess.dir_exists_absolute(SAVE_DIR):
		var err_dir := DirAccess.make_dir_recursive_absolute(SAVE_DIR)
		if err_dir != OK:
			push_error("SaveManager: 无法创建存档目录 %s (%s)" % [SAVE_DIR, error_string(err_dir)])
	var cfg := ConfigFile.new()
	var pdata := player.export_state()
	cfg.set_value("player", "level", pdata.level)
	cfg.set_value("player", "xp", pdata.xp)
	cfg.set_value("player", "skill_points", pdata.skill_points)
	cfg.set_value("player", "skill_levels", pdata.skill_levels)
	cfg.set_value("player", "base_max_hp", pdata.base_max_hp)
	cfg.set_value("player", "max_mp", pdata.max_mp)
	cfg.set_value("player", "hp", pdata.hp)
	cfg.set_value("player", "mp", pdata.mp)
	cfg.set_value("player", "weapon", pdata.weapon)
	cfg.set_value("player", "armor", pdata.armor)
	cfg.set_value("player", "quickbar", pdata.quickbar)
	cfg.set_value("map", "rng_seed", map_gen.used_seed)
	cfg.set_value("respawn", "x", respawn.x)
	cfg.set_value("respawn", "y", respawn.y)
	var err := cfg.save(SAVE_PATH)
	if err != OK:
		push_error("SaveManager: 存档失败 (%s)" % error_string(err))


## 读取存档,返回可供 main.gd / Player.import_state 使用的字典;无存档返回空字典。
static func load_game() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) != OK:
		return {}
	var data := {}
	data["player"] = {
		"level": cfg.get_value("player", "level", 1),
		"xp": cfg.get_value("player", "xp", 0),
		"skill_points": cfg.get_value("player", "skill_points", 0),
		"skill_levels": cfg.get_value("player", "skill_levels", {"triple": 1, "draw": 1}),
		"base_max_hp": cfg.get_value("player", "base_max_hp", 100.0),
		"max_mp": cfg.get_value("player", "max_mp", 50.0),
		"hp": cfg.get_value("player", "hp", 100.0),
		"mp": cfg.get_value("player", "mp", 50.0),
		"weapon": cfg.get_value("player", "weapon", ""),
		"armor": cfg.get_value("player", "armor", ""),
		"quickbar": cfg.get_value("player", "quickbar", [null, null, null]),
	}
	data["rng_seed"] = cfg.get_value("map", "rng_seed", 0)
	data["respawn"] = Vector2(
		cfg.get_value("respawn", "x", 0.0),
		cfg.get_value("respawn", "y", 0.0)
	)
	return data
