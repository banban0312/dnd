extends CharacterBody2D
## Enemy shots share the same physical wall/player layer, never home after firing.
var direction := Vector2.RIGHT
var damage := 12.0
var speed := 300.0
var source_actor: Node
var lifetime := 0.0

func setup(aim: Vector2, amount: float, velocity_speed: float = 300.0, source: Node = null) -> void:
	direction = aim.normalized()
	damage = amount
	speed = velocity_speed
	source_actor = source

func _ready() -> void:
	collision_layer = 0
	collision_mask = 1
	add_to_group("enemy_projectiles")
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(8, 8)
	shape.shape = rect
	add_child(shape)
	var sprite := Sprite2D.new()
	sprite.texture = preload("res://assets/sprites/arrow.png")
	sprite.scale = Vector2(0.6, 0.6)
	sprite.modulate = Color("8de0d2")
	sprite.rotation = direction.angle() + PI
	add_child(sprite)

func _physics_process(delta: float) -> void:
	lifetime += delta
	if lifetime > 3.2:
		queue_free()
		return
	var hit := move_and_collide(direction * speed * delta)
	if hit != null:
		var target := hit.get_collider()
		if target is Player:
			target.take_damage(damage, source_actor if is_instance_valid(source_actor) else self)
		queue_free()
