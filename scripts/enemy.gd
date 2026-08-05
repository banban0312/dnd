extends CharacterBody2D
class_name Enemy
## 敌人:固定位置巡逻;玩家进入仇恨范围后以追击速度索敌;接触造成伤害,死亡概率掉落药水。
## 与主场景解耦:掉落通过 drop_requested 信号上抛,不再反向调用父节点。

signal died(enemy: Enemy)
signal drop_requested(pos: Vector2, item: ItemData)

@export var enemy_name: String = "哥布林"
@export var max_hp: float = 20.0
@export var move_speed: float = 70.0
@export var chase_speed: float = 110.0
@export var aggro_radius: float = 180.0
@export var contact_damage: float = 8.0
@export var xp_reward: int = 10
@export var drop_chance: float = 0.3
@export var body_color := Color(0.35, 0.75, 0.3)
@export var patrol_points: Array[Vector2] = []
@export var attack_interval: float = 1.0

var hp: float
var patrol_index := 0
var attack_cd := 0.0
var hit_flash := 0.0
var dead := false
var bob_timer := 0.0
var visual_sprite: AnimatedSprite2D
## 缓存玩家引用,避免每帧全树 group 查找(敌人数量多时性能关键)
var cached_player: Player

## 角色动画名(由 Spawner/场景预设):"goblin" / "skeleton"
@export var anim_character: String = "goblin"

@onready var contact_area: Area2D = $ContactArea


func _ready() -> void:
	hp = max_hp
	add_to_group("enemies")
	cached_player = get_tree().get_first_node_in_group("player") as Player
	visual_sprite = $Visual as AnimatedSprite2D
	if visual_sprite.sprite_frames == null:
		visual_sprite.sprite_frames = AnimFactory.make_frames(anim_character)
	visual_sprite.play("idle")
	_setup_shadow()


func _physics_process(delta: float) -> void:
	if dead:
		return
	if hit_flash > 0.0:
		hit_flash -= delta
		modulate = Color(3.0, 1.5, 1.5) if hit_flash > 0.0 else Color.WHITE
	var player := _get_player()
	if player != null and not player.dead and global_position.distance_to(player.global_position) <= aggro_radius:
		_chase(player)
	else:
		_patrol()
	move_and_slide()
	_try_contact_damage(delta)
	_update_visual_effects(delta)


func _setup_shadow() -> void:
	var shadow := Sprite2D.new()
	shadow.name = "Shadow"
	shadow.texture = preload("res://assets/sprites/shadow.png")
	shadow.position = Vector2(0, 4)
	shadow.z_index = -1
	add_child(shadow)


func _update_visual_effects(delta: float) -> void:
	if visual_sprite == null:
		return
	var moving := velocity.length() > 10.0
	var target_anim := "run" if moving else "idle"
	if visual_sprite.animation != target_anim:
		visual_sprite.play(target_anim)
	var bob_y := 0.0
	var bob_rot := 0.0
	if moving:
		bob_timer += delta * 9.0
		bob_y = sin(bob_timer) * 2.5
		bob_rot = sin(bob_timer * 0.5) * 0.06
		if absf(velocity.x) > 1.0:
			visual_sprite.flip_h = velocity.x < 0.0
	visual_sprite.position = visual_sprite.position.lerp(Vector2(0, bob_y), 0.3)
	visual_sprite.rotation = lerpf(visual_sprite.rotation, bob_rot, 0.15)


func _get_player() -> Player:
	return cached_player


func _chase(target: Player) -> void:
	var to_target := target.global_position - global_position
	if to_target.length() < 6.0:
		velocity = Vector2.ZERO
		return
	velocity = to_target.normalized() * chase_speed


func _patrol() -> void:
	if patrol_points.is_empty():
		velocity = Vector2.ZERO
		return
	var target: Vector2 = patrol_points[patrol_index]
	var to_target := target - global_position
	if to_target.length() < 8.0:
		velocity = Vector2.ZERO
		patrol_index = (patrol_index + 1) % patrol_points.size()
		return
	velocity = to_target.normalized() * move_speed


func _try_contact_damage(delta: float) -> void:
	attack_cd -= delta
	if attack_cd > 0.0:
		return
	for body in contact_area.get_overlapping_bodies():
		if body is Player and not body.dead:
			body.take_damage(contact_damage, self)
			attack_cd = attack_interval
			return


func take_damage(amount: float, _source: Node = null) -> void:
	if dead:
		return
	hp -= amount
	hit_flash = 0.12
	modulate = Color(3.0, 1.0, 1.0)
	Sfx.play(SoundFactory.hit(), -10.0)
	if hp <= 0.0:
		_die()


func _die() -> void:
	dead = true
	_roll_drop()
	died.emit(self)
	set_physics_process(false)
	Sfx.play(SoundFactory.die(), -8.0)
	# 死亡动画:白闪 + 放大 + 淡出,结束后销毁
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.2, 2.2, 2.2), 0.08)
	tween.tween_property(self, "scale", scale * 1.25, 0.18)
	tween.tween_property(self, "modulate:a", 0.0, 0.22)
	tween.tween_callback(queue_free)


func _roll_drop() -> void:
	if randf() >= drop_chance:
		return
	var item: ItemData = ItemData.red_potion() if randi() % 2 == 0 else ItemData.blue_potion()
	drop_requested.emit(global_position, item)
