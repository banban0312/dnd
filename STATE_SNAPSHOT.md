# Current state

current_phase: v061_local_release_verified_pending_human
updated_at: 2026-10-21 Asia/Hong_Kong
baseline_commit: 7211a3dbc420eb6d0711ebae31054655926fd75d
remote: https://github.com/banban0312/dnd

当前范围：三层、六装备、一个可选井契。第一层四柱守望者；第二层精英升降梯；第三层骷髅法师、规律骨雨/花瓣二次绽放、召唤、两次举杖四秒保护罩判定。新建四套像素模型。0.6.1操作取代旧方案：WASD移动，鼠标瞄准/左键普攻，G/V技能；修复敌我平台速度继承和守望者可见身体漏判。

旧0.4检查点在`_test/checkpoints/pre_05_1792572536`。可分发版本统一`releases/v0.4`、`v0.5`、`v0.6`、`v0.6.1`，manifest记录大小与SHA256。当前验证结论见`docs/PATCH_061_REPORT.md`。

仓库提交源码、测试、必要实机图、版本清单；ZIP/EXE/PCK、导出模板、本机测试日志不提交。提交信息统一`[新增] ...`。原两层80小时计划属于历史，不代表新增功能耗时或真人验收已通过。

历史0.6的12组回归、720p/1080pD3D12采集、PCK及全新解压目录的原生EXE完整流程通过；音乐已加入真实主场景并验证循环/淡化/暂停/静音。

当前补丁以docs/PATCH_061_REPORT.md为最新证据，旧0.6报告保留历史。

0.6.1最终14组回归、PCK、独立ZIP本机原生运行通过，包和SHA256已登记，待朋友复测。
