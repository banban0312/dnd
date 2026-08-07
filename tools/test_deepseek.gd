extends SceneTree
## 冒烟测试:直接调用 DeepSeek Responses API(服务端 web_search),打印搜索状态与回答。
## 用法:
##   & "D:\Godot\Godot_v4.7.1-stable_win64_console.exe" --headless --path . --script res://tools/test_deepseek.gd -- "你的问题"
## API Key:环境变量 DEEPSEEK_API_KEY 优先,其次 user://ai_config.cfg

var prompt := "搜索今天最新的 3 条重要 AI 新闻,并标注时间和出处"


func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if not args.is_empty():
		prompt = args[0]
	var client := DeepSeekClient.new()
	client.name = "DeepSeekClient"
	root.add_child(client)
	client.response_ready.connect(func(text: String) -> void:
		print("=== 回答 ===")
		print(text)
		quit(0))
	client.search_status.connect(func(status: String) -> void:
		print("[搜索]", status))
	client.request_failed.connect(func(code: int, message: String) -> void:
		printerr("请求失败(%d): %s" % [code, message])
		quit(1))
	if not client.has_key():
		printerr("未找到 API Key:请设置环境变量 DEEPSEEK_API_KEY,或先运行游戏在聊天面板保存 Key")
		quit(2)
		return
	print("模型: %s | 接口: %s" % [client.model, client.base_url])
	print("问题: %s" % prompt)
	client.ask(prompt)
