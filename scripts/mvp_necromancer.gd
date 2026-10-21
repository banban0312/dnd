extends "res://scripts/mvp_enemy.gd"
## Ossuary sovereign: a readable rotating barrage, summoned guards, two shelter rites.
const BoneSpark = preload("res://scripts/mvp_necromancer_projectile.gd")
const RITUAL_DURATION := 4.0
const RECOVERY_DURATION := 2.0
const MAX_MINIONS := 4
var phase := 1
var shielded := false
var phase_state := "combat"
var ritual_time := 0.0
var safe_center := Vector2.ZERO
var safe_radius := 80.0
var threshold_index := 0
var wave_index := 0
var wave_time := 1.4
var summon_time := 5.0
var summon_warning := 0.0
var summon_points: Array[Vector2] = []
var summoned: Array[Enemy] = []
var recovery_time := 0.0
var explosion_flash := 0.0
var visual_clock := 0.0
var ritual_label: Label

func _ready() -> void:
	super._ready()
	if visual_sprite != null:
		visual_sprite.hide()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	ritual_label = Label.new()
	ritual_label.position = Vector2(-155, -146)
	ritual_label.add_theme_font_size_override("font_size", 21)
	ritual_label.add_theme_color_override("font_color", Color("edd5a1"))
	ritual_label.add_theme_constant_override("outline_size", 4)
	add_child(ritual_label)
	ritual_label.hide()

func pillars_remaining() -> int:
	return 0

func _player_in_arena() -> bool:
	var target := _get_player()
	return is_instance_valid(target) and not target.dead and encounter_rect.has_point(target.global_position)

func can_be_shot() -> bool:
	return arena_active and not shielded and _player_in_arena()

func take_damage(amount: float, source: Node = null) -> void:
	if dead or amount <= 0.0:
		return
	acquire_aggro()
	if shielded or (source != null and not _player_in_arena()):
		return
	if threshold_index < 2:
		var threshold := max_hp * float(2 - threshold_index) / 3.0
		if hp - amount <= threshold:
			hp = threshold
			threshold_index += 1
			phase = threshold_index + 1
			health_updated.emit(hp, max_hp)
			_begin_ritual()
			return
	super.take_damage(amount, source)

func _physics_process(delta: float) -> void:
	if dead:
		return
	visual_clock += delta
	explosion_flash = maxf(0.0, explosion_flash - delta)
	hit_flash = maxf(0.0, hit_flash - delta)
	velocity = Vector2.ZERO
	current_speed = 0.0
	if not arena_active:
		queue_redraw()
		return
	if phase_state == "ritual":
		ritual_time = maxf(0.0, ritual_time - delta)
		ritual_label.text = "归骨大葬 · 入罩 %.1f" % ritual_time
		if ritual_time <= 0.0:
			_resolve_ritual()
	elif phase_state == "recovery":
		recovery_time -= delta
		if recovery_time <= 0.0:
			phase_state = "combat"
	else:
		if not _player_in_arena():
			queue_redraw()
			return
		wave_time -= delta
		if wave_time <= 0.0:
			_emit_wave()
			wave_time = 1.65 - (phase - 1) * 0.22
		summon_time -= delta
		if summon_warning > 0.0:
			summon_warning -= delta
			if summon_warning <= 0.0:
				_complete_summon()
		elif summon_time <= 0.0:
			_prepare_summon()
	queue_redraw()

func _emit_wave() -> void:
	if not arena_active or shielded or not _player_in_arena():
		return
	var existing := get_tree().get_nodes_in_group("necromancer_projectiles").size()
	if wave_index % 2 == 1:
		var target := _get_player()
		var aim := global_position.direction_to(target.global_position)
		for angle in [-0.7, 0.0, 0.7]:
			if existing >= BoneSpark.LIMIT:
				break
			var seed := BoneSpark.new()
			var direction := aim.rotated(angle)
			seed.setup(direction, 10.0 + phase, 110.0, self)
			seed.is_seed = true
			seed.position = global_position + direction * 45.0
			get_parent().add_child(seed)
			existing += 1
		wave_index += 1
		return
	# A 75 degree opening rotates by 15 degrees each volley; the rest is evenly spaced.
	var offset := floorf(wave_index / 2.0) * PI / 12.0
	for slot in 24:
		if slot in [0, 1, 2, 22, 23]:
			continue
		if existing >= BoneSpark.LIMIT:
			break
		var direction := Vector2.RIGHT.rotated(offset + slot * TAU / 24.0)
		var bolt := BoneSpark.new()
		bolt.setup(direction, 11.0 + phase, 150.0 + phase * 12.0, self)
		bolt.position = global_position + direction * 45.0
		get_parent().add_child(bolt)
		existing += 1
	wave_index += 1

func _living_minions() -> int:
	for index in range(summoned.size() - 1, -1, -1):
		if not is_instance_valid(summoned[index]) or summoned[index].dead:
			summoned.remove_at(index)
	return summoned.size()

func _prepare_summon() -> void:
	summon_time = 9.0
	summon_points.clear()
	var available := MAX_MINIONS - _living_minions()
	if available <= 0:
		return
	for index in mini(2, available):
		var offset := Vector2(-200 if (wave_index + index) % 2 == 0 else 200, 150 if index == 0 else -150)
		var point := (global_position + offset).clamp(encounter_rect.position + Vector2(64, 64), encounter_rect.end - Vector2(64, 64))
		summon_points.append(point)
	summon_warning = 1.2

func _complete_summon() -> void:
	var game := get_parent().get_parent()
	if not game.has_method("_spawn_minion"):
		summon_points.clear()
		return
	for point in summon_points:
		if _living_minions() >= MAX_MINIONS:
			break
		var minion = game.call("_spawn_minion", point)
		if minion is Enemy:
			minion.add_to_group("necromancer_minions")
			summoned.append(minion)
	summon_points.clear()

func _clear_owned_objects() -> void:
	for bolt in get_tree().get_nodes_in_group("necromancer_projectiles"):
		if bolt.source_actor == self:
			bolt.queue_free()
	for minion in summoned:
		if is_instance_valid(minion):
			minion.queue_free()
	summoned.clear()
	summon_points.clear()
	summon_warning = 0.0

func _begin_ritual() -> void:
	shielded = true
	phase_state = "ritual"
	ritual_time = RITUAL_DURATION
	_cancel_attack()
	_clear_owned_objects()
	var target := _get_player()
	# Seeded, repeatable placements. Ordinary movement can cover the offset in < 2s.
	var ritual_rng := RandomNumberGenerator.new()
	ritual_rng.seed = int(home_position.x * 31 + home_position.y * 17) + threshold_index * 103
	var direction := Vector2.RIGHT.rotated(ritual_rng.randf_range(0.0, TAU))
	var player_position: Vector2 = target.global_position if is_instance_valid(target) else encounter_rect.get_center()
	var margin := Vector2(safe_radius + 32, safe_radius + 32)
	safe_center = (player_position + direction * 240.0).clamp(encounter_rect.position + margin, encounter_rect.end - margin)
	if safe_center.distance_to(player_position) < 150.0:
		var inward := player_position.direction_to(encounter_rect.get_center())
		safe_center = (player_position + inward * 240.0).clamp(encounter_rect.position + margin, encounter_rect.end - margin)
	ritual_label.show()
	ritual_label.text = "归骨大葬 · 入罩 4.0"
	var game := get_parent().get_parent()
	if game.has_method("_notify"):
		game._notify("举杖 · 4秒后全图爆炸！全身进入金色保护罩")
	queue_redraw()

func _player_fully_sheltered(target: Player) -> bool:
	var collision := target.get_node_or_null("CollisionShape2D") as CollisionShape2D
	var half := Vector2(13, 13)
	var center := target.global_position
	if collision != null and collision.shape is RectangleShape2D:
		half = collision.shape.size * 0.5
		center = collision.global_position
		for sign_x in [-1, 1]:
			for sign_y in [-1, 1]:
				if (collision.global_transform * Vector2(sign_x * half.x, sign_y * half.y)).distance_to(safe_center) > safe_radius:
					return false
		return true
	for sign_x in [-1, 1]:
		for sign_y in [-1, 1]:
			if (center + Vector2(sign_x * half.x, sign_y * half.y)).distance_to(safe_center) > safe_radius:
				return false
	return true

func _resolve_ritual() -> void:
	var target := _get_player()
	if is_instance_valid(target) and not target.dead and not _player_fully_sheltered(target):
		# This is the encounter's shelter check, not blockable or dodgeable weapon damage.
		target.hp = 0.0
		target.stats_changed.emit()
		target._die()
	shielded = false
	phase_state = "recovery"
	recovery_time = RECOVERY_DURATION
	explosion_flash = 0.45
	wave_time = 0.7
	summon_time = 5.0
	ritual_label.hide()
	queue_redraw()

func _die() -> void:
	_clear_owned_objects()
	super._die()

func _pixel_ring(center: Vector2, radius: float, color: Color, width := 3.0) -> void:
	var points := PackedVector2Array()
	for index in 49:
		var point := center + Vector2.RIGHT.rotated(index * TAU / 48.0) * radius
		points.append((point / 4.0).round() * 4.0)
	draw_polyline(points, color, width, false)

func _draw() -> void:
	if dead:
		return
	# Layered stone-gold / dead violet palette. All silhouette edges align to pixels.
	var ink := Color("161b23")
	var dark := Color("262532")
	var robe := Color("454052")
	var fold := Color("63556b")
	var gold := Color("b69a63")
	var bone := Color("d7cdb0")
	var lit := Color("f0e4c3")
	var lift := -20.0 if phase_state == "ritual" else 0.0
	# Floor shadow and torn hem.
	draw_rect(Rect2(-39, 19, 78, 12), Color("101820"))
	draw_rect(Rect2(-33, -15, 66, 40), ink)
	draw_rect(Rect2(-29, -26, 58, 43), dark)
	draw_rect(Rect2(-25, -21, 50, 40), robe)
	for index in 5:
		var x := -25 + index * 10
		draw_rect(Rect2(x, 14, 8, 10 + (index % 2) * 5), robe)
		draw_rect(Rect2(x + 2, -12, 3, 30), fold if index % 2 == 0 else dark)
	draw_rect(Rect2(-4, -16, 8, 36), dark)
	draw_rect(Rect2(-3, -8, 6, 6), gold)
	draw_rect(Rect2(-2, 0, 4, 16), gold)
	# Mantle, raised hood, skull with separate jaw, dark sockets and luminous pupils.
	draw_rect(Rect2(-35, -40, 70, 17), ink)
	draw_rect(Rect2(-31, -37, 62, 12), robe)
	draw_rect(Rect2(-23, -68, 46, 35), ink)
	draw_rect(Rect2(-19, -73, 38, 40), dark)
	draw_rect(Rect2(-15, -69, 30, 8), fold)
	draw_rect(Rect2(-15, -59, 30, 25), bone)
	draw_rect(Rect2(-11, -62, 22, 28), lit)
	draw_rect(Rect2(-13, -53, 10, 8), ink)
	draw_rect(Rect2(3, -53, 10, 8), ink)
	draw_rect(Rect2(-10, -50, 4, 3), Color("76b6a2"))
	draw_rect(Rect2(6, -50, 4, 3), Color("76b6a2"))
	draw_rect(Rect2(-2, -45, 4, 5), ink)
	draw_rect(Rect2(-10, -34, 20, 7), bone)
	for x in [-7, -1, 5]:
		draw_rect(Rect2(x, -35, 2, 6), dark)
	# Shoulder medallions and skeletal arm holding a carved staff.
	draw_rect(Rect2(-32, -33, 10, 9), gold)
	draw_rect(Rect2(22, -33, 10, 9), gold)
	draw_rect(Rect2(31, -28 + lift, 16, 8), dark)
	draw_rect(Rect2(37, -25 + lift, 15, 5), bone)
	draw_rect(Rect2(47, -32 + lift, 7, 13), lit)
	draw_rect(Rect2(48, -76 + lift, 8, 100), ink)
	draw_rect(Rect2(50, -76 + lift, 4, 98), Color("8e7252"))
	draw_rect(Rect2(45, -83 + lift, 14, 8), gold)
	draw_rect(Rect2(41, -101 + lift, 22, 18), dark)
	draw_rect(Rect2(46, -105 + lift, 12, 25), gold)
	draw_rect(Rect2(48, -101 + lift, 8, 17), Color("6fa897"))
	draw_rect(Rect2(50, -98 + lift, 4, 8), lit)
	if phase_state == "ritual":
		var at := to_local(safe_center)
		_pixel_ring(at, safe_radius, lit, 5.0)
		_pixel_ring(at, safe_radius - 8, gold, 2.0)
		draw_rect(Rect2(at - Vector2(12, 3), Vector2(24, 6)), gold)
		draw_rect(Rect2(at - Vector2(3, 12), Vector2(6, 24)), gold)
		# Receding segments show the remaining time without covering the playfield.
		for index in 16:
			var mark := at + Vector2.RIGHT.rotated(index * TAU / 16.0) * (safe_radius + 12)
			if float(index) / 16.0 < ritual_time / RITUAL_DURATION:
				draw_rect(Rect2((mark / 4.0).round() * 4.0 - Vector2(2, 2), Vector2(4, 4)), lit)
		var arena_at := to_local(encounter_rect.position)
		draw_rect(Rect2(arena_at, encounter_rect.size), Color("96734e"), false, 5.0)
	if explosion_flash > 0.0:
		# Three sharp concentric shock rings, no full-screen white strobe.
		for radius in [150.0, 300.0, 480.0]:
			_pixel_ring(Vector2.ZERO, radius * (1.45 - explosion_flash), gold, 4.0)
	for point in summon_points:
		var at := to_local(point)
		_pixel_ring(at, 26, Color("83a799"), 3.0)
		draw_line(at - Vector2(16, 0), at + Vector2(16, 0), bone, 2, false)
		draw_line(at - Vector2(0, 16), at + Vector2(0, 16), bone, 2, false)
