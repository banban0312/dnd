class_name Boss
extends Enemy
## 独眼巨魔 Boss:镇守中央房间的"深渊看守者"。
## 区域仇恨 —— 仅玩家进入领地(arena_rect,世界坐标矩形)才追击;玩家离开即回领地中心待机。
## 永不离场 —— 追击目标 clamp 到领地内,物理上无法离开中心区域。
## 动态待机 —— 呼吸浮动 + 独眼发光脉动 + 脚下暗红粒子,常驻播放。

const CYCLOPS_TEX: Texture2D = preload("res://assets/sprites/cyclops.png")

signal health_changed(current: float, max: float)

## 领地(世界坐标矩形),由 main 注入(约定:中央房间中心 400×400)
var arena_rect := Rect2(Vector2.ZERO, Vector2(400, 400))
## 归位点(领地中心)与视觉缩放(32→128px)
var home_pos := Vector2.ZERO
@export var visual_scale := 4.0
@export var idle_bob_amp := 4.0
@export var eye_glow_amp := 0.35

var idle_timer := 0.0
var eye_glow: Sprite2D


func _ready() -> void:
	super._ready()
	_build_visual()
	_setup_big_shadow()
	_setup_ambient_particles()
	hp = max_hp


## 自建视觉:单帧独眼巨人 + 程序生成发光眼珠,"Visual" 节点名兼容 Enemy 逻辑
func _build_visual() -> void:
	var visual := Sprite2D.new()
	visual.name = "Visual"
	visual.texture = CYCLOPS_TEX
	visual.scale = Vector2.ONE * visual_scale
	visual.position = Vector2(0, -visual_scale * 4.0)
	add_child(visual)
	eye_glow = Sprite2D.new()
	eye_glow.name = "EyeGlow"
	eye_glow.texture = _make_glow_texture()
	eye_glow.position = Vector2(0, -visual_scale * 4.0 - visual_scale * 6.0)
	eye_glow.scale = Vector2.ONE * 2.5
	eye_glow.z_index = 1
	add_child(eye_glow)


## 16x16 发光圆点:中心亮边透明,脉动模拟"独眼泛光"
func _make_glow_texture() -> Texture2D:
	var img := Image.create(16, 16, false, Image.FORMAT_RGBA8)
	for y in 16:
		for x in 16:
			var d := Vector2(x - 7.5, y - 7.5).length() / 7.5
			img.set_pixel(x, y, Color(1.0, 0.85, 0.4, clampf(1.0 - d, 0.0, 1.0)))
	return ImageTexture.create_from_image(img)


## 大号阴影(3x)
func _setup_big_shadow() -> void:
	var shadow := get_node_or_null("Shadow") as Sprite2D
	if shadow != null:
		shadow.scale = Vector2.ONE * 3.0


## 常驻暗红粒子:脚下烟雾飘散
func _setup_ambient_particles() -> void:
	var particles := CPUParticles2D.new()
	particles.name = "AmbientParticles"
	particles.amount = 18
	particles.lifetime = 1.6
	particles.local_coords = false
	particles.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	particles.emission_box_extents = Vector2(40, 8)
	particles.direction = Vector2.UP
	particles.spread = 35.0
	particles.initial_velocity_min = 8.0
	particles.initial_velocity_max = 24.0
	particles.gravity = Vector2(0, -30)
	particles.scale_amount_min = 1.2
	particles.scale_amount_max = 2.6
	particles.color = Color(0.45, 0.08, 0.05, 0.5)
	particles.z_index = -1
	add_child(particles)


func _physics_process(delta: float) -> void:
	if dead:
		return
	if hit_flash > 0.0:
		hit_flash -= delta
		modulate = Color(3.0, 1.5, 1.5) if hit_flash > 0.0 else Color.WHITE
	var player := _get_player()
	var in_arena := player != null and not player.dead and arena_rect.has_point(player.global_position)
	if in_arena:
		_chase_within_arena(player)
	else:
		_return_home()
	move_and_slide()
	_try_contact_damage(delta)
	_update_idle_effects(delta)


## 追击:目标点 clamp 领地内 → Boss 永远无法离开中心
func _chase_within_arena(target: Player) -> void:
	var clamped := Vector2(
		clampf(target.global_position.x, arena_rect.position.x, arena_rect.end.x),
		clampf(target.global_position.y, arena_rect.position.y, arena_rect.end.y)
	)
	var to := clamped - global_position
	if to.length() < 8.0:
		velocity = Vector2.ZERO
		return
	velocity = to.normalized() * chase_speed


## 回巢:慢踱回领地中心
func _return_home() -> void:
	var to_home := home_pos - global_position
	if to_home.length() < 8.0:
		velocity = Vector2.ZERO
		return
	velocity = to_home.normalized() * move_speed


## 动态待机:呼吸浮动 + 身体轻摆 + 独眼发光脉动(常驻)
func _update_idle_effects(delta: float) -> void:
	idle_timer += delta
	var visual := get_node_or_null("Visual") as Sprite2D
	if visual == null:
		return
	var moving := velocity.length() > 10.0
	var amp := idle_bob_amp * (0.5 if moving else 1.0)
	var bob_y := sin(idle_timer * 2.2) * amp
	visual.position = Vector2(0, -visual_scale * 4.0 + bob_y)
	visual.rotation = sin(idle_timer * 1.3) * 0.05
	if eye_glow != null:
		var pulse := 0.5 + 0.5 * sin(idle_timer * 3.0)
		eye_glow.modulate.a = 0.5 + eye_glow_amp * pulse
		eye_glow.scale = Vector2.ONE * (2.0 + 1.2 * pulse)
		eye_glow.position = visual.position + Vector2(0, -visual_scale * 6.0)


## override:受击后 emit health_changed(供 HUD 血条)
func take_damage(amount: float, _source: Node = null) -> void:
	super.take_damage(amount, _source)
	health_changed.emit(hp, max_hp)


## Boss 固定掉落 2~3 瓶药
func _roll_drop() -> void:
	drop_requested.emit(global_position + Vector2(-24, 0), ItemData.red_potion())
	drop_requested.emit(global_position + Vector2(24, 0), ItemData.blue_potion())
	if randf() < 0.6:
		drop_requested.emit(global_position + Vector2(0, -24), ItemData.red_potion())


## Boss 死亡:重白闪 + 更大缩放 + 长淡出 + 专属音效
func _die() -> void:
	dead = true
	_roll_drop()
	died.emit(self)
	set_physics_process(false)
	Sfx.play(SoundFactory.boss_die(), -2.0)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color(2.4, 2.4, 2.4), 0.12)
	tween.tween_property(self, "scale", scale * 1.5, 0.25)
	tween.tween_property(self, "modulate:a", 0.0, 0.6)
	tween.tween_callback(queue_free)
