extends "res://scripts/mvp_enemy.gd"
## Two combat phases, separated by four independent moving wards.
const Pillar = preload("res://scripts/mvp_pillar.gd")
var phase := 1
var shielded := false
var phase_state := "combat"
var transition_time := 0.0
var pillars: Dictionary = {}

class ArrowHurtbox extends Area2D:
	var warden: Enemy
	var hit_shape: CollisionShape2D

	func _physics_process(_delta: float) -> void:
		# Handles arrows born inside the volume as well as ordinary entry signals.
		if is_instance_valid(warden) and not warden.dead:
			for body in get_overlapping_bodies():
				warden._receive_hurtbox_arrow(body)
			# Area overlap lists arrive a tick later. A point-blank arrow may already be
			# physically recovered outside the body by then; inspect its birth position
			# before its first motion using the same transformed sensor rectangle.
			var rectangle := hit_shape.shape as RectangleShape2D
			var bounds := Rect2(-rectangle.size * 0.5, rectangle.size)
			for arrow in get_tree().get_nodes_in_group("arrows"):
				if arrow is Arrow and is_zero_approx(arrow.lifetime) and bounds.has_point(hit_shape.to_local(arrow.global_position)):
					warden._receive_hurtbox_arrow(arrow)

func _ready() -> void:
	super._ready()
	_setup_arrow_hurtbox()

func _setup_arrow_hurtbox() -> void:
	if visual_sprite == null:
		return
	# Union opaque pixels from every animation frame, in the sprite's own space.
	# Parenting to Visual follows its scale, position, bob, and rotation automatically.
	var bounds := Rect2()
	var initialized := false
	for animation in visual_sprite.sprite_frames.get_animation_names():
		for frame in visual_sprite.sprite_frames.get_frame_count(animation):
			var texture := visual_sprite.sprite_frames.get_frame_texture(animation, frame)
			var opaque := Rect2(texture.get_image().get_used_rect())
			if not opaque.has_area():
				continue
			if visual_sprite.centered:
				opaque.position -= texture.get_size() * 0.5
			opaque.position += visual_sprite.offset
			bounds = bounds.merge(opaque) if initialized else opaque
			initialized = true
	if not initialized:
		return
	# flip_h only flips drawing, so cover both orientations without altering body collision.
	var horizontal_extent := maxf(absf(bounds.position.x), absf(bounds.end.x))
	bounds.position.x = -horizontal_extent
	bounds.size.x = horizontal_extent * 2.0
	var hurtbox := ArrowHurtbox.new()
	hurtbox.name = "ArrowHurtbox"
	hurtbox.warden = self
	hurtbox.collision_layer = 0
	hurtbox.collision_mask = 4
	hurtbox.monitoring = true
	hurtbox.monitorable = false
	var collision := CollisionShape2D.new()
	var rectangle := RectangleShape2D.new()
	rectangle.size = bounds.size
	collision.shape = rectangle
	collision.position = bounds.get_center()
	hurtbox.hit_shape = collision
	hurtbox.add_child(collision)
	hurtbox.body_entered.connect(_receive_hurtbox_arrow)
	visual_sprite.add_child(hurtbox)

func _receive_hurtbox_arrow(body: Node2D) -> void:
	if dead or not body is Arrow or body.is_queued_for_deletion():
		return
	var arrow := body as Arrow
	if arrow.hit_targets.has(get_instance_id()):
		return
	if arrow._hit_enemy(self):
		# Area and solid body represent one target and consume one pierce allowance.
		arrow.add_collision_exception_with(self)
	else:
		arrow.queue_free()

func can_be_shot() -> bool:
	return arena_active and not shielded and _player_in_arena()

func _player_in_arena() -> bool:
	var target := _get_player()
	return is_instance_valid(target) and encounter_rect.has_point(target.global_position)

func pillars_remaining() -> int:
	return pillars.size()

func take_damage(amount: float, source: Node = null) -> void:
	if dead or amount <= 0:
		return
	acquire_aggro()
	if shielded or (source != null and not _player_in_arena()):
		return
	if phase == 1 and hp - amount <= max_hp * 0.5:
		hp = max_hp * 0.5
		health_updated.emit(hp, max_hp)
		phase = 2
		shielded = true
		phase_state = "transition"
		transition_time = 1.6
		_cancel_attack()
		# The announced transition is a safe break from previously fired attacks.
		for projectile in get_tree().get_nodes_in_group("enemy_projectiles"):
			if projectile.source_actor == self:
				projectile.queue_free()
		var game := get_parent().get_parent()
		if game.has_method("_notify"):
			game._notify("守望者进入二阶段 · 击破四根移动悬柱，解除护盾")
		queue_redraw()
		return
	super.take_damage(amount, source)

func _physics_process(delta: float) -> void:
	if dead:
		return
	if shielded:
		velocity = Vector2.ZERO
		current_speed = 0
		if phase_state == "transition":
			transition_time -= delta
			if transition_time <= 0:
				phase_state = "pillars"
				_spawn_pillars()
		queue_redraw()
		return
	super._physics_process(delta)

func _spawn_pillars() -> void:
	var offsets := [Vector2(-235, -135), Vector2(235, -135), Vector2(235, 175), Vector2(-235, 175)]
	for i in 4:
		var pillar := Pillar.new()
		pillar.anchor = encounter_rect.get_center() + offsets[i]
		pillar.arena = encounter_rect
		pillar.slot = i
		pillar.position = pillar.anchor
		pillar.died.connect(_on_pillar_died)
		pillars[pillar.get_instance_id()] = pillar
		get_parent().add_child(pillar)

func _on_pillar_died(pillar: Enemy) -> void:
	if dead or phase_state != "pillars" or not pillars.has(pillar.get_instance_id()):
		return
	pillars.erase(pillar.get_instance_id())
	if pillars.is_empty():
		shielded = false
		phase_state = "combat"
		boss_move_index = 0
		attack_cd = 1.0
		chase_speed = 143.0
		if visual_sprite != null:
			visual_sprite.modulate = Color("e5a398")
		var game := get_parent().get_parent()
		if game.has_method("_notify"):
			game._notify("四柱已碎 · 护盾消失，守望者的攻势加快")
	queue_redraw()

func _begin_attack(target: Player) -> void:
	if shielded:
		return
	super._begin_attack(target)
	if phase == 2:
		var pattern := [1, 0, 2, 1]
		attack_kind = pattern[(boss_move_index - 1) % pattern.size()]
		windup_duration = 0.68 if attack_kind == 1 else (0.85 if attack_kind == 2 else 0.7)
		state_time = windup_duration

func attack_reach() -> float:
	if phase == 2:
		var pattern := [1, 0, 2, 1]
		var next: int = pattern[boss_move_index % pattern.size()]
		return 130.0 if next == 0 else (370.0 if next == 2 else 270.0)
	return super.attack_reach()

func _resolve_strike(target: Player) -> void:
	if phase == 2 and attack_kind == 2:
		if is_instance_valid(target):
			for angle in [-0.26, 0.0, 0.26]:
				fire_projectile(locked_direction.rotated(angle), 14.0, 310.0)
		return
	super._resolve_strike(target)

func _begin_recovery() -> void:
	super._begin_recovery()
	if phase == 2:
		state_time = 0.42
		attack_cd = 1.0

func _draw() -> void:
	super._draw()
	if not dead and phase == 2 and attack_kind == 2 and attack_state == AttackState.WINDUP:
		var fan := PackedVector2Array([Vector2.ZERO, locked_direction.rotated(-0.26) * 360, locked_direction.rotated(0.26) * 360])
		draw_colored_polygon(fan, Color(0.6, 0.85, 0.8, 0.08))
		for angle in [-0.26, 0.26]:
			draw_line(Vector2.ZERO, locked_direction.rotated(angle) * 360, Color("91cfc6"), 2)
	if not dead and shielded:
		draw_circle(Vector2.ZERO, 72, Color(0.3, 0.65, 0.7, 0.16))
		draw_arc(Vector2.ZERO, 72, 0, TAU, 48, Color("a7dfd7"), 3)
		for value in pillars.values():
			if is_instance_valid(value) and not value.dead:
				draw_line(Vector2.ZERO, to_local(value.global_position), Color(0.45, 0.75, 0.72, 0.38), 2)
