extends Control
class_name AiChatPanel
## 游戏内 AI 向导聊天面板(DeepSeek Responses API + 服务端 web_search)。
## 按 J 打开/关闭;打开时游戏暂停;Key 可粘贴保存到本机 user://ai_config.cfg。

const C_PANEL := Color(0.055, 0.045, 0.075, 0.97)
const C_GOLD := Color(0.72, 0.55, 0.25)
const C_GOLD_DIM := Color(0.42, 0.31, 0.15)
const C_TEXT := Color(0.9, 0.86, 0.78)
const C_TITLE := Color(0.9, 0.72, 0.38)
const C_USER := Color(0.78, 0.8, 0.92)
const C_ASSISTANT := Color(0.78, 0.9, 0.76)
const C_ERROR := Color(1.0, 0.55, 0.5)

var client: DeepSeekClient

var log_rt: RichTextLabel
var input_edit: LineEdit
var status_label: Label
var key_edit: LineEdit
var model_edit: LineEdit
var send_button: Button
var _open := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_ui()
	visible = false
	if client != null:
		client.response_ready.connect(_on_response)
		client.search_status.connect(_on_search_status)
		client.request_failed.connect(_on_failed)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ai_chat"):
		toggle()
		get_viewport().set_input_as_handled()
	elif event.is_action_pressed("ui_cancel") and _open:
		close()
		get_viewport().set_input_as_handled()


func toggle() -> void:
	if _open:
		close()
	else:
		open()


func open() -> void:
	# Another modal (such as the startup menu) already owns the pause.
	if get_tree().paused:
		return
	_open = true
	visible = true
	get_tree().paused = true
	_refresh_settings()
	input_edit.call_deferred("grab_focus")


func close() -> void:
	if not _open:
		return
	_open = false
	visible = false
	get_tree().paused = false


func _on_send() -> void:
	var text := input_edit.text.strip_edges()
	if text.is_empty():
		return
	_append_line("你", text, C_USER)
	input_edit.text = ""
	if not client.has_key():
		_append_line("向导", "还没有 API Key:请先粘贴 DeepSeek API Key 并点击保存配置。", C_ASSISTANT)
		status_label.text = "未配置 API Key"
		return
	if not client.ask(text):
		status_label.text = "请求未发送"
		return
	send_button.disabled = true
	send_button.text = "思考中…"
	status_label.text = "已提交,等待回复…"


func _on_response(text: String) -> void:
	_append_line("向导", text, C_ASSISTANT)
	_set_idle("完成,可继续提问")


func _on_search_status(status: String) -> void:
	status_label.text = status


func _on_failed(code: int, message: String) -> void:
	_append_line("向导", "出错了:%s" % message, C_ERROR)
	_set_idle("请求失败(错误码 %d)" % code)


func _set_idle(text: String) -> void:
	send_button.disabled = false
	send_button.text = "发送"
	status_label.text = text


func _on_save_settings() -> void:
	client.save_config(key_edit.text.strip_edges(), model_edit.text.strip_edges())
	key_edit.text = ""
	status_label.text = "配置已保存到 user://ai_config.cfg"


func _on_clear_history() -> void:
	client.reset_history()
	log_rt.clear()
	status_label.text = "对话历史已清空"


func _refresh_settings() -> void:
	if client.api_key.is_empty():
		key_edit.placeholder_text = "粘贴 DeepSeek API Key(环境变量优先)…"
		status_label.text = "未配置 API Key"
	else:
		key_edit.placeholder_text = "已配置 Key,留空则保持不变"
		status_label.text = "已连接 DeepSeek(deepseek-v4-flash + 联网搜索)"
	model_edit.text = client.model


func _append_line(who: String, text: String, color: Color) -> void:
	log_rt.push_color(color)
	log_rt.add_text("%s: " % who)
	log_rt.pop()
	log_rt.add_text(text)
	log_rt.newline()
	log_rt.newline()


func _build_ui() -> void:
	var panel := _make_panel(self, Vector2(350, 70), Vector2(580, 590), "冒险向导 · DeepSeek(联网搜索)")
	_make_button(panel, "✕ 关闭", Vector2(494, 7), Vector2(72, 26), close)

	log_rt = RichTextLabel.new()
	log_rt.position = Vector2(14, 40)
	log_rt.size = Vector2(552, 318)
	log_rt.bbcode_enabled = true
	log_rt.scroll_following = true
	log_rt.add_theme_font_size_override("normal_font_size", 14)
	log_rt.add_theme_color_override("default_color", C_TEXT)
	log_rt.add_theme_color_override("selection_color", Color(0.3, 0.25, 0.18, 1.0))
	panel.add_child(log_rt)

	input_edit = LineEdit.new()
	input_edit.position = Vector2(14, 366)
	input_edit.size = Vector2(436, 34)
	input_edit.placeholder_text = "输入问题,回车发送(可联网搜索)…"
	input_edit.add_theme_font_size_override("font_size", 14)
	input_edit.add_theme_stylebox_override("normal", _edit_style())
	input_edit.add_theme_stylebox_override("focus", _edit_style(true))
	input_edit.text_submitted.connect(func(_s: String) -> void: _on_send())
	panel.add_child(input_edit)

	send_button = _make_button(panel, "发送", Vector2(458, 366), Vector2(108, 34), _on_send)

	status_label = _make_label(panel, "", Vector2(14, 408), 12)
	status_label.size = Vector2(420, 20)
	status_label.add_theme_color_override("font_color", C_TITLE)

	_make_button(panel, "清空对话", Vector2(448, 406), Vector2(118, 24), _on_clear_history)

	var sep := ColorRect.new()
	sep.position = Vector2(10, 440)
	sep.size = Vector2(560, 1)
	sep.color = C_GOLD_DIM
	panel.add_child(sep)

	_make_label(panel, "API Key", Vector2(14, 456), 13)
	key_edit = LineEdit.new()
	key_edit.position = Vector2(86, 452)
	key_edit.size = Vector2(340, 28)
	key_edit.secret = true
	key_edit.placeholder_text = "粘贴 DeepSeek API Key(环境变量优先)…"
	key_edit.add_theme_font_size_override("font_size", 13)
	key_edit.add_theme_stylebox_override("normal", _edit_style())
	key_edit.add_theme_stylebox_override("focus", _edit_style(true))
	panel.add_child(key_edit)
	_make_button(panel, "保存配置", Vector2(434, 452), Vector2(132, 28), _on_save_settings)

	_make_label(panel, "模型", Vector2(14, 492), 13)
	model_edit = LineEdit.new()
	model_edit.position = Vector2(86, 488)
	model_edit.size = Vector2(340, 28)
	model_edit.placeholder_text = "deepseek-v4-flash"
	model_edit.add_theme_font_size_override("font_size", 13)
	model_edit.add_theme_stylebox_override("normal", _edit_style())
	model_edit.add_theme_stylebox_override("focus", _edit_style(true))
	panel.add_child(model_edit)

	_make_label(panel, "J 打开/关闭 · 搜索由服务端执行 · Key 仅保存在本机 user://ai_config.cfg",
			Vector2(14, 530), 11)


func _make_panel(parent: Control, pos: Vector2, size: Vector2, title: String) -> Control:
	var panel := Control.new()
	panel.position = pos
	panel.size = size
	parent.add_child(panel)
	var bg := Panel.new()
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.add_theme_stylebox_override("panel", _box_style(C_PANEL))
	panel.add_child(bg)
	var title_label := _make_label(panel, title, Vector2(12, 6), 16)
	title_label.add_theme_color_override("font_color", C_TITLE)
	var line := ColorRect.new()
	line.position = Vector2(10, 26)
	line.size = Vector2(size.x - 20, 1)
	line.color = C_GOLD_DIM
	panel.add_child(line)
	var gem := ColorRect.new()
	gem.position = Vector2(10, 21)
	gem.size = Vector2(5, 5)
	gem.rotation = PI * 0.25
	gem.color = C_GOLD
	panel.add_child(gem)
	return panel


func _make_button(parent: Control, text: String, pos: Vector2, size: Vector2, callback: Callable) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.position = pos
	btn.size = size
	btn.add_theme_stylebox_override("normal", _box_style(Color(0.11, 0.09, 0.11, 0.96)))
	btn.add_theme_stylebox_override("hover", _box_style(Color(0.2, 0.16, 0.12, 1.0)))
	btn.add_theme_stylebox_override("pressed", _box_style(Color(0.26, 0.2, 0.12, 1.0)))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	btn.add_theme_color_override("font_color", C_TEXT)
	btn.add_theme_color_override("font_hover_color", C_TITLE)
	btn.add_theme_font_size_override("font_size", 13)
	btn.pressed.connect(callback)
	parent.add_child(btn)
	return btn


func _make_label(parent: Control, text: String, pos: Vector2, font_size: int) -> Label:
	var label := Label.new()
	label.text = text
	label.position = pos
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", C_TEXT)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.85))
	label.add_theme_constant_override("outline_size", 2)
	parent.add_child(label)
	return label


func _edit_style(focused := false) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.075, 0.1, 0.95) if not focused else Color(0.14, 0.12, 0.13, 1.0)
	sb.border_color = C_GOLD if focused else C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb


func _box_style(bg_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg_color
	sb.border_color = C_GOLD_DIM
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(3)
	return sb
