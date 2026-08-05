extends Area2D
class_name SavePoint
## 存档点:玩家触碰后通过信号上报重生位置(由主场景决定如何存档)。

signal respawn_requested(pos: Vector2)


func _ready() -> void:
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if body is Player:
		respawn_requested.emit(global_position)
