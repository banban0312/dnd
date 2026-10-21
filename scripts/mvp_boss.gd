extends "res://scripts/mvp_enemy.gd"
## Two combat phases, separated by four independent moving wards.
const Pillar = preload("res://scripts/mvp_pillar.gd")
var phase := 1
var shielded := false
var phase_state := "combat"
var transition_time := 0.0
var pillars: Dictionary = {}

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
