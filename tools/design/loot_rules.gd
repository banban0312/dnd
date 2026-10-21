extends RefCounted
## Standalone prototype: returns equipment dictionaries and potion IDs.
## No scene spawning, Player mutation or legacy save writes.

const Catalog = preload("res://tools/design/equipment_catalog.gd")
const SLOT_WEIGHTS := {"weapon": 45.0, "armor": 35.0, "trinket": 20.0}
const NORMAL_CHANCE := [0.10, 0.12, 0.14]
const NORMAL_MISS_LIMIT := 8
# Rows are depths I/II/III; columns white/green/blue/purple/orange.
const QUALITY := {
	"normal": [[75,25,0,0,0], [45,45,10,0,0], [20,55,25,0,0]],
	"elite": [[0,80,20,0,0], [0,45,50,5,0], [0,15,65,20,0]],
	"chest": [[45,45,10,0,0], [10,60,28,2,0], [0,35,55,10,0]],
	"cursed_chest": [[0,70,30,0,0], [0,30,60,10,0], [0,10,60,30,0]],
}
const BOSS_FIRST := [0,0,0,90,10]
const BOSS_SECOND := [0,0,70,30,0]

var rng := RandomNumberGenerator.new()
var normal_misses := 0
var serial := 0
var claimed: Dictionary = {}

func start_run(seed_value: int) -> void:
	rng.seed = seed_value
	normal_misses = 0
	serial = 0
	claimed.clear()

func roll(source: String, depth: int, event_id: String,
		owned_ids: Array = [], occupied_slots: Array = []) -> Dictionary:
	var result := {"equipment": [], "potions": [], "pity": false, "error": ""}
	if depth < 1 or depth > 3 or (source != "boss" and not QUALITY.has(source)):
		result.error = "Invalid source or depth"
		return result
	if source == "boss" and depth != 3:
		result.error = "Boss rewards require depth III"
		return result
	if event_id.is_empty():
		result.error = "An encounter/chest ID is required"
		return result
	if claimed.has(event_id):
		result.error = "Reward already resolved"
		return result
	# Mark even a no-drop event resolved. Calling twice must never reroll it.
	claimed[event_id] = true
	var count := 1
	if source == "normal":
		var forced := normal_misses >= NORMAL_MISS_LIMIT
		if forced or rng.randf() < NORMAL_CHANCE[depth - 1]:
			result.pity = forced
			normal_misses = 0
		else:
			count = 0
			normal_misses += 1
	elif source in ["cursed_chest", "boss"]:
		count = 2
	var recent: Array = owned_ids.duplicate()
	for i in count:
		var weights: Array = QUALITY[source][depth - 1] if source != "boss" else (BOSS_FIRST if i == 0 else BOSS_SECOND)
		var item := _equipment(depth, weights, recent, occupied_slots)
		serial += 1
		item["instance_id"] = "%s:%d" % [event_id, serial]
		result.equipment.append(item)
		recent.append(item.id)
	match source:
		"normal", "elite":
			var chance := 0.12 if source == "normal" else 0.35
			if rng.randf() < chance:
				result.potions.append(_potion())
		"chest":
			result.potions.append(_potion())
		"boss":
			result.potions.assign(["red_potion", "blue_potion"])
	return result

func _equipment(depth: int, grade_weights: Array, owned: Array, occupied: Array) -> Dictionary:
	var grades: Array = []
	var weights: Array = []
	for i in Catalog.GRADES.size():
		if grade_weights[i] > 0 and not Catalog.pool(depth, Catalog.GRADES[i]).is_empty():
			grades.append(Catalog.GRADES[i])
			weights.append(float(grade_weights[i]))
	var grade: String = grades[_pick(weights)]
	var slots: Array = []
	weights = []
	for slot in Catalog.SLOTS:
		if not Catalog.pool(depth, grade, slot).is_empty():
			slots.append(slot)
			weights.append(SLOT_WEIGHTS[slot] * (1.0 if slot in occupied else 1.5))
	var slot: String = slots[_pick(weights)]
	var candidates: Array[Dictionary] = Catalog.pool(depth, grade, slot)
	weights = []
	for candidate in candidates:
		weights.append(candidate.weight * (0.25 if candidate.id in owned else 1.0))
	return candidates[_pick(weights)].duplicate(true)

func _pick(weights: Array) -> int:
	var total := 0.0
	for weight in weights:
		total += float(weight)
	var cursor := rng.randf() * total
	for i in weights.size():
		cursor -= float(weights[i])
		if cursor < 0.0:
			return i
	return weights.size() - 1

func _potion() -> String:
	return "red_potion" if rng.randf() < 0.55 else "blue_potion"

func export_state() -> Dictionary:
	# Strings preserve 64-bit RNG values through JSON as well as ConfigFile.
	return {"version": 1, "rng_seed": str(rng.seed), "rng_state": str(rng.state),
		"normal_misses": normal_misses, "serial": serial, "claimed": claimed.duplicate(true)}

func restore_state(data: Dictionary) -> bool:
	if data.get("version", 0) != 1:
		return false
	if not str(data.get("rng_seed", "")).is_valid_int() or not str(data.get("rng_state", "")).is_valid_int():
		return false
	if not data.get("claimed", null) is Dictionary:
		return false
	var misses := int(data.get("normal_misses", -1))
	var next_serial := int(data.get("serial", -1))
	if misses < 0 or misses > NORMAL_MISS_LIMIT or next_serial < 0:
		return false
	rng.seed = int(data.rng_seed)
	rng.state = int(data.rng_state)
	normal_misses = misses
	serial = next_serial
	claimed = data.claimed.duplicate(true)
	return true
