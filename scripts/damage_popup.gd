class_name DamagePopup
extends Label
## 伤害/经验飘字:向上飘并淡出,自动销毁。
## 静态工厂:DamagePopup.spawn(parent, world_pos, text, color)
## 挂到世界坐标节点下(parent 需为 Node2D),位置自动转为父节点局部坐标。

static func spawn(parent: Node, world_pos: Vector2, text: String, color: Color = Color(1, 0.9, 0.55)) -> void:
	var popup := DamagePopup.new()
	popup.text = text
	popup.add_theme_font_size_override("font_size", 15)
	popup.add_theme_color_override("font_color", color)
	popup.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	popup.add_theme_constant_override("outline_size", 3)
	if parent is Node2D:
		popup.position = (parent as Node2D).to_local(world_pos) + Vector2(-20, -40)
	else:
		popup.position = world_pos + Vector2(-20, -40)
	popup.z_index = 50
	parent.add_child(popup)
	var tween := popup.create_tween()
	tween.set_parallel(true)
	tween.tween_property(popup, "position:y", popup.position.y - 34.0, 0.55) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(popup, "modulate:a", 0.0, 0.55).set_delay(0.1)
	tween.chain().tween_callback(popup.queue_free)
