extends Area2D
class_name PotionPickup
## 掉落药水:玩家靠近自动放入快捷栏(快捷栏仅用于掉落消耗品)。

var item: ItemData


func setup(p_item: ItemData) -> void:
	item = p_item
	var visual := Sprite2D.new()
	if item != null and item.item_type == ItemData.ItemType.POTION and item.potion_type == ItemData.PotionType.RED:
		visual.texture = preload("res://assets/sprites/potion_red.png")
	else:
		visual.texture = preload("res://assets/sprites/potion_blue.png")
	visual.scale = Vector2(1.5, 1.5)
	add_child(visual)

	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 12.0
	shape.shape = circle
	add_child(shape)

	z_index = 5


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		if body.add_item_to_quickbar(item):
			Sfx.play(SoundFactory.pickup(), -8.0)
			queue_free()
		else:
			body.notify.emit("快捷栏已满,无法拾取")
