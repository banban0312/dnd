extends SceneTree
var failures: Array[String] = []
var arena: Node2D
var player
var Special

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	Special = load("res://scripts/mvp_special_enemy.gd")
	arena = Node2D.new()
	root.add_child(arena)
	player = load("res://scripts/player.gd").new()
	player.position = Vector2(800, 500)
	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	player.add_child(visual)
	arena.add_child(player)
	player.set_physics_process(false)
	player.invuln_timer = 1000
	await physics_frame
	var signatures := {}
	var atlas := Image.create(128, 36, false, Image.FORMAT_RGBA8)
	atlas.fill(Color("23232f"))
	var model_index := 0
	for role in ["shieldbearer", "bone_weaver", "wisp", "summoned_skeleton"]:
		var enemy = _enemy(role)
		_check(not enemy.get_node("Visual").visible and enemy.pixel_model.visible, role + " replaces the old sprite")
		_check(enemy.pixel_model.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, role + " uses a crisp source pixel grid")
		var image: Image = enemy.model_frames[0].get_image()
		signatures[hash(image.get_data())] = true
		atlas.blend_rect(image, Rect2i(0, 0, 32, 36), Vector2i(model_index * 32, 0))
		model_index += 1
		_check(image.get_data() != enemy.model_frames[1].get_image().get_data(), role + " has a distinct animated pixel frame")
		for y in image.get_height():
			for x in image.get_width():
				var alpha := image.get_pixel(x, y).a
				_check(alpha == 0.0 or alpha == 1.0, role + " has no antialiased body pixels")
		if role == "shieldbearer":
			await _shield_checks(enemy)
		elif role == "bone_weaver" or role == "wisp":
			await _volley_checks(enemy)
		else:
			_check(enemy.xp_reward == 0 and enemy.drop_chance == 0, "Summoned skeleton grants no XP/drop")
			var drops := [0]
			enemy.drop_requested.connect(func(_position, _item): drops[0] += 1)
			enemy.take_damage(10000)
			_check(enemy.dead and drops[0] == 0, "Summoned skeleton death emits no drops")
	atlas.resize(768, 216, Image.INTERPOLATE_NEAREST)
	atlas.save_png("res://_test/special-enemy-models.png")
	_check(signatures.size() == 4, "All four roles have different authored silhouettes")
	var chasing = _enemy("bone_weaver")
	chasing.encounter_rect = Rect2(400, 350, 100, 100)
	chasing.acquire_aggro()
	player.position = Vector2(900, 500)
	chasing._physics_process(0.1)
	_check(chasing.provoked and not chasing.returning_home and chasing.velocity.x > 0, "Special enemy maintains pursuit across encounter boundaries")
	var existing: Array = get_nodes_in_group("enemy_projectiles").duplicate()
	arena.queue_free()
	await process_frame
	_check(not is_instance_valid(chasing), "Floor disposal cleans special enemies")
	for shot in existing:
		_check(not is_instance_valid(shot), "Floor disposal cleans special enemy projectiles")
	for sound in root.get_node("Sfx").get_children():
		if sound is AudioStreamPlayer:
			sound.stop()
			sound.queue_free()
	await create_timer(0.25).timeout
	if failures.is_empty():
		print("MVP SPECIAL ENEMY OK: four unique crisp animated silhouettes, real front/back arrow damage, locked fan and six-ray gap volleys, windups, persistent pursuit, summon drops and floor cleanup")
		quit(0)
	else:
		for failure in failures:
			printerr("FAIL: " + failure)
		quit(1)

func _enemy(role: String):
	var enemy = Special.new()
	enemy.role = role
	enemy.position = Vector2(500, 500)
	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	enemy.add_child(visual)
	var contact := Area2D.new()
	contact.name = "ContactArea"
	contact.collision_mask = 0
	enemy.add_child(contact)
	arena.add_child(enemy)
	enemy.set_physics_process(false)
	return enemy

func _shield_checks(enemy) -> void:
	enemy.guard_direction = Vector2.RIGHT
	var before: float = enemy.hp
	var front = _arrow(enemy.position + Vector2(40, 0))
	front._hit_enemy(enemy)
	_check(is_equal_approx(before - enemy.hp, 5.0) and enemy.last_guarded, "Real arrow from front suffers 75 percent shield reduction")
	before = enemy.hp
	var back = _arrow(enemy.position - Vector2(40, 0))
	back._hit_enemy(enemy)
	_check(is_equal_approx(before - enemy.hp, 20.0) and not enemy.last_guarded, "Real arrow from behind deals full damage")
	front.queue_free()
	back.queue_free()
	await process_frame

func _arrow(position: Vector2):
	var arrow = load("res://scripts/arrow.gd").new()
	arrow.setup(Vector2.RIGHT, 20)
	arrow.position = position
	arena.add_child(arrow)
	arrow.set_physics_process(false)
	return arrow

func _volley_checks(enemy) -> void:
	player.position = enemy.position + Vector2(240, 0)
	enemy._begin_attack(player)
	var aim: Vector2 = enemy.locked_direction
	_check(enemy.attack_state == enemy.AttackState.WINDUP and enemy.state_time >= 1.0 and enemy.velocity == Vector2.ZERO, enemy.role + " stops with a readable windup")
	player.position = enemy.position + Vector2(0, 240)
	enemy._physics_process(0.1)
	_check(enemy.locked_direction == aim and enemy.velocity == Vector2.ZERO, enemy.role + " commits direction instead of tracking during windup")
	var expected: Array = enemy.volley_directions()
	enemy._resolve_strike(player)
	var actual: Array = []
	for shot in get_nodes_in_group("enemy_projectiles"):
		if shot.source_actor == enemy:
			shot.set_physics_process(false)
			actual.append(shot)
	_check(actual.size() == (3 if enemy.role == "bone_weaver" else 6), enemy.role + " fires the exact advertised number of shots")
	for i in actual.size():
		_check(actual[i].direction.is_equal_approx(expected[i]), enemy.role + " projectile matches its warning ray")
	if enemy.role == "bone_weaver":
		_check(actual[1].direction.is_equal_approx(aim), "Bone fan remains on original aim after target moves")
	else:
		_check(actual[0].speed == 155.0 and absf(actual[0].direction.angle_to(actual[1].direction)) > 1.0, "Wisp ring stays slow with navigable 60-degree gaps")
	await process_frame

func _check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
