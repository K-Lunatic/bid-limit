class_name BidSignalingClient
extends Node

signal rooms_received(rooms: Array)
signal hosted(peer_id: int)
signal joined(peer_id: int)
signal signal_received(message: Dictionary)
signal failed(message: String)
signal auth_succeeded(uid: String, username: String)
signal profile_exported(code: String)
signal profile_imported(profile: Dictionary)

var base_url := ""
var room_id := ""
var peer_id := 0
var room_token := ""
var request_kind := ""
var request_http: HTTPRequest
var poll_http: HTTPRequest
var signal_http: HTTPRequest
var poll_timer := 0.0
var signal_queue: Array[Dictionary] = []
var auth_token := ""
var uid := ""

func _ready() -> void:
	base_url = str(ProjectSettings.get_setting("bid_network/signaling_url", ""))
	if base_url.is_empty():
		if OS.has_feature("web"):
			base_url = "%s/api" % str(JavaScriptBridge.eval("window.location.origin"))
		else:
			base_url = "http://127.0.0.1:8787"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--signal-url="):
			base_url = arg.trim_prefix("--signal-url=").trim_suffix("/")
	request_http = HTTPRequest.new()
	poll_http = HTTPRequest.new()
	signal_http = HTTPRequest.new()
	add_child(request_http)
	add_child(poll_http)
	add_child(signal_http)
	request_http.request_completed.connect(handle_request)
	poll_http.request_completed.connect(handle_poll)
	signal_http.request_completed.connect(handle_signal_sent)

func _process(delta: float) -> void:
	if room_id.is_empty() or peer_id == 0:
		return
	poll_timer -= delta
	if poll_timer <= 0.0 and poll_http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		poll_timer = 0.45
		poll_http.request("%s%s" % [base_url, room_path(room_id, "messages", peer_id)], ["x-room-token: %s" % room_token])

func list_rooms() -> void:
	if not _begin_request("list"):
		return
	if request_http.request("%s/rooms" % base_url) != OK:
		request_kind = ""
		failed.emit("중계 서버에 연결하지 못했습니다. AI와 바로 시작할 수 있습니다.")

func room_path(target_room_id: String, action: String, target_peer_id: int = 0) -> String:
	if OS.has_feature("web"):
		var path := "/rooms?room=%s&action=%s" % [target_room_id, action]
		if target_peer_id > 0:
			path += "&peer=%d" % target_peer_id
		return path
	var path := "/rooms/%s/%s" % [target_room_id, action]
	if target_peer_id > 0:
		path += "?peer=%d" % target_peer_id
	return path

func host_room(room_name: String, private_room: bool, password: String) -> void:
	if not _begin_request("host"): return
	request_json("/rooms", {"name": room_name, "private": private_room, "password": password})

func join_room(target_room_id: String, password: String) -> void:
	if not _begin_request("join"): return
	request_json(room_path(target_room_id, "join"), {"password": password})

func register_account(username: String, password: String) -> void:
	if not _begin_request("register"): return
	request_json("/auth/register", {"username": username, "password": password})

func login_account(username: String, password: String) -> void:
	if not _begin_request("login"): return
	request_json("/auth/login", {"username": username, "password": password})

func export_profile(profile: Dictionary) -> void:
	if not _begin_request("profile_export"): return
	request_json("/profiles/export", {"profile": profile})

func import_profile(code: String) -> void:
	if not _begin_request("profile_import"): return
	request_json("/profiles/import", {"code": code})

func send_signal(target_peer_id: int, message: Dictionary) -> void:
	if room_id.is_empty() or target_peer_id == peer_id:
		return
	signal_queue.append({"to": target_peer_id, "message": message})
	pump_signal_queue()

func pump_signal_queue() -> void:
	if signal_queue.is_empty() or signal_http.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	var payload: Dictionary = signal_queue.front()
	var error := signal_http.request("%s%s" % [base_url, room_path(room_id, "signal", peer_id)], ["Content-Type: application/json", "x-room-token: %s" % room_token], HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		signal_queue.pop_front()
		failed.emit("연결 신호를 전달하지 못했습니다.")

func handle_signal_sent(_result: int, _response_code: int, _headers: PackedStringArray, _body: PackedByteArray) -> void:
	if not signal_queue.is_empty():
		signal_queue.pop_front()
	pump_signal_queue()

func request_json(path: String, payload: Dictionary, extra_headers: PackedStringArray = PackedStringArray()) -> void:
	var headers := PackedStringArray(["Content-Type: application/json"])
	if not auth_token.is_empty():
		headers.append("Authorization: Bearer %s" % auth_token)
	for header in extra_headers:
		headers.append(header)
	var error := request_http.request("%s%s" % [base_url, path], headers, HTTPClient.METHOD_POST, JSON.stringify(payload))
	if error != OK:
		request_kind = ""
		failed.emit("중계 서버에 연결하지 못했습니다.")

func _begin_request(kind: String) -> bool:
	if not request_kind.is_empty():
		failed.emit("이전 요청을 처리하고 있습니다. 잠시 후 다시 시도해 주세요.")
		return false
	request_kind = kind
	return true

func handle_request(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var completed_kind := request_kind
	request_kind = ""
	if result != HTTPRequest.RESULT_SUCCESS:
		failed.emit("중계 서버에 연결하지 못했습니다. AI와 바로 시작할 수 있습니다.")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if response_code < 200 or response_code >= 300 or not data is Dictionary:
		failed.emit(data.get("error", "중계 서버 요청이 실패했습니다.") if data is Dictionary else "중계 서버 요청이 실패했습니다.")
		return
	if completed_kind == "list":
		rooms_received.emit(data.get("rooms", []))
	elif completed_kind == "register" or completed_kind == "login":
		auth_token = str(data.get("token", ""))
		uid = str(data.get("uid", ""))
		auth_succeeded.emit(uid, str(data.get("username", "")))
	elif completed_kind == "profile_export":
		profile_exported.emit(str(data.get("code", "")))
	elif completed_kind == "profile_import":
		profile_imported.emit(data.get("profile", {}))
	elif completed_kind == "host" or completed_kind == "join":
		room_id = data.get("room", {}).get("id", "")
		peer_id = int(data.get("peerId", 0))
		room_token = data.get("token", "")
		if peer_id == 0 or room_id.is_empty():
			failed.emit("방 정보를 받지 못했습니다.")
		elif completed_kind == "host":
			hosted.emit(peer_id)
		else:
			joined.emit(peer_id)

func handle_poll(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if not data is Dictionary:
		return
	for message in data.get("messages", []):
		if message is Dictionary:
			signal_received.emit(message)
