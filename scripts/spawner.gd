extends Node2D
class_name Spawner
## 测试工具:刷怪开关。开启时每隔一段时间在刷新点概率生成敌人。

signal enemy_spawned(enemy: Enemy)

## 敌人物理层(与 project.godot layer_names 中 layer_2="enemies" 一致)
const ENEMY_LAYER := 2

@export var spawn_interval: float = 2.2
@export var max_alive: int = 14
@export var spawn_points: Array[Vector2] = []
@export var enabled: bool = true

var _timer := 0.0
var alive: Array[Enemy] = []

## 怪物类型池:具体参数统一在 EnemyData
const ENEMY_TYPES := ["goblin", "skeleton"]


func _physics_process(delta: float) -> void:
	if not enabled:
		return
	_timer += delta
	if _timer >= spawn_interval:
		_timer = 0.0
		_try_spawn()


func set_spawning(value: bool) -> void:
	enabled = value


func alive_count() -> int:
	return alive.size()


func _try_spawn() -> void:
	if alive.size() >= max_alive or spawn_points.is_empty():
		return
	var pos: Vector2 = spawn_points[randi() % spawn_points.size()]
	var type: String = ENEMY_TYPES[0] if randf() < 0.55 else ENEMY_TYPES[1]
	var enemy := _create_enemy(type)
	enemy.global_position = pos
	enemy.patrol_points = [pos, pos + Vector2(randf_range(-70.0, 70.0), randf_range(-50.0, 50.0))]
	add_child(enemy)
	alive.append(enemy)
	enemy.died.connect(_on_enemy_died)
	enemy_spawned.emit(enemy)


func _on_enemy_died(enemy: Enemy) -> void:
	alive.erase(enemy)


func _create_enemy(type: String) -> Enemy:
	var enemy := Enemy.new()
	enemy.collision_layer = ENEMY_LAYER
	enemy.collision_mask = 3
	EnemyData.apply_to(enemy, type)
	var data: Dictionary = EnemyData.get_data(type)

	var half: Vector2 = data.size * 0.5
	var body_shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = data.size
	body_shape.shape = rect
	enemy.add_child(body_shape)

	var visual := AnimatedSprite2D.new()
	visual.name = "Visual"
	visual.sprite_frames = AnimFactory.make_frames(data.anim)
	visual.scale = Vector2.ONE * AnimFactory.visual_scale(data.anim)
	visual.play("idle")
	enemy.add_child(visual)

	var contact := Area2D.new()
	contact.name = "ContactArea"
	contact.collision_layer = 0
	contact.collision_mask = 1
	enemy.add_child(contact)
	var contact_shape := CollisionShape2D.new()
	var contact_rect := RectangleShape2D.new()
	contact_rect.size = Vector2(44, 44)
	contact_shape.shape = contact_rect
	contact.add_child(contact_shape)
	return enemy
