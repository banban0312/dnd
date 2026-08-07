extends Node
class_name DeepSeekClient
## DeepSeek Responses API 客户端(服务端 web_search 联网搜索)。
## 官方文档:https://api-docs.deepseek.com/zh-cn/guides/responses_api/
## API Key 读取顺序:环境变量 DEEPSEEK_API_KEY > user://ai_config.cfg
## 注意:Responses API 目前仅支持 deepseek-v4-flash(deepseek-v4-pro 暂不支持)。

signal response_ready(text: String)
signal search_status(text: String)
signal request_failed(code: int, message: String)

const BASE_URL := "https://api.deepseek.com/responses"
const CONFIG_PATH := "user://ai_config.cfg"
## 保留最近 N 条消息(用户+助手各算 1 条),避免历史过长撑爆上下文
const MAX_HISTORY_ITEMS := 24

var model := "deepseek-v4-flash"
var base_url := BASE_URL
var api_key := ""
var history: Array[Dictionary] = []
var _http: HTTPRequest
var _busy := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_config()


## 读取配置:环境变量优先,其次 user://ai_config.cfg
func _load_config() -> void:
	api_key = OS.get_environment("DEEPSEEK_API_KEY").strip_edges()
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		if api_key.is_empty():
			api_key = str(cfg.get_value("deepseek", "api_key", "")).strip_edges()
		var m := str(cfg.get_value("deepseek", "model", "")).strip_edges()
		if not m.is_empty():
			model = m
		var u := str(cfg.get_value("deepseek", "base_url", "")).strip_edges()
		if not u.is_empty():
			base_url = u


## 把 Key / 模型 / 接口地址保存到 user://ai_config.cfg(仅本机,不进仓库)
func save_config(p_key: String, p_model: String = "", p_base_url: String = "") -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	if not p_key.is_empty():
		api_key = p_key.strip_edges()
		cfg.set_value("deepseek", "api_key", api_key)
	if not p_model.is_empty():
		model = p_model.strip_edges()
		cfg.set_value("deepseek", "model", model)
	if not p_base_url.is_empty():
		base_url = p_base_url.strip_edges()
		cfg.set_value("deepseek", "base_url", base_url)
	cfg.save(CONFIG_PATH)


func has_key() -> bool:
	return not api_key.is_empty()


## 清空对话历史(不改变 Key/模型配置)
func reset_history() -> void:
	history.clear()


## 发送一条用户消息(非流式,带服务端 web_search)。
## 返回 true 表示请求已发出,结果通过 signal 回调。
func ask(text: String) -> bool:
	if _busy:
		return false
	if api_key.is_empty():
		request_failed.emit(0, "未配置 API Key:请设置环境变量 DEEPSEEK_API_KEY,或在聊天面板粘贴 Key")
		return false
	if text.strip_edges().is_empty():
		return false
	history.append(_make_message("user", "input_text", text))
	_trim_history()
	_busy = true
	_ensure_http()
	var body := {
		"model": model,
		"instructions": "你是《Darker and Darker》地牢冒险世界里的冒险向导。回答简洁、清晰,"
				+ "涉及最新信息或无法确定的内容时主动使用联网搜索。",
		"input": history,
		"tools": [{"type": "web_search"}],
	}
	var headers := [
		"Authorization: Bearer %s" % api_key,
		"Content-Type: application/json",
	]
	var err := _http.request(base_url, headers, HTTPClient.METHOD_POST, JSON.stringify(body))
	if err != OK:
		_busy = false
		request_failed.emit(err, "请求发送失败(HTTPRequest 错误码 %d)" % err)
		return false
	return true


func _ensure_http() -> void:
	if _http != null:
		return
	_http = HTTPRequest.new()
	_http.timeout = 60.0
	add_child(_http)
	_http.request_completed.connect(_on_request_completed)


func _make_message(role: String, content_type: String, text: String) -> Dictionary:
	return {
		"type": "message",
		"role": role,
		"content": [{"type": content_type, "text": text}],
	}


func _trim_history() -> void:
	while history.size() > MAX_HISTORY_ITEMS:
		history.pop_front()


func _on_request_completed(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_busy = false
	if result != HTTPRequest.RESULT_SUCCESS:
		request_failed.emit(result, "网络请求失败(HTTP %d, result %d)" % [code, result])
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if json is not Dictionary:
		request_failed.emit(code, "响应解析失败:不是有效 JSON")
		return
	if code >= 400:
		var err_obj: Variant = json.get("error", {})
		var msg := str(err_obj.get("message", "HTTP %d" % code) if err_obj is Dictionary else "HTTP %d" % code)
		request_failed.emit(code, "API 错误(%d): %s" % [code, msg])
		return

	var answer := ""
	var saw_search := false
	var error_msg := ""
	for item in json.get("output", []):
		if item is not Dictionary:
			continue
		match str(item.get("type", "")):
			"web_search_call":
				saw_search = true
				match str(item.get("status", "")):
					"in_progress", "searching":
						search_status.emit("正在联网搜索…")
					"completed":
						search_status.emit("搜索完成,正在整理答案…")
					_:
						search_status.emit("服务端联网搜索中…")
				var cites: Variant = item.get("citations", [])
				if cites is Array and not cites.is_empty():
					var lines: Array[String] = []
					for cite in cites:
						if cite is Dictionary:
							var url := str(cite.get("url", ""))
							var title := str(cite.get("title", ""))
							if not url.is_empty():
								lines.append("- %s: %s" % [title if not title.is_empty() else url, url])
					if not lines.is_empty():
						answer += "\n\n来源:\n" + "\n".join(lines)
			"message":
				if str(item.get("role", "")) != "assistant":
					continue
				var texts: Array[String] = []
				for content in item.get("content", []):
					if content is Dictionary and str(content.get("type", "")) == "output_text":
						texts.append(str(content.get("text", "")))
				if not texts.is_empty():
					answer += "\n".join(texts)
			"error":
				error_msg = str(item.get("message", ""))

	if not error_msg.is_empty():
		request_failed.emit(code, "API 错误: %s" % error_msg)
		return
	answer = answer.strip_edges()
	if answer.is_empty():
		request_failed.emit(code, "模型返回为空,请重试")
		return
	if not saw_search:
		search_status.emit("完成(未触发联网搜索)")
	history.append(_make_message("assistant", "output_text", answer))
	_trim_history()
	response_ready.emit(answer)
