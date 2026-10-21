extends SceneTree
## Run: godot --headless --path . --script res://tools/test_mvp_equipment.gd

var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var player_script = load("res://scripts/player.gd")
	var items = load("res://scripts/item_data.gd")
	var player = player_script.new()
	player.base_max_hp = 100.0
	player.base_max_mp = 50.0
	player.hp = 70.0
	player.mp = 20.0
	player.equipment.weapon = items.survival_bow()
	player.equipment.armor = items.cloth_armor()
	player._recalc_stats()
	_check(is_equal_approx(player.attack_damage(), 15.0), "Starter bow damage")
	_check(is_equal_approx(player.max_hp, 110.0), "Starter armor HP")
	player.equip_item("weapon", items.recurve_bow())
	_check(is_equal_approx(player._current_attack_interval(), 0.4), "Fast bow interval")
	player.equip_item("armor", items.ranger_leather())
	_check(is_equal_approx(player._current_speed(), 273.0), "Light armor speed")
	player.equip_item("armor", items.iron_plate())
	_check(is_equal_approx(player._current_speed(), 239.2), "Heavy armor slows base movement")
	_check(is_equal_approx(player._incoming_damage(12.0), 9.0), "Armor works without blocking")
	player.blocking = true
	_check(is_equal_approx(player._incoming_damage(12.0), 4.5), "Blocking applies after armor")
	_check(is_equal_approx(player._incoming_damage(0.0), 0.0), "Zero damage stays zero")
	player.blocking = false
	for i in range(10):
		player.equip_item("armor", items.cloth_armor())
		player.equip_item("armor", items.iron_plate())
	_check(is_equal_approx(player.max_hp, 130.0) and is_equal_approx(player.hp, 70.0), "Repeated equip never stacks HP or heals")
	var mana_armor = items.cloth_armor()
	mana_armor.max_mp_bonus = 10.0
	player.equip_item("armor", mana_armor)
	for i in range(10):
		player._recalc_stats()
	_check(is_equal_approx(player.max_mp, 60.0) and is_equal_approx(player.mp, 20.0), "MP bonus is recalculated from base")
	player.unequip_item("armor")
	_check(is_equal_approx(player.max_mp, 50.0), "Removing MP gear removes its bonus")
	player.hp = 10.0
	player.quickbar[0] = items.red_potion()
	player._use_quick_item(0)
	_check(is_equal_approx(player.hp, 45.0) and player.quickbar[0] == null, "Red potion restores 35% and is consumed")
	player.mp = 0.0
	player.quickbar[1] = items.blue_potion()
	player._use_quick_item(1)
	_check(is_equal_approx(player.mp, 20.0), "Blue potion restores 40%")
	_check(items.from_name("piercing_bow").pierce_count == 1, "Piercing bow restores by ID")
	_check(items.from_name("ranger_leather") != null, "Light armor restores by ID")
	player.free()
	await _arrow_checks()
	if failures.is_empty():
		print("MVP equipment checks OK: six items, replacement, armor, movement, MP, physical piercing")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _arrow_checks() -> void:
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 10.0, 700.0, 1)
	_check(arrow.pierces_remaining == 1, "Pierce count reaches arrow")
	_check(arrow.hit_targets.is_empty(), "New arrows have independent hit sets")
	arrow.free()
	await _physical_piercing_check()

func _physical_piercing_check() -> void:
	# The same scene used by the game supplies a fully initialized Player and
	# Enemy children. Disable enemy behavior before firing the actual arrow.
	var scene = load("res://main.tscn").instantiate()
	root.add_child(scene)
	await process_frame
	paused = false
	var menu = scene.get_node_or_null("ContinueMenu")
	if menu != null:
		menu.queue_free()
	for node in scene.get_children():
		if node is Node2D:
			node.set_physics_process(false)
	var first = scene.get_node_or_null("Goblin1")
	var second = scene.get_node_or_null("Goblin2")
	if first == null or second == null:
		_check(false, "Legacy scene enemy fixtures missing")
		scene.queue_free()
		return
	first.position = Vector2(7000, 100)
	second.position = Vector2(7080, 100)
	first.hp = 1000.0
	second.hp = 1000.0
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 10.0, 700.0, 1)
	arrow.position = Vector2(6940, 100)
	scene.add_child(arrow)
	for i in range(35):
		await physics_frame
	_check(is_equal_approx(first.hp, 990.0), "Piercing hits first enemy exactly once")
	_check(is_equal_approx(second.hp, 990.0), "Piercing reaches second enemy exactly once")
	_check(not is_instance_valid(arrow), "Arrow terminates after second target")
	first.hp = 1000.0
	second.hp = 1000.0
	var ordinary = load("res://scripts/arrow.gd").new()
	ordinary.setup(Vector2.RIGHT, 10.0, 700.0)
	ordinary.position = Vector2(6940, 100)
	scene.add_child(ordinary)
	for i in range(35):
		await physics_frame
	_check(is_equal_approx(first.hp, 990.0) and is_equal_approx(second.hp, 1000.0), "Ordinary arrows stop at first target")
	first.hp = 1000.0
	var wall := StaticBody2D.new()
	wall.position = Vector2(7040, 100)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 60)
	shape.shape = rect
	wall.add_child(shape)
	scene.add_child(wall)
	var blocked = load("res://scripts/arrow.gd").new()
	blocked.setup(Vector2.RIGHT, 10.0, 700.0, 1)
	blocked.position = Vector2(6940, 100)
	scene.add_child(blocked)
	for i in range(35):
		await physics_frame
	_check(is_equal_approx(first.hp, 990.0) and is_equal_approx(second.hp, 1000.0), "Piercing does not bypass walls")
	_check(not is_instance_valid(blocked), "Piercing arrow ends on wall")
	scene.queue_free()
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
