extends Area2D
class_name Chest
## 宝箱:靠近按 F 打开,概率掉落红/蓝药水并给予经验。
## 与主场景解耦:掉落/经验通过信号上抛,不再反向调用父节点。

signal opened(chest: Chest)
signal potion_requested(pos: Vector2, item: ItemData)
signal xp_requested(amount: int)

@export var drop_red_chance := 0.7
@export var drop_blue_chance := 0.7
@export var xp_reward := 25

var is_open := false
var player_near := false
var prompt_label: Label


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	body_exited.connect(_on_body_exited)
	prompt_label = Label.new()
	prompt_label.text = "按 F 打开宝箱"
	prompt_label.position = Vector2(-62, -38)
	prompt_label.add_theme_font_size_override("font_size", 14)
	prompt_label.visible = false
	add_child(prompt_label)


func _process(_delta: float) -> void:
	if is_open:
		return
	if player_near and Input.is_action_just_pressed("interact"):
		_open()
	prompt_label.visible = player_near and not is_open


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		player_near = true


func _on_body_exited(body: Node2D) -> void:
	if body is Player:
		player_near = false


func _open() -> void:
	is_open = true
	($Visual as Sprite2D).texture = preload("res://assets/sprites/chest_open.png")
	prompt_label.visible = false
	Sfx.play(SoundFactory.chest(), -6.0)
	if randf() < drop_red_chance:
		potion_requested.emit(global_position + Vector2(0, -34), ItemData.red_potion())
	if randf() < drop_blue_chance:
		potion_requested.emit(global_position + Vector2(0, 34), ItemData.blue_potion())
	for body in get_overlapping_bodies():
		if body is Player:
			xp_requested.emit(xp_reward)
			body.notify.emit("打开宝箱,+%d 经验" % xp_reward)
	opened.emit(self)
