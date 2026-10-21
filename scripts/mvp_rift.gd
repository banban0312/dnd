extends Node2D
## One readable fixed hazard, owned and freed with its floor.
const WINDUP := 1.0
const ACTIVE := 0.35
const REST := 2.0
const RADIUS := 76.0
var clock := -1.5
var hit_this_cycle := false
var phase_offset := 0.0

func _ready() -> void:
	add_to_group("mvp_rifts")
	clock -= phase_offset
	z_index = -1

func _physics_process(delta: float) -> void:
	clock += delta
	if clock >= WINDUP + ACTIVE + REST:
		clock = fmod(clock, WINDUP + ACTIVE + REST)
		hit_this_cycle = false
	if clock >= WINDUP and clock < WINDUP + ACTIVE and not hit_this_cycle:
		var player := get_tree().get_first_node_in_group("player") as Player
		if is_instance_valid(player) and not player.dead and player.invuln_timer <= 0 and global_position.distance_to(player.global_position) <= RADIUS:
			var query := PhysicsRayQueryParameters2D.create(global_position, player.global_position, 1)
			query.exclude = [player.get_rid()]
			if get_world_2d().direct_space_state.intersect_ray(query).is_empty():
				hit_this_cycle = true
				player.take_damage(10.0, self)
	queue_redraw()

func _draw() -> void:
	var warming := clock >= 0 and clock < WINDUP
	var active := clock >= WINDUP and clock < WINDUP + ACTIVE
	var color := Color("e1846e") if active else Color("a7584b")
	draw_arc(Vector2.ZERO, RADIUS, 0, TAU, 40, Color(color, 0.95 if active else (0.7 if warming else 0.23)), 2)
	for i in 6:
		var direction := Vector2.RIGHT.rotated(i * TAU / 6)
		draw_line(direction * 32, direction * 59, Color(color, 0.9 if active else 0.45), 3 if active else 2)
	if warming:
		draw_arc(Vector2.ZERO, maxf(2, RADIUS * clock / WINDUP), 0, TAU, 40, color, 2)
	if active:
		draw_circle(Vector2.ZERO, RADIUS, Color(color, 0.25))
		draw_circle(Vector2.ZERO, 18, Color("ffe6b4"))
