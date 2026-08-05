class_name AnimFactory
## 统一提供 0x72 DungeonTileset II(CC0)角色的 SpriteFrames。
## 帧资源由 tools/generate_sprite_frames.gd 生成到 assets/sprites/*_frames.tres,
## 场景 AnimatedSprite2D 直接挂载(编辑器可预览),运行时这里统一加载保证一致。

const _FRAMES := {
	"ranger": preload("res://assets/sprites/ranger_frames.tres"),
	"goblin": preload("res://assets/sprites/goblin_frames.tres"),
	"skeleton": preload("res://assets/sprites/skeleton_frames.tres"),
}

## 角色对应显示缩放(与旧占位图视觉大小对齐)。
const VISUAL_SCALE := {
	"ranger": 2.5,
	"goblin": 2.0,
	"skeleton": 2.5,
}


## 获取指定角色的 SpriteFrames(含 idle / run 两个循环动画)。
static func make_frames(character: String) -> SpriteFrames:
	assert(_FRAMES.has(character), "未知角色: " + character)
	return _FRAMES[character]


## 角色显示缩放。
static func visual_scale(character: String) -> float:
	return VISUAL_SCALE[character]
