extends "res://scripts/mvp_enemy.gd"
## Authored pixel silhouettes and committed attacks share the dungeon palette.
const OUTLINE := Color("161622")
const BONE := Color("d8d2bc")
const BONE_SHADE := Color("8c918b")
const GOLD := Color("be9455")
const GOLD_LIGHT := Color("e0bc79")
const PURPLE := Color("44334d")
const PURPLE_LIGHT := Color("6a526c")
const FIRE := Color("88d7c5")
const FIRE_LIGHT := Color("d2f1d8")
var pixel_model: Sprite2D
var model_frames: Array[Texture2D] = []
var model_clock := 0.0
var guard_direction := Vector2.RIGHT
var last_guarded := false

func _ready() -> void:
	match role:
		"shieldbearer":
			enemy_name = "铜誓盾卫"
			max_hp = 84
			chase_speed = 91
			contact_damage = 12
			xp_reward = 16
		"bone_weaver":
			enemy_name = "缚骨祭司"
			max_hp = 43
			chase_speed = 101
			contact_damage = 10
			xp_reward = 18
		"wisp":
			enemy_name = "提灯幽魂"
			max_hp = 36
			chase_speed = 125
			contact_damage = 8
			xp_reward = 17
		"summoned_skeleton":
			enemy_name = "契骨侍从"
			max_hp = 26
			chase_speed = 151
			contact_damage = 7
			xp_reward = 0
			drop_chance = 0
	aggro_radius = 350
	super._ready()
	if visual_sprite != null:
		visual_sprite.hide()
	pixel_model = Sprite2D.new()
	pixel_model.name = "PixelModel"
	pixel_model.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_model.position = Vector2(0, -24)
	pixel_model.scale = Vector2.ONE * 2
	for step in 2:
		model_frames.append(_make_model(step))
	pixel_model.texture = model_frames[0]
	add_child(pixel_model)

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	if dead:
		return
	if attack_state == AttackState.WINDUP:
		guard_direction = locked_direction
	elif velocity.length() > 5:
		guard_direction = velocity.normalized()
	model_clock += delta * (9.0 if velocity.length() > 5 else 3.0)
	pixel_model.flip_h = guard_direction.x < -0.1
	pixel_model.texture = model_frames[int(model_clock) % 2] if velocity.length() > 5 or role == "wisp" else model_frames[0]
	pixel_model.position.y = -24 + (roundf(sin(model_clock) * 2) if role == "wisp" else (float(int(model_clock) % 2) * -2 if velocity.length() > 5 else 0.0))

func attack_reach() -> float:
	if role == "bone_weaver":
		return 350.0
	if role == "wisp":
		return 290.0
	return 75.0 if role == "shieldbearer" else 69.0

func _begin_attack(target: Player) -> void:
	super._begin_attack(target)
	guard_direction = locked_direction
	if role == "bone_weaver" or role == "wisp":
		attack_kind = 2
		windup_duration = 1.05 if role == "bone_weaver" else 1.2
		state_time = windup_duration
	elif role == "shieldbearer":
		windup_duration = 0.75
		state_time = windup_duration

func _resolve_strike(target: Player) -> void:
	if role == "bone_weaver" or role == "wisp":
		flash_time = 0.2
		if not is_instance_valid(target) or target.dead:
			return
		for direction in volley_directions():
			fire_projectile(direction, contact_damage, 245.0 if role == "bone_weaver" else 155.0)
		return
	super._resolve_strike(target)

func volley_directions() -> Array[Vector2]:
	var directions: Array[Vector2] = []
	if role == "bone_weaver":
		for angle in [-0.36, 0.0, 0.36]:
			directions.append(locked_direction.rotated(angle))
	elif role == "wisp":
		for index in 6:
			directions.append(locked_direction.rotated(PI / 6 + TAU * index / 6.0))
	return directions

func _begin_recovery() -> void:
	super._begin_recovery()
	if role == "bone_weaver" or role == "wisp":
		state_time = 0.65
		attack_cd = 2.5 if role == "bone_weaver" else 2.9

func take_damage(amount: float, source: Node = null) -> void:
	last_guarded = false
	if role == "shieldbearer" and source is Node2D and is_instance_valid(source):
		var incoming := global_position.direction_to(source.global_position)
		if incoming.dot(guard_direction) > 0.25:
			amount *= 0.25
			last_guarded = true
	super.take_damage(amount, source)

func _draw() -> void:
	if dead:
		return
	if role == "shieldbearer" or role == "summoned_skeleton":
		super._draw()
	else:
		if attack_state == AttackState.WINDUP or flash_time > 0:
			var progress := clampf(1.0 - state_time / windup_duration, 0.0, 1.0) if attack_state == AttackState.WINDUP else 1.0
			for direction in volley_directions():
				# Discrete rune marks communicate the exact committed projectile rays.
				for distance in range(40, 321 if role == "bone_weaver" else 241, 24):
					var point := (direction * distance / 2).round() * 2
					draw_rect(Rect2(point - Vector2(2, 2), Vector2(4, 4)), Color(FIRE, 0.3 + progress * 0.6))
				draw_line(direction * 24, direction * (310 if role == "bone_weaver" else 230), Color(GOLD_LIGHT, 0.3 + progress * 0.6), 2, false)
		if hp < max_hp:
			draw_rect(Rect2(-19, -64, 38, 7), OUTLINE)
			draw_rect(Rect2(-17, -62, 34 * clampf(hp / max_hp, 0, 1), 3), BONE)
	if role == "shieldbearer":
		var side := guard_direction.orthogonal()
		var at := guard_direction * 28
		draw_line(at - side * 14, at + side * 14, FIRE_LIGHT if last_guarded and hit_flash > 0 else GOLD_LIGHT, 4, false)

func _make_model(step: int) -> Texture2D:
	var image := Image.create(32, 36, false, Image.FORMAT_RGBA8)
	image.fill(Color.TRANSPARENT)
	# Every rectangle is on the source pixel grid; no filtered vector artwork.
	match role:
		"shieldbearer":
			_box(image, 8, 11, 16, 18, OUTLINE)
			_box(image, 9, 12, 13, 15, PURPLE)
			_box(image, 11, 12, 9, 9, BONE_SHADE)
			_box(image, 12, 13, 7, 6, BONE)
			_box(image, 10, 5, 12, 8, OUTLINE)
			_box(image, 11, 5, 10, 5, GOLD)
			_box(image, 13, 4, 5, 2, GOLD_LIGHT)
			_box(image, 11, 10, 10, 3, BONE_SHADE)
			_box(image, 13, 10, 7, 1, OUTLINE)
			_box(image, 18, 10, 2, 1, FIRE)
			_box(image, 7, 12, 4, 4, GOLD)
			_box(image, 6, 13, 1, 2, GOLD_LIGHT)
			_box(image, 6, 19, 2, 12, OUTLINE)
			_box(image, 6, 10, 1, 10, BONE)
			_box(image, 4, 9, 5, 2, GOLD)
			_box(image, 10, 22, 11, 3, GOLD)
			_box(image, 11, 23, 9, 1, GOLD_LIGHT)
			_box(image, 11, 27, 4, 5 + step, OUTLINE)
			_box(image, 17, 27, 4, 6 - step, OUTLINE)
			_box(image, 11, 28, 3, 3, BONE_SHADE)
			_box(image, 18, 28, 3, 3, BONE_SHADE)
			# Tower shield projects past the shoulder, with a brass cross and rivets.
			_box(image, 20, 12, 10, 16, OUTLINE)
			_box(image, 21, 13, 8, 13, GOLD)
			_box(image, 22, 14, 6, 11, PURPLE)
			_box(image, 24, 14, 2, 11, GOLD_LIGHT)
			_box(image, 22, 18, 6, 2, GOLD_LIGHT)
			_box(image, 23, 26, 4, 2, GOLD)
		"bone_weaver":
			# Tall split mitre, skeletal face, narrow embroidered robe and bone staff.
			_box(image, 10, 6, 12, 11, OUTLINE)
			_box(image, 11, 4, 4, 5, OUTLINE)
			_box(image, 17, 4, 4, 5, OUTLINE)
			_box(image, 12, 5, 2, 5, GOLD)
			_box(image, 18, 5, 2, 5, GOLD)
			_box(image, 12, 10, 8, 7, BONE)
			_box(image, 13, 12, 2, 2, OUTLINE)
			_box(image, 17, 12, 2, 2, OUTLINE)
			_box(image, 13, 12, 1, 1, FIRE)
			_box(image, 17, 12, 1, 1, FIRE)
			_box(image, 15, 15, 2, 2, OUTLINE)
			_box(image, 10, 17, 12, 7, OUTLINE)
			_box(image, 8, 23, 16, 8, OUTLINE)
			_box(image, 10, 20, 12, 9, PURPLE)
			_box(image, 11, 19, 3, 10, PURPLE_LIGHT)
			_box(image, 15, 17, 2, 14, GOLD)
			_box(image, 9, 29, 6, 2 + step, BONE_SHADE)
			_box(image, 18, 29, 5, 3 - step, BONE_SHADE)
			_box(image, 5, 18, 5, 3, BONE)
			_box(image, 22, 18, 4, 3, BONE)
			_box(image, 25, 10, 2, 22, OUTLINE)
			_box(image, 25, 11, 1, 20, GOLD)
			_box(image, 23, 6, 6, 6, OUTLINE)
			_box(image, 24, 7, 4, 4, BONE)
			_box(image, 25, 8, 1, 1, FIRE)
			_box(image, 27, 8, 1, 1, FIRE)
		"wisp":
			# Hooded floating mantle with an asymmetrical swinging caged lantern.
			_box(image, 11, 5, 10, 3, OUTLINE)
			_box(image, 9, 8, 14, 13, OUTLINE)
			_box(image, 11, 7, 10, 12, PURPLE)
			_box(image, 12, 8, 8, 2, PURPLE_LIGHT)
			_box(image, 12, 11, 8, 7, OUTLINE)
			_box(image, 13, 13, 2, 2, FIRE)
			_box(image, 18, 13, 2, 2, FIRE)
			_box(image, 8, 19, 16, 9, OUTLINE)
			_box(image, 10, 18, 12, 8, PURPLE)
			_box(image, 9, 22, 4, 6, PURPLE_LIGHT)
			_box(image, 15, 20, 2, 7, GOLD)
			_box(image, 10, 27, 3, 4 - step, FIRE)
			_box(image, 16, 26, 2, 5 + step, FIRE)
			_box(image, 21, 26, 2, 3, FIRE)
			_box(image, 23, 17, 5, 2, BONE_SHADE)
			_box(image, 26, 18 + step, 1, 4, GOLD)
			_box(image, 23, 21 + step, 7, 9, OUTLINE)
			_box(image, 24, 22 + step, 5, 6, GOLD)
			_box(image, 25, 23 + step, 3, 4, FIRE)
			_box(image, 26, 24 + step, 1, 2, FIRE_LIGHT)
			_box(image, 23, 29 + step, 7, 1, GOLD_LIGHT)
		"summoned_skeleton":
			# Small uncovered rib cage and broken cleaver; no cloak silhouette.
			_box(image, 11, 11, 9, 8, OUTLINE)
			_box(image, 12, 12, 7, 5, BONE)
			_box(image, 13, 14, 2, 2, OUTLINE)
			_box(image, 17, 14, 2, 2, OUTLINE)
			_box(image, 13, 14, 1, 1, FIRE)
			_box(image, 17, 14, 1, 1, FIRE)
			_box(image, 14, 17, 4, 2, BONE_SHADE)
			_box(image, 15, 19, 2, 10, BONE)
			_box(image, 11, 20, 10, 2, BONE)
			_box(image, 11, 24, 10, 2, BONE_SHADE)
			_box(image, 11, 22, 2, 4, BONE)
			_box(image, 19, 22, 2, 4, BONE)
			_box(image, 10, 28, 5, 2, PURPLE)
			_box(image, 18, 28, 4, 2, PURPLE)
			_box(image, 11, 30, 2, 3 - step, BONE)
			_box(image, 19, 30, 2, 2 + step, BONE)
			_box(image, 8, 21, 2, 7, BONE_SHADE)
			_box(image, 21, 20, 3, 3, BONE)
			_box(image, 24, 16, 2, 9, OUTLINE)
			_box(image, 24, 16, 5, 6, BONE_SHADE)
			_box(image, 27, 16, 2, 4, BONE)
	# Single source-pixel accents: rivets, rib gaps, worn hems and flame cores.
	match role:
		"shieldbearer":
			_box(image, 11, 6, 7, 1, GOLD_LIGHT)
			_box(image, 12, 7, 2, 2, Color("a47c45"))
			_box(image, 20, 6, 1, 3, Color("785638"))
			_box(image, 12, 14, 2, 5, Color("b6b7a3"))
			for row in [14, 16, 18]:
				for column in [15, 18]:
					_box(image, column, row, 1, 1, BONE_SHADE)
			_box(image, 10, 26, 2, 2, PURPLE_LIGHT)
			_box(image, 18, 25, 2, 2, PURPLE_LIGHT)
			for point in [Vector2i(22, 14), Vector2i(27, 14), Vector2i(22, 24), Vector2i(27, 24)]:
				_box(image, point.x, point.y, 1, 1, GOLD_LIGHT)
			_box(image, 24, 17, 2, 4, BONE)
			_box(image, 25, 18, 1, 2, FIRE)
			_box(image, 28, 16, 1, 8, Color("785638"))
		"bone_weaver":
			_box(image, 12, 10, 7, 1, BONE_SHADE)
			_box(image, 14, 16, 1, 1, BONE)
			_box(image, 17, 16, 1, 1, BONE)
			_box(image, 10, 18, 4, 2, BONE_SHADE)
			_box(image, 18, 18, 4, 2, BONE_SHADE)
			_box(image, 11, 18, 2, 1, BONE)
			_box(image, 19, 18, 2, 1, BONE)
			for row in [21, 24, 27]:
				_box(image, 15, row, 2, 1, GOLD_LIGHT)
			_box(image, 20, 22, 1, 6, PURPLE_LIGHT)
			_box(image, 12, 28, 1, 2, OUTLINE)
			_box(image, 21, 28, 1, 2, OUTLINE)
			_box(image, 25, 10, 3, 1, BONE_SHADE)
			_box(image, 25, 11, 1, 2, BONE)
		"wisp":
			_box(image, 13, 4, 6, 1, OUTLINE)
			_box(image, 13, 6, 4, 1, PURPLE_LIGHT)
			_box(image, 11, 10, 1, 7, PURPLE_LIGHT)
			_box(image, 21, 11, 1, 8, Color("302536"))
			_box(image, 10, 19, 3, 2, PURPLE_LIGHT)
			_box(image, 15, 20, 2, 1, GOLD_LIGHT)
			_box(image, 11, 28, 1, 4 - step, FIRE_LIGHT)
			_box(image, 16, 28, 1, 4 + step, FIRE_LIGHT)
			_box(image, 21, 25, 1, 4, FIRE_LIGHT)
			_box(image, 24, 22 + step, 5, 1, GOLD_LIGHT)
			_box(image, 25, 25 + step, 1, 2, Color("48a995"))
			_box(image, 26, 28 + step, 1, 1, GOLD_LIGHT)
		"summoned_skeleton":
			_box(image, 12, 12, 6, 1, BONE_SHADE)
			_box(image, 14, 17, 1, 1, BONE)
			_box(image, 17, 17, 1, 1, BONE)
			_box(image, 12, 23, 8, 1, BONE)
			_box(image, 15, 22, 2, 1, BONE_SHADE)
			_box(image, 15, 26, 2, 2, BONE_SHADE)
			_box(image, 8, 24, 2, 1, OUTLINE)
			_box(image, 24, 16, 4, 1, BONE)
			_box(image, 27, 20, 2, 1, OUTLINE)
	return ImageTexture.create_from_image(image)

func _box(image: Image, x: int, y: int, width: int, height: int, color: Color) -> void:
	image.fill_rect(Rect2i(x, y, width, height), color)
