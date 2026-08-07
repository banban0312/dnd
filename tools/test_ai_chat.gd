extends SceneTree
## 冒烟测试:单独实例化 AI 聊天面板,验证打开/关闭(暂停恢复)、无 Key 错误提示。
## 注意:--script 模式不加载 Autoload,无法实例化 main.tscn;整场景接线由 --quit-after 冒烟测试覆盖。
## 用法:godot --headless --path . --script res://tools/test_ai_chat.gd


func _initialize() -> void:
	_run()


func _run() -> void:
	await process_frame
	if not InputMap.has_action("ai_chat"):
		printerr("FAIL: 缺少 ai_chat 输入映射")
		quit(1)
		return
	var client := DeepSeekClient.new()
	client.name = "DeepSeekClient"
	root.add_child(client)
	var panel := AiChatPanel.new()
	panel.client = client
	root.add_child(panel)
	if client.has_key():
		printerr("本机已配置 Key,此测试只验证无 Key 流程;请临时清空环境变量 DEEPSEEK_API_KEY 后重试")
		quit(3)
		return

	panel.open()
	if not panel.visible or not paused:
		printerr("FAIL: 打开面板后应可见且游戏暂停")
		quit(1)
		return

	panel.input_edit.text = "你好,介绍一下这个地牢"
	panel._on_send()
	await process_frame
	var log_text := panel.log_rt.get_parsed_text()
	if not log_text.contains("还没有 API Key"):
		printerr("FAIL: 无 Key 时应给出提示,实际日志:\n%s" % log_text)
		quit(1)
		return

	panel.close()
	if panel.visible or paused:
		printerr("FAIL: 关闭面板后应隐藏并恢复游戏")
		quit(1)
		return
	print("AI chat smoke OK")
	quit(0)
