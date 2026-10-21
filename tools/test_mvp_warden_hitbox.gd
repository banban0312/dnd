extends SceneTree
## Real physical arrows aimed at opaque idle-frame pixels, all four approach sides.
## Body/visual/arena are from the actual first-floor Boss, moved into a wall-free lab.
var failures: Array[String] = []
var game
var boss
var image_data: Image
var visual: AnimatedSprite2D

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	game = load("res://mvp.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.start_run()
	game.set_process(false)
	game.player.set_physics_process(false)
	for foe in get_nodes_in_group("enemies"):
		foe.set_physics_process(false)
	boss = game.boss
	_check(boss != null and boss.is_boss, "First floor contains the real warden Boss")
	boss.global_position = Vector2(-2500, -2500)
	boss.home_position = boss.global_position
	boss.encounter_rect = Rect2(-3000, -3000, 1000, 1000)
	boss.awaken()
	visual = boss.get_node("Visual")
	visual.stop()
	visual.animation = "idle"
	visual.frame = 0
	var texture := visual.sprite_frames.get_frame_texture("idle", 0)
	image_data = texture.get_image()
	var opaque := image_data.get_used_rect()
	var local_top: Vector2 = _pixel_world(Vector2i(opaque.position.x, opaque.position.y)) - boss.global_position
	var local_bottom: Vector2 = _pixel_world(opaque.end - Vector2i.ONE) - boss.global_position
	var collision: CollisionShape2D
	for child in boss.get_children():
		if child is CollisionShape2D:
			collision = child
			break
	print("WARDEN_GEOMETRY frame=%s opaque=%s visual_scale=%s visual_offset=%s opaque_world_local_top=%s bottom=%s physical_shape=%s" % [texture.get_size(), opaque, visual.scale, visual.position, local_top, local_bottom, collision.shape.size])
	for part in [["crown", 0.04], ["head", 0.16], ["chest", 0.50], ["lower_body", 0.88], ["hem", 0.98]]:
		var sample := _opaque_sample(opaque, part[1])
		var aim_point := _pixel_world(sample)
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			await _case("%s_%s" % [part[0], direction], aim_point, direction, 220.0)
	# Match the real player's 34px arrow spawn offset while touching the 58px boss.
	for repeat in 6:
		for direction in [Vector2.RIGHT, Vector2.LEFT, Vector2.DOWN, Vector2.UP]:
			await _case("contact_spawn_%d_%s" % [repeat, direction], boss.global_position, direction, 42.1)
	await _piercing_check()
	await _visual_follow_check()
	await _immunity_checks()
	_check(collision.shape.size == Vector2(58, 58), "Independent arrow hurtbox preserves the original 58px physical body")
	game.queue_free()
	await process_frame
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await process_frame
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("WARDEN HITBOX OK: opaque head/chest/lower-body physical arrows from four sides, contact spawn, shield/outside-arena protection")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _pixel_world(pixel: Vector2i) -> Vector2:
	var centered_offset := Vector2(image_data.get_size()) * 0.5 if visual.centered else Vector2.ZERO
	return visual.to_global(Vector2(pixel) + Vector2(0.5, 0.5) - centered_offset + visual.offset)

func _opaque_sample(used: Rect2i, fraction: float) -> Vector2i:
	var y := used.position.y + int((used.size.y - 1) * fraction)
	var center := int(image_data.get_width() / 2)
	for distance in image_data.get_width():
		for x in [center - distance, center + distance]:
			if x >= 0 and x < image_data.get_width() and image_data.get_pixel(x, y).a > 0.5:
				return Vector2i(x, y)
	return used.get_center()

func _case(label: String, aim_point: Vector2, direction: Vector2, distance: float) -> void:
	boss.hp = boss.max_hp
	boss.shielded = false
	boss.phase = 1
	boss.phase_state = "combat"
	game.player.global_position = aim_point - direction * distance
	game.player.velocity = Vector2.ZERO
	await physics_frame
	await physics_frame
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(direction, 5.0, 700.0)
	arrow.position = game.player.global_position + direction * 34.0
	var initial: Vector2 = arrow.position
	game.add_child(arrow)
	for _frame in (8 if distance < 50.0 else 32):
		await physics_frame
	var damage: float = boss.max_hp - boss.hp
	var shot_allowed: bool = boss.can_be_shot()
	print("WARDEN_SHOT case=%s aim_local=%s spawn_local=%s damage=%.1f allowed=%s" % [label, aim_point - boss.global_position, initial - boss.global_position, damage, shot_allowed])
	_check(shot_allowed and is_equal_approx(damage, 5.0), "Opaque visible " + label + " must accept exactly one real arrow hit")
	if is_instance_valid(arrow):
		arrow.free()

func _piercing_check() -> void:
	boss.hp = boss.max_hp
	boss.shielded = false
	var aim: Vector2 = _pixel_world(_opaque_sample(image_data.get_used_rect(), 0.88))
	var target = game._spawn_enemy(aim + Vector2(150, 0), false, false, false)
	target.set_physics_process(false)
	target.home_position = target.position
	target.encounter_rect = Rect2()
	var second_hp: float = target.hp
	game.player.global_position = aim - Vector2(220, 0)
	await physics_frame
	await physics_frame
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 5.0, 700.0, 1)
	arrow.position = aim - Vector2(90, 0)
	game.add_child(arrow)
	for _frame in 7:
		await physics_frame
	_check(is_instance_valid(arrow) and arrow.pierces_remaining == 0, "Area-only lower-body hit consumes exactly one pierce and leaves arrow alive")
	_check(is_equal_approx(boss.max_hp - boss.hp, 5.0), "Area-only hit deals exactly one Boss damage resolution")
	if is_instance_valid(arrow):
		_check(arrow.hit_targets.size() == 1 and arrow.hit_targets.has(boss.get_instance_id()), "Hurtbox records Boss identity, not a separate target")
	for _frame in 25:
		await physics_frame
	_check(is_equal_approx(boss.max_hp - boss.hp, 5.0), "Remaining in or leaving hurtbox does not deal repeated damage")
	_check(is_equal_approx(second_hp - target.hp, 5.0) and not is_instance_valid(arrow), "Piercing arrow continues to real second target and stops after final permitted hit")
	if is_instance_valid(arrow):
		arrow.free()
	target.free()
	print("WARDEN_PIERCE area_first/body_not_crossed/single_consume/second_target=checked")

func _visual_follow_check() -> void:
	var original_position := visual.position
	var original_scale := visual.scale
	var original_rotation := visual.rotation
	visual.position = Vector2(3, 4)
	visual.scale = Vector2(4.0, 4.0)
	visual.rotation = 0.05
	visual.animation = "run"
	visual.frame = 2
	image_data = visual.sprite_frames.get_frame_texture("run", 2).get_image()
	var aim := _pixel_world(_opaque_sample(image_data.get_used_rect(), 0.98))
	await _case("run_frame_bob_scale_rotation_lower_left", aim, Vector2.RIGHT, 220.0)
	await _case("run_frame_bob_scale_rotation_lower_right", aim, Vector2.LEFT, 220.0)
	visual.position = original_position
	visual.scale = original_scale
	visual.rotation = original_rotation
	visual.animation = "idle"
	visual.frame = 0
	image_data = visual.sprite_frames.get_frame_texture("idle", 0).get_image()
	print("WARDEN_VISUAL_FOLLOW animation_union/bob/scale/rotation=checked")

func _immunity_checks() -> void:
	for mode in ["shield", "outside_arena"]:
		boss.hp = boss.max_hp
		boss.shielded = mode == "shield"
		game.player.global_position = boss.global_position - Vector2(200, 0) if mode == "shield" else boss.encounter_rect.position - Vector2(100, 0)
		var arrow = load("res://scripts/arrow.gd").new()
		arrow.setup(Vector2.RIGHT, 5.0, 700.0)
		# This lower-body trajectory only enters the hurtbox, not the solid body.
		arrow.position = boss.global_position + Vector2(-120, 42)
		game.add_child(arrow)
		for _frame in 20:
			await physics_frame
		_check(is_equal_approx(boss.hp, boss.max_hp), mode + " still rejects physical arrow damage")
		_check(not is_instance_valid(arrow), mode + " consumes physical incoming arrow")
		if is_instance_valid(arrow):
			arrow.free()

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
