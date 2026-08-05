# 素材来源与许可 (Asset Sources & License)

本项目当前使用的像素美术素材全部为 **CC0 (Public Domain)** 授权,可自由用于商业项目,署名非强制。

## 1. Dungeon Crawl 32x32 tiles (主素材)

- 来源: Dungeon Crawl Stone Soup 官方瓦片集
- 页面: https://opengameart.org/content/dungeon-crawl-32x32-tiles
- 授权: CC0 — 可商用,无需署名(署名作为致谢)
- 本地副本: `assets/crawl-tiles/` (原始压缩包 `assets/crawl-tiles.zip`)

使用的瓦片:

| 游戏对象 | 使用文件 |
| --- | --- |
| 箭矢 | `sprites/arrow.png` (effect/arrow2.png) |
| 红色药水 | `sprites/potion_red.png` (item/potion/i-heal.png) |
| 蓝色药水 | `sprites/potion_blue.png` (item/potion/i-magic.png) |
| 宝箱(关/开) | `sprites/chest_closed.png` / `sprites/chest_open.png` |
| 存档点(蓝喷泉) | `sprites/save_point.png` (dc-dngn/dngn_blue_fountain.png) |
| 墙壁 | `sprites/wall.png` (dc-dngn/wall/stone_gray0.png) |
| 地面(石板) | `sprites/floor.png` (dc-dngn/floor/rect_gray0.png) |
| 石柱 | `sprites/pillar.png` (dc-dngn/crumbled_column.png) |
| 角色阴影 | `sprites/shadow.png`(程序生成的椭圆渐变阴影,本项目自制) |

## 2. Kenney Roguelike/RPG pack (备用/环境扩展)

- 来源: https://opengameart.org/content/roguelikerpg-pack-1700-tiles
- 作者: Kenney (www.kenney.nl),16x16 转换 by Lynn Evers
- 授权: CC0 — 可商用,署名非强制
- 本地副本: `assets/roguelike/` (原始压缩包 `assets/Roguelike pack.zip`)

该包含 16x16 地板/墙/家具/UI 等 1700+ 瓦片,供后续箱庭关卡设计使用。

## 3. 0x72 16x16 DungeonTileset II v1.7 (角色动画主素材)

- 来源: 0x72 (Robert Norenberg) 官方 itch.io 页面
- 页面: https://0x72.itch.io/dungeontileset-ii
- 授权: **CC-0** — 官方页面原文 "You can use this tileset for whatever you like (CC-0)",可商用、无需署名
- 本地副本: `assets/dungeontileset2/` (完整 512×512 瓦片图 + 官方 `tile_list_v1.7.txt` + README)

使用的角色动画帧(按官方 tile_list 从瓦片图裁剪为横向条带):

| 游戏对象 | 使用文件 | 官方帧名 |
| --- | --- | --- |
| 玩家(游侠 = 精灵弓箭手 elf_m) | `sprites/player_ranger_idle.png` / `player_ranger_run.png` | `elf_m_idle_anim_f0..f3` / `elf_m_run_anim_f0..f3` |
| 哥布林 | `sprites/goblin_idle.png` / `sprites/goblin_run.png` | `goblin_idle_anim_f0..f3` / `goblin_run_anim_f0..f3` |
| 骷髅怪 | `sprites/skeleton_idle.png` / `skeleton_run.png` | `skelet_idle_anim_f0..f3` / `skelet_run_anim_f0..f3` |

条带均为 4 帧横排:玩家帧 16×28,哥布林/骷髅帧 16×16。由 `tools/generate_sprite_frames.gd` 生成 `sprites/*_frames.tres`(SpriteFrames 资源),场景 AnimatedSprite2D 直接挂载。

## 备注

- 后续替换/新增素材时,请保持 CC0 或至少可商用许可(如 CC-BY),并在此处登记来源。
