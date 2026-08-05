extends Area2D
class_name EquipmentPickup
## 装备掉落物:爆出弹跳 + 待机浮动动效,玩家靠近自动装备(替换同槽位)。

var item: ItemData


func setup(p_item: ItemData) -> void:
	item = p_item
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = _pick_icon(item)
	visual.scale = Vector2.ONE * 2.0
	add_child(visual)
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 14.0
	shape.shape = circle
	add_child(shape)
	z_index = 5


func _ready() -> void:
	body_entered.connect(_on_body_entered)
	_play_spawn_animation()
	_play_idle_float()


func _play_spawn_animation() -> void:
	modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE * 1.3, 0.10).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(self, "modulate:a", 1.0, 0.10)
	tw.tween_property(self, "scale", Vector2.ONE, 0.08).set_ease(Tween.EASE_IN)


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
		var slot := ""
		match item.item_type:
			ItemData.ItemType.WEAPON:
				slot = "weapon"
			ItemData.ItemType.ARMOR:
				slot = "armor"
		if slot != "":
			body.equip_item(slot, item)
			Sfx.play(SoundFactory.pickup(), -8.0)
			body.notify.emit("装备 %s" % item.item_name)
			queue_free()
		else:
			body.notify.emit("戒指槽位尚未开放")


## 按 item_id 匹配图标(复用 HUD icon 体系)
static func _pick_icon(p_item: ItemData) -> Texture2D:
	if p_item == null:
		return null
	var id := p_item.item_id
	if id in ["survival_bow", "recurve_bow", "longbow", "elven_bow", "dragon_bow"]:
		return preload("res://assets/sprites/icon_bow.png")
	if id in ["iron_sword", "oath_sword"]:
		return preload("res://assets/sprites/icon_sword.png")
	if id == "cloth_armor":
		return preload("res://assets/sprites/icon_cloth.png")
	if id == "chainmail":
		return preload("res://assets/sprites/icon_chainmail.png")
	if id == "iron_plate":
		return preload("res://assets/sprites/icon_plate.png")
	if id == "dragonscale":
		return preload("res://assets/sprites/icon_dragon.png")
	if id in ["wooden_shield", "iron_shield"]:
		return preload("res://assets/sprites/icon_shield.png")
	if id in ["lucky_ring", "wind_ring"]:
		return preload("res://assets/sprites/icon_ring.png")
	if id in ["guard_amulet", "blood_amulet", "sage_eye"]:
		return preload("res://assets/sprites/icon_amulet.png")
	return preload("res://assets/sprites/icon_bow.png")
