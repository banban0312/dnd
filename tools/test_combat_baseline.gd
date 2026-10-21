extends SceneTree
## Deterministic laboratory measurement, NOT a human playthrough or duration gate.
## Run: Godot --headless --path . --script res://tools/test_combat_baseline.gd
## Stationary targets, no skills, no misses, no travel time in ideal TTK.

var failures: Array[String] = []
var fixture: Node2D
var targets: Array = []

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	seed(4217)
	fixture = Node2D.new()
	root.add_child(fixture)
	for index in range(2):
		var enemy = load("res://scripts/enemy.gd").new()
		enemy.position = Vector2(300 + 90 * index, 200)
		enemy.max_hp = 10000.0
		enemy.collision_layer = 2
		enemy.collision_mask = 0
		var shape := CollisionShape2D.new()
		var rectangle := RectangleShape2D.new()
		rectangle.size = Vector2(26, 26)
		shape.shape = rectangle
		enemy.add_child(shape)
		var contact := Area2D.new()
		contact.name = "ContactArea"
		enemy.add_child(contact)
		fixture.add_child(enemy)
		enemy.set_physics_process(false)
		targets.append(enemy)
	await physics_frame
	var player = load("res://scripts/player.gd").new()
	var items = load("res://scripts/item_data.gd")
	player.base_max_hp = 100.0
	player.base_max_mp = 50.0
	player.hp = 110.0
	player.mp = 50.0
	player.equipment.armor = items.cloth_armor()
	print("BASELINE scope=stationary_lab seed=4217 tick_hz=%d skills=false crit=false human_playtest=false" % Engine.physics_ticks_per_second)
	for weapon in [items.recurve_bow(), items.piercing_bow()]:
		player.equip_item("weapon", weapon)
		var damage: float = player.attack_damage()
		var interval: float = player._current_attack_interval()
		var single: Array[float] = await _shot(player, false)
		var aligned: Array[float] = await _shot(player, true)
		_check(is_equal_approx(single[0], damage) and is_zero_approx(single[1]), weapon.item_id + " single-target physical damage")
		_check(is_equal_approx(aligned[0], damage), weapon.item_id + " first aligned target hit once")
		_check(is_equal_approx(aligned[1], damage if weapon.pierce_count > 0 else 0.0), weapon.item_id + " second aligned target physical damage")
		print("BOW " + JSON.stringify({"id": weapon.item_id, "damage": damage, "interval_seconds": interval, "single_target_dps": damage / interval, "aligned_two_target_damage_per_arrow": aligned[0] + aligned[1], "aligned_two_target_dps": (aligned[0] + aligned[1]) / interval}))
		# Current implementation snapshot: normal roles, floor-two elite, both bosses.
		# These are arithmetic lower bounds after the first hit, not clear times.
		for hp_value in [28.0, 34.0, 42.0, 150.0, 360.0, 720.0]:
			var shots := ceili(hp_value / damage)
			print("IDEAL_TTK " + JSON.stringify({"bow": weapon.item_id, "target_hp_snapshot": hp_value, "shots": shots, "seconds_after_first_hit": (shots - 1) * interval}))
	_measure_guard(player)
	player.free()
	fixture.queue_free()
	await process_frame
	if failures.is_empty():
		print("COMBAT BASELINE OK; human movement, damage taken, potions and 8-12 minute pacing remain unmeasured")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _shot(player, aligned: bool) -> Array[float]:
	for target in targets:
		target.hp = 10000.0
	targets[1].position.y = 200.0 if aligned else 400.0
	await physics_frame
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, player.attack_damage(), player.arrow_speed * player._arrow_speed_mult(), player.equipment.weapon.pierce_count)
	arrow.position = Vector2(230, 200)
	fixture.add_child(arrow)
	for _frame in range(35):
		await physics_frame
	var result: Array[float] = [10000.0 - targets[0].hp, 10000.0 - targets[1].hp]
	if is_instance_valid(arrow):
		arrow.free()
	return result

func _measure_guard(player) -> void:
	player.equip_item("weapon", load("res://scripts/item_data.gd").recurve_bow())
	player.blocking = false
	var mobile_speed: float = player._current_speed()
	var free_interval: float = player._current_attack_interval()
	var unguarded_damage: float = player._incoming_damage(22.0)
	player.blocking = true
	_check(is_equal_approx(player._incoming_damage(22.0), unguarded_damage * 0.5), "Starter armor guard halves post-armor damage")
	print("GUARD_LEGACY " + JSON.stringify({"incoming_raw": 22, "unguarded_damage": unguarded_damage, "guarded_damage": player._incoming_damage(22.0), "move_speed_ratio": player._current_speed() / mobile_speed, "shot_interval_ratio": player._current_attack_interval() / free_interval}))
	_check(is_equal_approx(player._current_speed(), mobile_speed), "Legacy guard preserves movement")
	_check(is_equal_approx(player._current_attack_interval(), free_interval), "Legacy guard preserves attack interval")
	# MVP optional rule is checked here once present; the default legacy rule is
	# always measured above so adding the rule cannot silently change old scenes.
	if _has_property(player, "mvp_block_tradeoff"):
		_check(not player.get("mvp_block_tradeoff"), "MVP guard rules default off")
		player.set("mvp_block_tradeoff", true)
		print("GUARD_MVP " + JSON.stringify({"move_speed_ratio": player._current_speed() / mobile_speed, "shot_interval_ratio": player._current_attack_interval() / free_interval, "guarded_damage": player._incoming_damage(22.0)}))
		_check(is_equal_approx(player._current_speed() / mobile_speed, 0.75), "MVP guard movement multiplier is 0.75")
		_check(is_equal_approx(player._current_attack_interval() / free_interval, 1.35), "MVP guard shooting interval multiplier is 1.35")
		player.draw_speed_timer = 3.0
		var guarded_draw_interval: float = player._current_attack_interval()
		player.blocking = false
		var free_draw_interval: float = player._current_attack_interval()
		_check(is_equal_approx(guarded_draw_interval / free_draw_interval, 1.35), "Draw-speed skill preserves MVP guard cost")
		print("GUARD_MVP_DRAW " + JSON.stringify({"unguarded_interval_seconds": free_draw_interval, "guarded_interval_seconds": guarded_draw_interval}))
	else:
		print("GUARD_MVP not_implemented; legacy guard halves damage without movement/shooting cost")

func _has_property(object: Object, property: String) -> bool:
	for entry in object.get_property_list():
		if entry.name == property:
			return true
	return false

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
