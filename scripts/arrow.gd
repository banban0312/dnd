extends CharacterBody2D
class_name Arrow
## 箭矢占位:小方块,命中敌人造成伤害,撞墙或超时消失。

const MAX_LIFETIME := 1.5

var direction := Vector2.RIGHT
var speed := 700.0
var damage := 10.0
var lifetime := 0.0
var pierces_remaining := 0
var hit_targets: Dictionary = {}


func setup(p_direction: Vector2, p_damage: float, p_speed: float = 700.0, p_pierce_count: int = 0) -> void:
	direction = p_direction.normalized()
	damage = p_damage
	speed = p_speed
	pierces_remaining = maxi(0, p_pierce_count)
	# arrow.png 的箭头朝左,旋转 180 度后对准实际朝向
	rotation = direction.angle() + PI
	var visual := Sprite2D.new()
	visual.texture = preload("res://assets/sprites/arrow.png")
	visual.scale = Vector2(0.55, 0.55)
	add_child(visual)
	_setup_trail()
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(10, 10)
	shape.shape = rect
	add_child(shape)


## 箭矢拖尾:向后喷射的小粒子(程序生成纹理,像素风)
func _setup_trail() -> void:
	var trail := CPUParticles2D.new()
	trail.amount = 14
	trail.lifetime = 0.22
	trail.local_coords = false
	trail.direction = -direction
	trail.spread = 25.0
	trail.initial_velocity_min = 20.0
	trail.initial_velocity_max = 70.0
	trail.gravity = Vector2.ZERO
	trail.scale_amount_min = 0.8
	trail.scale_amount_max = 1.6
	trail.color = Color(1.0, 0.88, 0.55, 0.55)
	var img := Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color(1, 0.9, 0.6, 1))
	trail.texture = ImageTexture.create_from_image(img)
	trail.z_index = -1
	add_child(trail)


func _ready() -> void:
	collision_layer = 4
	collision_mask = 3
	add_to_group("arrows")


func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime >= MAX_LIFETIME:
		queue_free()
		return
	var remaining_motion := direction * speed * delta
	# A piercing arrow may cross several bodies in one physics tick.
	for _step in range(8):
		if remaining_motion.length_squared() <= 0.0001:
			return
		var collision := move_and_collide(remaining_motion)
		if collision == null:
			return
		var collider := collision.get_collider()
		if collider is Enemy:
			var keep_flying := _hit_enemy(collider)
			if not keep_flying:
				queue_free()
				return
			# Ignore the whole body after the first hit instead of getting stuck
			# inside its collision shape or repeatedly damaging it next frame.
			add_collision_exception_with(collider)
			remaining_motion = collision.get_remainder()
		else:
			queue_free()
			return


func _hit_enemy(enemy: Enemy) -> bool:
	# Even an invulnerable target notices an incoming player attack.
	if enemy.has_method("acquire_aggro"):
		enemy.call("acquire_aggro")
	if enemy.has_method("can_be_shot") and not enemy.call("can_be_shot"):
		return false
	var target_id := enemy.get_instance_id()
	if hit_targets.has(target_id):
		return true
	hit_targets[target_id] = true
	enemy.take_damage(damage, self)
	DamagePopup.spawn(get_parent(), global_position, str(int(damage)))
	Sfx.play(SoundFactory.hit(), -6.0)
	if pierces_remaining <= 0:
		return false
	pierces_remaining -= 1
	return true
