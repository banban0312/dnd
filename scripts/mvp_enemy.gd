extends Enemy
## MVP enemy attacks use a visible wind-up and one damage resolution per move.
## Main owns reward generation; the legacy contact attack and drops are unused.

signal health_updated(current: float, maximum: float)

var is_elite := false
var is_boss := false
var home_position := Vector2.ZERO

enum AttackState { IDLE, WINDUP, DASH, RECOVERY }
var attack_state := AttackState.IDLE
var state_time := 0.0
var windup_duration := 0.55
var locked_direction := Vector2.RIGHT
var attack_kind := 0 # 0: strike; 1: boss dash.
var boss_move_index := 0
var attack_hit := false
var flash_time := 0.0
var returning_home := false

func _ready() -> void:
	if home_position == Vector2.ZERO:
		home_position = global_position
	super._ready()
	attack_cd = 0.7
	health_updated.emit(hp, max_hp)

func _physics_process(delta: float) -> void:
	if dead:
		return
	attack_cd = maxf(0.0, attack_cd - delta)
	flash_time = maxf(0.0, flash_time - delta)
	if hit_flash > 0.0:
		hit_flash = maxf(0.0, hit_flash - delta)
		modulate = Color(2.0, 1.2, 1.1) if hit_flash > 0.0 else Color.WHITE
	var target := _get_player()
	var target_valid := is_instance_valid(target) and not target.dead
	var leash := 590.0 if is_boss else 460.0
	if global_position.distance_to(home_position) > leash:
		returning_home = true
		_cancel_attack()
	if returning_home:
		velocity = global_position.direction_to(home_position) * chase_speed
		if global_position.distance_to(home_position) < 22.0:
			returning_home = false
			velocity = Vector2.ZERO
	elif attack_state == AttackState.WINDUP:
		velocity = Vector2.ZERO
		state_time -= delta
		if state_time <= 0.0:
			if attack_kind == 1:
				attack_state = AttackState.DASH
				state_time = 0.35
			else:
				_resolve_strike(target if target_valid else null)
				_begin_recovery()
	elif attack_state == AttackState.DASH:
		velocity = locked_direction * 740.0
		state_time -= delta
		if target_valid and not attack_hit and global_position.distance_to(target.global_position) <= 72.0:
			if _clear_shot(target):
				target.take_damage(contact_damage, self)
				attack_hit = true
		if state_time <= 0.0:
			_begin_recovery()
	elif attack_state == AttackState.RECOVERY:
		velocity = Vector2.ZERO
		state_time -= delta
		if state_time <= 0.0:
			attack_state = AttackState.IDLE
	elif target_valid and global_position.distance_to(target.global_position) <= aggro_radius:
		var distance := global_position.distance_to(target.global_position)
		var reach := 205.0 if is_boss else (108.0 if anim_character == "skeleton" else 72.0)
		if distance <= reach and attack_cd <= 0.0 and _clear_shot(target):
			_begin_attack(target)
		else:
			_chase(target)
	else:
		_patrol()
	move_and_slide()
	_update_visual_effects(delta)
	queue_redraw()

func _begin_attack(target: Player) -> void:
	attack_state = AttackState.WINDUP
	locked_direction = global_position.direction_to(target.global_position)
	if locked_direction == Vector2.ZERO:
		locked_direction = Vector2.RIGHT
	attack_hit = false
	attack_kind = boss_move_index % 2 if is_boss else 0
	if is_boss:
		boss_move_index += 1
		windup_duration = 0.80 if attack_kind == 1 else 0.85
	else:
		windup_duration = 0.66 if anim_character == "skeleton" else 0.55
	state_time = windup_duration
	velocity = Vector2.ZERO

func _resolve_strike(target: Player) -> void:
	flash_time = 0.20
	if not is_instance_valid(target) or target.dead or attack_hit:
		return
	var offset := target.global_position - global_position
	var radius := 145.0 if is_boss else (124.0 if anim_character == "skeleton" else 94.0)
	var in_shape := offset.length() <= radius
	if not is_boss:
		in_shape = in_shape and (offset.length() < 1.0 or locked_direction.dot(offset.normalized()) >= 0.25)
	if in_shape and _clear_shot(target):
		target.take_damage(contact_damage, self)
		attack_hit = true

func _begin_recovery() -> void:
	attack_state = AttackState.RECOVERY
	state_time = 0.55 if is_boss else 0.38
	attack_cd = 1.6 if is_boss else 1.3
	velocity = Vector2.ZERO

func _cancel_attack() -> void:
	attack_state = AttackState.IDLE
	state_time = 0.0
	attack_hit = false
	velocity = Vector2.ZERO

func _clear_shot(target: Player) -> bool:
	var query := PhysicsRayQueryParameters2D.create(global_position, target.global_position, 1)
	query.exclude = [get_rid(), target.get_rid()]
	return get_world_2d().direct_space_state.intersect_ray(query).is_empty()

func take_damage(amount: float, source: Node = null) -> void:
	if dead:
		return
	super.take_damage(amount, source)
	health_updated.emit(maxf(0.0, hp), max_hp)
	queue_redraw()

func _die() -> void:
	_cancel_attack()
	flash_time = 0.0
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
	if is_elite or is_boss:
		draw_arc(Vector2.ZERO, 28.0 if is_elite else 49.0, 0, TAU, 48, Color(gold, 0.5), 1.0, true)
		for i in range(4):
			var direction := Vector2.RIGHT.rotated(PI * 0.25 + i * PI * 0.5)
			draw_line(direction * 32.0, direction * 37.0, gold, 2.0, true)
	if attack_state == AttackState.WINDUP or flash_time > 0.0:
		var progress := clampf(1.0 - state_time / windup_duration, 0.0, 1.0) if attack_state == AttackState.WINDUP else 1.0
		var outline := Color(danger, 0.65 + progress * 0.35)
		var fill := Color(danger, 0.08 + progress * 0.13)
		if attack_kind == 1:
			var perpendicular := locked_direction.orthogonal() * 35.0
			var end := locked_direction * 300.0
			var polygon := PackedVector2Array([-perpendicular, perpendicular, end + perpendicular, end - perpendicular])
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
