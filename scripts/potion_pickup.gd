extends Area2D
class_name PotionPickup
## 掉落药水:0x72 flask 素材,爆出弹跳 + 待机浮动动效,玩家靠近自动拾取。

const TEX_RED: Texture2D = preload("res://assets/sprites/potion_red.png")
const TEX_BLUE: Texture2D = preload("res://assets/sprites/potion_blue.png")

var item: ItemData


func setup(p_item: ItemData) -> void:
	item = p_item
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = TEX_RED if item != null and item.potion_type == ItemData.PotionType.RED else TEX_BLUE
	visual.scale = Vector2.ONE * 2.0
	add_child(visual)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	z_index = 5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_play_spawn_animation()
	_play_idle_float()


## 爆出弹跳:0→1.2→1.0,带淡入
func _play_spawn_animation() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.3, 0.10).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.10)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_IN)


## 待机轻微上下浮动(循环)
func _play_idle_float() -> void:
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	var tw := visual.create_tween()
	tw.set_loops()
	tw.tween_property(visual, "position:y", -2.5, 0.9).set_ease(Tween.EASE_IN_OUT)
	tw.tween_property(visual, "position:y", 0.0, 0.9).set_ease(Tween.EASE_IN_OUT)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.add_to_backpack(item) or body.add_item_to_quickbar(item):
			Sfx.play(SoundFactory.pickup(), -8.0)
			queue_free()
		else:
			body.notify.emit("背包与快捷栏已满,无法拾取")
