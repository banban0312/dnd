extends SceneTree
## godot --headless --path . --script res://tools/design/test_loot.gd
const Catalog = preload("res://tools/design/equipment_catalog.gd")
const Loot = preload("res://tools/design/loot_rules.gd")
var failures: Array[String] = []

func _initialize() -> void:
	_catalog_checks()
	_state_checks()
	_distribution_checks()
	if failures.is_empty():
		print("Loot prototype checks OK: catalog, eligibility, pity, duplicate suppression, replay, distributions")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)

func _catalog_checks() -> void:
	var ids: Dictionary = {}
	for item in Catalog.items():
		check(not ids.has(item.id), "Duplicate template ID: " + item.id)
		ids[item.id] = true
		check(item.slot in Catalog.SLOTS and item.grade in Catalog.GRADES, "Invalid catalog entry")
	check(ids.size() == 18, "Expected 18 templates")
	for depth in range(1, 4):
		for source in Loot.QUALITY:
			var weights: Array = Loot.QUALITY[source][depth - 1]
			var total := 0
			for i in weights.size():
				total += weights[i]
				if weights[i] > 0:
					for slot in Catalog.SLOTS:
						check(not Catalog.pool(depth, Catalog.GRADES[i], slot).is_empty(), "Missing eligible grade/slot pool")
			check(total == 100, "Quality weights must sum to 100")

func _state_checks() -> void:
	var a = Loot.new()
	a.start_run(1234)
	var before: Dictionary = a.export_state()
	check(not a.roll("boss", 1, "invalid").error.is_empty(), "Early boss must be rejected")
	check(a.export_state() == before, "Invalid calls must not mutate state")
	a.normal_misses = 8
	var reward: Dictionary = a.roll("normal", 1, "pity")
	check(reward.pity and reward.equipment.size() == 1 and a.normal_misses == 0, "Ninth eligible kill must drop")
	before = a.export_state()
	check(not a.roll("normal", 1, "pity").error.is_empty(), "Same event must not reroll")
	check(a.export_state() == before, "Duplicate claim must not advance RNG")
	a.normal_misses = 4
	a.roll("chest", 2, "unrelated")
	check(a.normal_misses == 4, "Chest must not reset ordinary-kill pity")
	var b = Loot.new()
	var json_copy: Dictionary = JSON.parse_string(JSON.stringify(a.export_state()))
	check(b.restore_state(json_copy), "State must survive JSON roundtrip")
	for i in range(50):
		check(a.roll("normal", 2, "replay%d" % i) == b.roll("normal", 2, "replay%d" % i), "Save/resume sequence must match")
	check(not b.restore_state({"version": 99}), "Unknown save version must be rejected")
	a.start_run(1234)
	check(a.claimed.is_empty() and a.normal_misses == 0 and a.serial == 0, "New run must reset all state")
	# Snapshot/response copies must not mutate their source.
	var snapshot: Dictionary = a.export_state()
	snapshot.claimed["external"] = true
	check(not a.claimed.has("external"), "Exported state must be independent")

func _distribution_checks() -> void:
	var loot = Loot.new()
	for depth in range(1, 4):
		loot.start_run(4000 + depth)
		var equipment := 0
		var dry_streak := 0
		var samples := 10000
		for i in samples:
			var result: Dictionary = loot.roll("normal", depth, "normal%d" % i)
			if result.equipment.is_empty():
				dry_streak += 1
			else:
				equipment += 1
				dry_streak = 0
				check(result.equipment[0].grade not in ["purple", "orange"], "Ordinary enemies cannot drop purple/orange")
			check(dry_streak <= 8, "Pity dry streak exceeded")
		var p: float = Loot.NORMAL_CHANCE[depth - 1]
		var expected := p / (1.0 - pow(1.0 - p, 9))
		var rate := float(equipment) / samples
		check(absf(rate - expected) < 0.02, "Ordinary drop rate outside broad simulation tolerance")
		print("Depth %d ordinary equipment: %d/%d (%.2f%%; pity-adjusted target %.2f%%)" % [depth, equipment, samples, rate * 100.0, expected * 100.0])
		for source in ["elite", "chest", "cursed_chest"]:
			for i in range(300):
				var result: Dictionary = loot.roll(source, depth, "%s:%d" % [source, i])
				check(result.equipment.size() == (2 if source == "cursed_chest" else 1), "Guaranteed count mismatch")
				for item in result.equipment:
					check(item.min_depth <= depth and item.grade != "orange", "Invalid depth or nonboss orange")
	loot.start_run(9876)
	var oranges := 0
	for i in range(2000):
		var result: Dictionary = loot.roll("boss", 3, "boss%d" % i)
		check(result.equipment.size() == 2, "Boss must drop two equipment items")
		check(result.equipment[0].grade in ["purple", "orange"], "Boss first drop must be purple+")
		check(result.equipment[1].grade in ["blue", "purple"], "Boss second drop must be blue/purple")
		if result.equipment[0].grade == "orange":
			oranges += 1
	check(absf(float(oranges) / 2000 - 0.10) < 0.035, "Boss orange rate mismatch")
	print("Depth III boss first-slot orange: %d/2000" % oranges)
	var owned := 0
	var other := 0
	for i in range(2500):
		var item: Dictionary = loot._equipment(3, [0,0,100,0,0], ["dd_bone_bow"], Catalog.SLOTS)
		if item.slot == "weapon":
			if item.id == "dd_bone_bow":
				owned += 1
			else:
				other += 1
	var repeat_rate := float(owned) / maxi(1, owned + other)
	check(repeat_rate > 0.12 and repeat_rate < 0.30, "Owned template should have approximately 20% share in a two-item equal-weight pool")
	print("Owned blue bow within weapon pool: %.2f%% (target 20%%)" % (repeat_rate * 100.0))
