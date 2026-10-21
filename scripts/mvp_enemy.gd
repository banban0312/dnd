extends Enemy
## Room encounters: readable roles, locked attacks and smooth pressure curves.
signal health_updated(current: float, maximum: float)
const Shot = preload("res://scripts/mvp_enemy_projectile.gd")
var is_elite := false
var is_boss := false
var role := "melee"
var home_position := Vector2.ZERO
var encounter_rect := Rect2()
var reduced_flash := false
var arena_active := false
var ward_label: Label
var current_speed := 0.0
var pursuit_time := 0.0
var steer_direction := Vector2.ZERO

enum AttackState { IDLE, WINDUP, DASH, RECOVERY }
var attack_state := AttackState.IDLE
var state_time := 0.0
var windup_duration := 0.55
var locked_direction := Vector2.RIGHT
var attack_kind := 0 # 0 melee, 1 physical charge, 2 locked ranged shot.
var boss_move_index := 0
var attack_hit := false
var flash_time := 0.0
var returning_home := false
var provoked := false

func acquire_aggro() -> void:
	if dead:
		return
	provoked = true
	returning_home = false
	if is_boss:
		awaken()

func _ready() -> void:
	# Top-down actors are obstacles, never moving floors carrying other actors.
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	platform_floor_layers = 0
	platform_wall_layers = 0
	if home_position == Vector2.ZERO:
		home_position = global_position
	super._ready()
	attack_cd = 0.7 + fposmod(home_position.x, 3) * 0.16
	health_updated.emit(hp, max_hp)
	if role == "ranged":
		var bow := Sprite2D.new()
		bow.texture = preload("res://assets/sprites/icon_bow.png")
		bow.scale = Vector2(0.65, 0.65)
		bow.position = Vector2(15, -3)
		add_child(bow)
	if role == "charger" and visual_sprite != null:
		visual_sprite.modulate = Color("e8a177")
	if is_boss:
		ward_label = Label.new()
		ward_label.text = "踏入圣所，破除封印"
		ward_label.position = Vector2(-110, -90)
		ward_label.add_theme_color_override("font_color", Color("d6ad68"))
		ward_label.add_theme_constant_override("outline_size", 4)
		add_child(ward_label)

func can_be_shot() -> bool:
	return not is_boss or arena_active

func awaken() -> void:
	arena_active = true
	if is_instance_valid(ward_label):
		ward_label.hide()

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	flash_time = maxf(0.0, flash_time - delta)
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		modulate = Color(2.0, 1.2, 1.1) if hit_flash > 0 and not reduced_flash else Color.WHITE
	var target := _get_player()
	var valid := is_instance_valid(target) and not target.dead
	if is_boss and not arena_active:
		valid = false
	if valid and encounter_rect.has_area() and not provoked:
		valid = encounter_rect.has_point(target.global_position)
	var dashing := false
	var leash := 590.0 if is_boss else 460.0
	if not provoked and (global_position.distance_to(home_position) > leash or (encounter_rect.has_area() and not encounter_rect.grow(-20).has_point(global_position))):
		returning_home = true
		_cancel_attack()
	if returning_home:
		_curve_move(home_position, delta, target)
		if global_position.distance_to(home_position) < 22:
			returning_home = false
			velocity = Vector2.ZERO
	elif attack_state == AttackState.WINDUP:
		velocity = Vector2.ZERO
		current_speed = move_toward(current_speed, 0.0, chase_speed * delta * 4)
		state_time -= delta
		if state_time <= 0:
			if attack_kind == 1:
				attack_state = AttackState.DASH
				state_time = 0.35
			else:
				_resolve_strike(target if valid else null)
				_begin_recovery()
	elif attack_state == AttackState.DASH:
		dashing = true
		velocity = locked_direction * dash_speed()
		state_time -= delta
		if state_time <= 0:
			_begin_recovery()
	elif attack_state == AttackState.RECOVERY:
		velocity = Vector2.ZERO
		current_speed = move_toward(current_speed, 0.0, chase_speed * 4 * delta)
		state_time -= delta
		if state_time <= 0:
			attack_state = AttackState.IDLE
	elif valid and (provoked or global_position.distance_to(target.global_position) <= aggro_radius):
		acquire_aggro()
		var distance := global_position.distance_to(target.global_position)
		var reach := attack_reach()
		if distance <= reach and attack_cd <= 0 and _clear_shot(target):
			_begin_attack(target)
		elif role == "ranged" and distance < 175 and _clear_shot(target):
			_curve_move(global_position + target.global_position.direction_to(global_position) * 110, delta, target)
		else:
			_curve_move(target.global_position, delta, target)
	else:
		pursuit_time = 0
		current_speed = move_toward(current_speed, 0.0, chase_speed * 3 * delta)
		velocity = steer_direction * current_speed
	move_and_slide()
	if dashing:
		for i in get_slide_collision_count():
			var body := get_slide_collision(i).get_collider()
			if valid and body == target and not attack_hit and _clear_shot(target):
				attack_hit = true
				target.take_damage(contact_damage, self)
			elif body is StaticBody2D:
				_begin_recovery()
	if encounter_rect.has_area() and (is_boss or not provoked):
		global_position = global_position.clamp(encounter_rect.position + Vector2(32, 32), encounter_rect.end - Vector2(32, 32))
	_update_visual_effects(delta)
	queue_redraw()

func dash_speed() -> float:
	return 740.0 if is_boss else 490.0

func attack_reach() -> float:
	if is_boss:
		return 270.0 if boss_move_index % 2 == 1 else 130.0
	return 340.0 if role == "ranged" else (185.0 if role == "charger" else 85.0)

func _curve_move(destination: Vector2, delta: float, target: Player) -> void:
	pursuit_time = minf(1.2, pursuit_time + delta)
	var ratio := pursuit_time / 1.2
	var ease := ratio * ratio * (3.0 - 2.0 * ratio)
	var distance := global_position.distance_to(destination)
	var near := clampf((distance - 45.0) / 130.0, 0.3, 1.0)
	var desired := chase_speed * lerpf(0.45, 1.5, ease) * near
	current_speed = move_toward(current_speed, desired, chase_speed * 2.3 * delta)
	var direction := global_position.direction_to(destination)
	if direction == Vector2.ZERO:
		velocity = Vector2.ZERO
		return
	var chosen := direction
	if not _probe_clear(direction, target):
		chosen = Vector2.ZERO
		for angle in [0.65, -0.65, 1.1, -1.1, 1.57, -1.57]:
			var candidate := direction.rotated(angle)
			if _probe_clear(candidate, target):
				chosen = candidate
				break
	if chosen == Vector2.ZERO:
		current_speed = move_toward(current_speed, 0.0, chase_speed * 4 * delta)
	steer_direction = steer_direction.lerp(chosen, 1.0 - exp(-9.0 * delta)).normalized()
	velocity = steer_direction * current_speed

func _probe_clear(direction: Vector2, target: Player) -> bool:
	var side := direction.orthogonal() * (30 if is_boss else 14)
	for offset in [Vector2.ZERO, side, -side]:
		var query := PhysicsRayQueryParameters2D.create(global_position + offset, global_position + offset + direction * 72, 1)
		query.exclude = [get_rid()]
		if is_instance_valid(target):
			query.exclude = [get_rid(), target.get_rid()]
		if not get_world_2d().direct_space_state.intersect_ray(query).is_empty():
			return false
	return true

func _begin_attack(target: Player) -> void:
	attack_state = AttackState.WINDUP
	locked_direction = global_position.direction_to(target.global_position)
	if locked_direction == Vector2.ZERO:
		locked_direction = Vector2.RIGHT
	attack_hit = false
	attack_kind = boss_move_index % 2 if is_boss else (2 if role == "ranged" else (1 if role == "charger" else 0))
	if is_boss:
		boss_move_index += 1
		windup_duration = 0.80 if attack_kind == 1 else 0.85
	else:
		windup_duration = 0.9 if role == "ranged" else (0.78 if role == "charger" else 0.55)
	state_time = windup_duration
	pursuit_time = 0.0
	velocity = Vector2.ZERO

func _resolve_strike(target: Player) -> void:
	flash_time = 0.20
	if attack_kind == 2:
		if is_instance_valid(target):
			fire_projectile(locked_direction, contact_damage, 300.0)
		return
	if not is_instance_valid(target) or target.dead or attack_hit:
		return
	var offset := target.global_position - global_position
	var radius := 145.0 if is_boss else (124.0 if anim_character == "skeleton" else 94.0)
	var in_shape := offset.length() <= radius
	if not is_boss:
		in_shape = in_shape and (offset.length() < 1 or locked_direction.dot(offset.normalized()) >= 0.25)
	if in_shape and _clear_shot(target):
		target.take_damage(contact_damage, self)
		attack_hit = true

func fire_projectile(direction: Vector2, amount: float, speed_value: float = 300.0) -> void:
	var shot := Shot.new()
	shot.setup(direction, amount, speed_value, self)
	shot.global_position = global_position + direction * 32
	get_parent().add_child(shot)

func _begin_recovery() -> void:
	attack_state = AttackState.RECOVERY
	state_time = 0.55 if is_boss else (0.7 if role == "charger" else 0.45)
	attack_cd = 1.6 if is_boss else (2.4 if role == "ranged" else 1.3)
	velocity = Vector2.ZERO

func _cancel_attack() -> void:
	attack_state = AttackState.IDLE
	state_time = 0
	attack_hit = false
	velocity = Vector2.ZERO
	current_speed = 0
	pursuit_time = 0

func _clear_shot(target: Player) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid(), target.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: float, source: Node = null) -> void:
	if dead or amount <= 0:
		return
	acquire_aggro()
	super.take_damage(amount, source)
	health_updated.emit(maxf(0, hp), max_hp)
	queue_redraw()

func _die() -> void:
	_cancel_attack()
	flash_time = 0
	super._die()
	queue_redraw()

func _roll_drop() -> void:
	pass


func _draw() -> void:
	if dead:
		return
	var gold := Color("c8a66b")
	var bone := Color("d8d2c4")
	var danger := Color("d36a61")
	if is_boss and not arena_active:
		draw_arc(Vector2.ZERO, 63, 0, TAU, 40, Color(gold, 0.8), 3)
	if is_elite or is_boss:
		draw_arc(Vector2.ZERO, 28.0 if is_elite else 49.0, 0, TAU, 48, Color(gold, 0.5), 1.0, true)
		for i in range(4):
			var direction := Vector2.RIGHT.rotated(PI * 0.25 + i * PI * 0.5)
			draw_line(direction * 32.0, direction * 37.0, gold, 2.0, true)
	if attack_state == AttackState.WINDUP or flash_time > 0.0:
		var progress := clampf(1.0 - state_time / windup_duration, 0.0, 1.0) if attack_state == AttackState.WINDUP else 1.0
		var outline := Color(danger, 0.65 + progress * 0.35)
		var fill := Color(danger, 0.08 + progress * 0.13)
		if attack_kind == 2:
			draw_line(Vector2.ZERO, locked_direction * 360.0, Color("91cfc6"), 2.0)
			draw_arc(locked_direction * 24, 10, 0, TAU * progress, 24, Color("edbf7c"), 3)
		elif attack_kind == 1:
			# Minkowski sum of the 58px boss body and the 26px player body.
			var extent := (42.0 if is_boss else 26.0) * (absf(locked_direction.x) + absf(locked_direction.y))
			var perpendicular := locked_direction.orthogonal() * extent
			var end := locked_direction * (dash_speed() * 0.35 + extent)
			var start := -locked_direction * extent
			var polygon := PackedVector2Array([start - perpendicular, start + perpendicular, end + perpendicular, end - perpendicular])
			draw_colored_polygon(polygon, fill)
			draw_polyline(PackedVector2Array([polygon[0], polygon[1], polygon[2], polygon[3], polygon[0]]), outline, 2.0, true)
			draw_line(Vector2.ZERO, end * progress, outline, 3.0, true)
		else:
			var radius := 145.0 if is_boss else (124.0 if anim_character == "skeleton" else 94.0)
			if is_boss:
				draw_circle(Vector2.ZERO, radius, fill)
				draw_arc(Vector2.ZERO, radius, 0, TAU, 64, outline, 2.0, true)
				draw_arc(Vector2.ZERO, maxf(3.0, radius * progress), 0, TAU, 64, Color(danger, 0.5), 1.5, true)
			else:
				var angle := locked_direction.angle()
				var points := PackedVector2Array([Vector2.ZERO])
				for i in range(21):
					points.append(Vector2.RIGHT.rotated(angle - 1.32 + 2.64 * float(i) / 20.0) * radius)
				draw_colored_polygon(points, fill)
				draw_arc(Vector2.ZERO, radius, angle - 1.32, angle + 1.32, 32, outline, 2.0, true)
				draw_line(Vector2.ZERO, points[1], outline, 1.0, true)
				draw_line(Vector2.ZERO, points[points.size() - 1], outline, 1.0, true)
	if hp < max_hp or is_elite:
		var bar_width := 54.0 if is_elite else 34.0
		var at := Vector2(-bar_width * 0.5, -54.0 if is_elite else -43.0)
		draw_rect(Rect2(at - Vector2(2, 2), Vector2(bar_width + 4, 7)), Color("15161c"))
		draw_rect(Rect2(at, Vector2(bar_width * clampf(hp / max_hp, 0.0, 1.0), 3)), gold if is_elite else bone)
