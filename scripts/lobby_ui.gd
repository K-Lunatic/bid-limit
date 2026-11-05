class_name BidLobbyUI
extends CanvasLayer

signal started
signal leave_requested

var client: Node
var network: Node
var panel: Control
var content: VBoxContainer
var rooms_box: VBoxContainer
var room_password: LineEdit
var profile := {"sock": "e15a67", "hair": "35a7d7", "hair_style": 0, "accessory": 0, "nickname": "양말", "weapon": 0}
var notice := ""
var back_button: Button
var back_action: Callable
var error_label: Label
var room_roster: Label
var fill_ai := true
var title_art: Control
var title_mode := false
var title_menu: VBoxContainer

func setup(signaling: Node, session: Node) -> void:
	var saved := ConfigFile.new()
	if saved.load("user://bid_profile.cfg") == OK:
		for key in profile:
			profile[key] = saved.get_value("profile", key, profile[key])
	client = signaling
	network = session
	network.room_started.connect(func() -> void:
		started.emit()
		queue_free())
	network.snapshot_received.connect(_refresh_room_roster)
	network.network_error.connect(func(message: String) -> void:
		error_label.text = message
		error_label.show())
	client.connect("rooms_received", show_rooms)
	client.connect("hosted", func(_peer_id: int) -> void: start_host())
	client.connect("joined", func(peer_id: int) -> void: start_join(peer_id))
	client.connect("failed", func(message: String) -> void:
		notice = message
		if error_label != null:
			error_label.text = message
			error_label.visible = true)
	client.connect("auth_succeeded", func(account_uid: String, username: String) -> void:
		profile["uid"] = account_uid
		notice = "%s 로그인 완료 · UID %s" % [username, account_uid.left(8)]
		show_customization()
	)
	client.connect("profile_exported", func(code: String) -> void:
		notice = "이동 코드가 생성되었습니다. 복사해 보관하세요.\n%s" % code
		show_customization()
	)
	client.connect("profile_imported", func(imported: Dictionary) -> void:
		profile = imported
		notice = "프로필을 불러왔습니다."
		show_customization()
	)
	build()
	client.call("list_rooms")

func build() -> void:
	if not has_node("Panel"):
		var shell: CanvasLayer = load("res://scenes/title_ui.tscn").instantiate()
		var shell_panel: Control = shell.get_node("Panel")
		shell.remove_child(shell_panel)
		add_child(shell_panel)
		shell.free()
	panel = $Panel
	title_art = $Panel/TitleArt
	title_menu = $Panel/TitleMenu
	back_button = $Panel/Back
	error_label = $Panel/Error
	back_button.pressed.connect(func() -> void:
		if back_action.is_valid(): back_action.call())
	title_menu.get_node("RoomActions/FindRoom").pressed.connect(show_room_finder)
	title_menu.get_node("RoomActions/CreateRoom").pressed.connect(show_create_room)
	title_menu.get_node("Customize").pressed.connect(show_customization)
	title_menu.get_node("Solo").pressed.connect(start_host)
	title_menu.get_node("HowToPlay").pressed.connect(show_how_to_play)
	var nickname := title_menu.get_node("Identity/Nickname") as LineEdit
	nickname.text_changed.connect(func(value: String) -> void:
		profile["nickname"] = value.strip_edges()
		_save_profile())
	nickname.focus_exited.connect(func() -> void:
		profile["nickname"] = nickname.text.strip_edges()
		_save_profile())
	show_title()

func _new_content(title_text: String) -> VBoxContainer:
	title_mode = title_text == "BID!  LIMIT"
	title_art.visible = title_mode
	error_label.visible = false
	back_button.visible = title_text != "BID!  LIMIT"
	back_action = show_customization if title_text == "계정 · 프로필 코드" else show_title
	title_menu.hide()
	if content != title_menu and content != null and is_instance_valid(content):
		panel.remove_child(content)
		content.queue_free()
	content = VBoxContainer.new()
	content.custom_minimum_size = Vector2(230, 0)
	content.add_theme_constant_override("separation", 3)
	panel.add_child(content)
	content.set_anchors_preset(Control.PRESET_CENTER_TOP)
	content.offset_left = -115
	content.offset_right = 115
	content.offset_top = 4
	content.offset_bottom = 4
	if title_mode:
		content.custom_minimum_size.x = 140
		content.offset_left = 5
		content.offset_right = 145
		content.offset_top = 12
	var title := Label.new()
	title.text = title_text
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 15)
	content.add_child(title)
	return content

func _button(text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(140 if title_mode else 230, 16)
	button.add_theme_font_size_override("font_size", 9)
	button.pressed.connect(action)
	content.add_child(button)

func _back_button() -> void:
	pass

func _notice() -> void:
	if notice.is_empty():
		return
	var label := Label.new()
	label.text = notice
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 9)
	content.add_child(label)

func show_title() -> void:
	notice = ""
	if content != title_menu and content != null and is_instance_valid(content):
		panel.remove_child(content)
		content.queue_free()
	content = title_menu
	title_mode = true
	title_menu.show()
	title_art.show()
	back_button.hide()
	error_label.hide()
	title_menu.get_node("Identity/Nickname").text = str(profile.get("nickname","양말"))

func show_how_to_play() -> void:
	_new_content("분실물 극장 안내")
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(230,132)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(scroll)
	var guide := Label.new()
	guide.custom_minimum_size.x = 216
	guide.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	guide.text = "세탁소가 문을 닫으면, 짝을 잃은 양말들이 분실물 극장을 열어요. 작은 단추도 이곳에서는 보물!\n\n팔이 없는 인형들은 수선 장갑이 만든 행동표로 입찰하고, 감정하고, 서로를 방해해요. 보풀은 돈, 실밥은 표를 움직이는 힘이에요.\n\n① 첫 준비 60초 동안 상점 방문·덱 편성\n   빈 좌석을 눌러 모두 착석하면 일찍 시작\n② 공개 힌트와 나만의 힌트로 가치 추측\n③ 내 차례 25초 안에 카드를 모아 제출\n④ 입찰에는 입찰표가 필요해요\n⑤ 봉쇄당하면 방어·공격 1장으로 해제 후 차례 종료, 또는 넘김\n⑥ 감정소에서 사이클당 물품 1개 판매\n⑦ 단추상점에서는 70보풀 결제 후 3장 중 1장 선택\n\n다섯 물품 거래 후 현금 + 물품 감정가 − 빚이 가장 높으면 오늘의 장사왕!\n\nA/D 이동 · 스페이스 점프\n1~5 카드 선택 · Enter 제출/채팅\n모바일: 바닥 터치 이동 · 카드 끌어 모으기"
	guide.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide.add_theme_font_size_override("font_size",8)
	scroll.add_child(guide)

func show_room_finder() -> void:
	_new_content("방 찾기")
	_button("새로고침", func() -> void: client.call("list_rooms"))
	var room_scroll := ScrollContainer.new()
	room_scroll.custom_minimum_size = Vector2(230, 36)
	room_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(room_scroll)
	rooms_box = VBoxContainer.new()
	rooms_box.custom_minimum_size = Vector2(225, 0)
	rooms_box.add_theme_constant_override("separation", 3)
	room_scroll.add_child(rooms_box)
	var code := LineEdit.new()
	code.placeholder_text = "비밀방 코드"
	code.add_theme_font_size_override("font_size", 9)
	content.add_child(code)
	room_password = LineEdit.new()
	room_password.placeholder_text = "비밀번호"
	room_password.secret = true
	room_password.add_theme_font_size_override("font_size", 9)
	content.add_child(room_password)
	_button("코드로 입장", func() -> void: client.call("join_room", code.text.strip_edges().to_upper(), room_password.text))
	_back_button()
	_notice()
	client.call("list_rooms")

func show_create_room() -> void:
	_new_content("방 만들기")
	var name := LineEdit.new()
	name.placeholder_text = "방 이름"
	name.text = "보풀 경매장"
	name.add_theme_font_size_override("font_size", 9)
	content.add_child(name)
	var private_box := CheckBox.new()
	private_box.text = "비밀방으로 만들기"
	private_box.add_theme_font_size_override("font_size", 9)
	content.add_child(private_box)
	var password := LineEdit.new()
	password.placeholder_text = "비밀번호 (4자 이상)"
	password.secret = true
	password.add_theme_font_size_override("font_size", 9)
	content.add_child(password)
	_button("방 생성", func() -> void: client.call("host_room", name.text, private_box.button_pressed, password.text))
	_back_button()
	_notice()

func show_customization() -> void:
	_new_content("커스터마이징")
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 5)
	content.add_child(row)
	var preview := SubViewportContainer.new()
	preview.custom_minimum_size = Vector2(90, 112)
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.stretch = true
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(preview)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(90, 112)
	viewport.transparent_bg = true
	viewport.canvas_item_default_texture_filter = Viewport.DEFAULT_CANVAS_ITEM_TEXTURE_FILTER_NEAREST
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	preview.add_child(viewport)
	var puppet: Node2D = preload("res://scripts/sock_puppet_2d.gd").new()
	puppet.call("setup", "", Color.html("#" + str(profile.get("sock", "e15a67"))), Color.html("#" + str(profile.get("hair", "35a7d7"))), false, 0, int(profile.get("hair_style", 0)), int(profile.get("accessory", 0)))
	viewport.add_child(puppet)
	puppet.position = Vector2(90, 165)
	puppet.scale = Vector2(0.64, 0.64)
	var preview_camera := Camera2D.new()
	preview_camera.position = Vector2(90, 117)
	preview_camera.zoom = Vector2.ONE
	viewport.add_child(preview_camera)
	var options := VBoxContainer.new()
	options.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	options.add_theme_constant_override("separation", 2)
	row.add_child(options)
	for option in ["양말 색상", "머리 색상", "머리 모양", "장식"]:
		var button := Button.new()
		button.text = option + " 변경"
		if option == "머리 모양": button.text = preload("res://scripts/sock_puppet_parts_2d.gd").HAIR_NAMES[posmod(int(profile.get("hair_style",0)),3)] + " ↻"
		button.add_theme_font_size_override("font_size", 8)
		button.pressed.connect(func() -> void:
			match option:
				"양말 색상": profile["sock"] = _next_choice(str(profile.get("sock", "e15a67")), ["e15a67", "5f9ed1", "9a6ac0"])
				"머리 색상": profile["hair"] = _next_choice(str(profile.get("hair", "35a7d7")), ["35a7d7", "e4ad5d", "ae78c8"])
				"머리 모양": profile["hair_style"] = (int(profile.get("hair_style", 0)) + 1) % 3
				"장식": profile["accessory"] = (int(profile.get("accessory", 0)) + 1) % 4
			_save_profile()
			show_customization())
		options.add_child(button)
	_button("계정 · 프로필 코드", show_account)
	_back_button()
	_notice()

func _next_choice(current: String, choices: Array) -> String:
	return str(choices[(choices.find(current) + 1) % choices.size()])

func _save_profile() -> void:
	var saved := ConfigFile.new()
	for key in ["sock", "hair", "hair_style", "accessory", "nickname", "weapon"]:
		saved.set_value("profile", key, profile.get(key))
	saved.save("user://bid_profile.cfg")

func show_account() -> void:
	_new_content("계정 · 프로필 코드")
	var username := LineEdit.new()
	username.placeholder_text = "아이디 (3~24자)"
	content.add_child(username)
	var account_password := LineEdit.new()
	account_password.placeholder_text = "비밀번호 (8자 이상)"
	account_password.secret = true
	content.add_child(account_password)
	_button("회원가입", func() -> void: client.call("register_account", username.text.strip_edges(), account_password.text))
	_button("로그인", func() -> void: client.call("login_account", username.text.strip_edges(), account_password.text))
	var transfer_code := LineEdit.new()
	transfer_code.placeholder_text = "프로필 이동 코드"
	content.add_child(transfer_code)
	_button("프로필 내보내기", func() -> void: client.call("export_profile", profile))
	_button("프로필 가져오기", func() -> void: client.call("import_profile", transfer_code.text.strip_edges()))
	_notice()

func show_rooms(rooms: Array) -> void:
	if rooms_box == null or not is_instance_valid(rooms_box):
		return
	for child in rooms_box.get_children():
		child.free()
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = "열린 방이 없습니다."
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rooms_box.add_child(empty)
		return
	for room in rooms:
		var row := Button.new()
		var lock_mark := "[잠김]" if bool(room.get("private", false)) else "[공개]"
		row.text = "%s %s  (%d/%d)" % [lock_mark, room.get("name", "BID! 방"), room.get("players", 0), room.get("maxPlayers", 4)]
		row.add_theme_font_size_override("font_size", 9)
		row.pressed.connect(func() -> void: client.call("join_room", room.get("id", ""), room_password.text))
		rooms_box.add_child(row)

func show_connection_lost(message: String) -> void:
	_new_content("연결 종료")
	notice = message
	_notice()
	_button("나가기",func() -> void: leave_requested.emit())

func start_host() -> void:
	network.call("set_local_profile", profile)
	if network.call("create_host") == OK:
		show_room_lobby()
	else:
		notice = "P2P 초기화에 실패했습니다."
		show_title()

func start_join(peer_id: int) -> void:
	network.call("set_local_profile", profile)
	if network.call("join_mesh", peer_id) == OK:
		show_room_lobby()
	else:
		notice = "P2P 연결을 준비하지 못했습니다."
		show_title()

func show_room_lobby() -> void:
	_new_content("대기실")
	back_button.visible = false
	room_roster = Label.new()
	room_roster.add_theme_font_size_override("font_size", 9)
	content.add_child(room_roster)
	if network.call("is_host"):
		var ai_option := CheckBox.new()
		ai_option.text = "시작할 때 빈자리를 AI로 채우기"
		ai_option.button_pressed = fill_ai
		ai_option.add_theme_font_size_override("font_size", 8)
		ai_option.toggled.connect(func(value: bool) -> void: fill_ai = value)
		content.add_child(ai_option)
		_button("게임 시작", func() -> void:
			network.call("start_room", fill_ai))
	else:
		var waiting := Label.new()
		waiting.text = "방장이 시작하기를 기다리는 중…"
		waiting.add_theme_font_size_override("font_size", 8)
		content.add_child(waiting)
	_button("방 나가기", func() -> void: leave_requested.emit())
	_refresh_room_roster(network.call("serialize_snapshot"))

func _refresh_room_roster(snapshot: Dictionary) -> void:
	if not is_instance_valid(room_roster):
		return
	var roster: Dictionary = snapshot.get("players", {})
	var lines: Array[String] = []
	for id in roster:
		var member: Dictionary = roster[id]
		lines.append("%s%s" % [str(member.get("profile", {}).get("nickname", "참가자")), " · 방장" if int(id) == 1 else ""])
	var connected := int(snapshot.get("connected_count", 0))
	var connection_line := "연결 준비 중" if connected <= 0 else "연결 %d/%d" % [connected, roster.size()]
	room_roster.text = "방 코드: %s · 참가 %d/4 · %s\n%s" % [str(client.get("room_id")), roster.size(), connection_line, "\n".join(lines)]
