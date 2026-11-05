class_name BidAuctionUI
extends CanvasLayer

const CardFanScript = preload("res://scripts/card_fan_ui.gd")
const CardFace = preload("res://scripts/card_face_ui.gd")
const DeckBuilderScript = preload("res://scripts/deck_builder_ui.gd")

signal defense_requested
signal travel_requested(destination: float)
signal jump_requested
signal return_to_title_requested
signal chat_requested(message: String)
signal market_requested(card_id: String)
signal voice_requested
signal voice_gain_requested(delta: float)
signal voice_peer_mute_requested(peer_id: int)
signal voice_peer_volume_requested(peer_id: int, delta: float)
signal vote_kick_requested(peer_id: int)

var game: Node
var lot_label := Label.new()
var detail_label := Label.new()
var status_label := Label.new()
var cash_label := Label.new()
var leader_label := Label.new()
var selected_indices: Array[int] = []
var staged_hand := ""
var submit_button: Button
var clear_button: Button
var card_fan: Control
var guide_label := Label.new()
var return_button: Button
var sell_button: Button
var sale_previous: Button
var sale_next: Button
var sale_label := Label.new()
var sale_index := 0
var appraisal_near := false
var chat_input := LineEdit.new()
var chat_composer: HBoxContainer
var info_panel: PanelContainer
var details_open := false
var exploration_controls: HBoxContainer
var fold_button: Button
var pass_button: Button
var voice_button: Button
var voice_settings_button: Button
var voice_panel: ColorRect
var voice_rows: VBoxContainer
var voice_peer_signature := ""
var market_panel: VBoxContainer
var market_background: ColorRect
var market_notice := Label.new()
var market_near := false
var market_open := false
var market_products: Array[Button] = []
var market_selection := -1
var market_offer_signature := ""
const MARKET_REVEAL_DURATION := 0.75
var market_reveal_elapsed := MARKET_REVEAL_DURATION
var market_reveal_sparks: Array[int] = []
var market_description: Label
var market_buy: Button
var market_button: Button
var played_panel: VBoxContainer
var played_background: ColorRect
var played_title := Label.new()
var played_names := Label.new()
var played_icons := HBoxContainer.new()
var played_sequence := -1
var played_remaining := 0.0
const PLAYED_DISPLAY_SECONDS := 2.5
var result_panel: PanelContainer
var result_grid: GridContainer
var result_signature := ""
var deck_builder: PanelContainer

func setup(session: Node) -> void:
	game = session
	game.connect("changed", render_state)
	build_panel()
	render_state(game.call("state"))

func build_panel() -> void:
	var panel := PanelContainer.new()
	info_panel = panel
	panel.position = Vector2(4, 4)
	panel.size = Vector2(112, 30)
	panel.custom_minimum_size = Vector2(112, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.055, 0.09, 0.82)
	style.border_color = Color("d3a35c")
	style.set_border_width_all(1)
	style.corner_radius_top_left = 3
	style.corner_radius_bottom_right = 3
	style.content_margin_left = 3
	style.content_margin_right = 3
	style.content_margin_top = 2
	style.content_margin_bottom = 2
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	var rows := VBoxContainer.new()
	rows.add_theme_constant_override("separation", 1)
	panel.add_child(rows)
	for label in [lot_label, detail_label, status_label, cash_label]:
		label.clip_text = true
		label.add_theme_font_size_override("font_size", 6)
		rows.add_child(label)
	detail_label.visible = false
	var detail_toggle := Button.new()
	detail_toggle.text = "정보"
	detail_toggle.position = Vector2(4, 36)
	detail_toggle.add_theme_font_size_override("font_size", 6)
	detail_toggle.pressed.connect(func() -> void:
		details_open = not details_open
		detail_label.visible = details_open
		info_panel.reset_size())
	add_child(detail_toggle)
	rows.custom_minimum_size = Vector2(106, 0)
	var controls := HBoxContainer.new()
	exploration_controls = controls
	controls.position = Vector2(90, 161)
	controls.size = Vector2(130, 16)
	controls.add_theme_constant_override("separation", 2)
	add_child(controls)
	_add_action_button(controls, "← 감정소", func() -> void: travel_requested.emit(520.0))
	_add_action_button(controls, "단추상점 →", func() -> void: travel_requested.emit(2580.0))
	_add_action_button(controls, "점프", func() -> void: jump_requested.emit())
	fold_button = Button.new()
	fold_button.position = Vector2(179, 4)
	fold_button.size = Vector2(48, 14)
	fold_button.text = "포기 (P)"
	fold_button.add_theme_font_size_override("font_size", 7)
	fold_button.pressed.connect(func() -> void: game.call("request_fold"))
	add_child(fold_button)
	pass_button = Button.new()
	pass_button.position = Vector2(229, 4)
	pass_button.size = Vector2(48, 14)
	pass_button.text = "넘김 (T)"
	pass_button.add_theme_font_size_override("font_size", 7)
	pass_button.pressed.connect(func() -> void: game.call("request_pass"))
	add_child(pass_button)
	guide_label.position = Vector2(140, 4)
	guide_label.size = Vector2(136, 20)
	guide_label.add_theme_font_size_override("font_size", 6)
	guide_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	guide_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(guide_label)
	leader_label.position = Vector2(4, 52)
	leader_label.size = Vector2(180, 14)
	leader_label.add_theme_font_size_override("font_size", 7)
	leader_label.add_theme_color_override("font_color", Color("ffe09a"))
	leader_label.add_theme_color_override("font_shadow_color", Color("1d1625"))
	leader_label.add_theme_constant_override("shadow_offset_x", 1)
	leader_label.add_theme_constant_override("shadow_offset_y", 1)
	leader_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(leader_label)
	return_button = Button.new()
	return_button.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	return_button.offset_left = -39
	return_button.offset_right = -4
	return_button.offset_top = 4
	return_button.offset_bottom = 20
	return_button.text = "나가기"
	return_button.add_theme_font_size_override("font_size", 7)
	return_button.visible = true
	return_button.pressed.connect(func() -> void: return_to_title_requested.emit())
	add_child(return_button)
	sell_button = Button.new()
	sell_button.position = Vector2(163, 70)
	sell_button.size = Vector2(94, 16)
	sell_button.add_theme_font_size_override("font_size", 7)
	sell_button.visible = false
	sell_button.pressed.connect(func() -> void: game.call("request_sell", sale_index))
	add_child(sell_button)
	sale_previous = Button.new()
	sale_previous.position = Vector2(137, 70)
	sale_previous.size = Vector2(23, 16)
	sale_previous.text = "<"
	sale_previous.pressed.connect(func() -> void: shift_sale_selection(-1))
	add_child(sale_previous)
	sale_next = Button.new()
	sale_next.position = Vector2(260, 70)
	sale_next.size = Vector2(23, 16)
	sale_next.text = ">"
	sale_next.pressed.connect(func() -> void: shift_sale_selection(1))
	add_child(sale_next)
	sale_label.position = Vector2(137, 92)
	sale_label.size = Vector2(175, 22)
	sale_label.add_theme_font_size_override("font_size", 7)
	sale_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sale_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(sale_label)
	card_fan = CardFanScript.new()
	card_fan.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	card_fan.card_dropped.connect(play_dropped_card)
	add_child(card_fan)
	submit_button = Button.new()
	submit_button.position = Vector2(214,112)
	submit_button.add_theme_font_size_override("font_size",7)
	submit_button.pressed.connect(submit_selected)
	add_child(submit_button)
	clear_button = Button.new()
	clear_button.position = Vector2(214,132)
	clear_button.text = "모두 회수"
	clear_button.add_theme_font_size_override("font_size",7)
	clear_button.pressed.connect(func() -> void:
		selected_indices.clear()
		render_state(game.call("state")))
	add_child(clear_button)
	deck_builder = DeckBuilderScript.new()
	add_child(deck_builder)
	deck_builder.call("setup",game)
	var deck_button := Button.new()
	deck_button.text = "덱"
	deck_button.position = Vector2(288,161)
	deck_button.size = Vector2(28,16)
	deck_button.add_theme_font_size_override("font_size",7)
	deck_button.pressed.connect(func() -> void: deck_builder.call("toggle"))
	add_child(deck_button)
	var chat := HBoxContainer.new()
	chat_composer = chat
	chat.visible = false
	chat.z_index = 30
	chat.position = Vector2(4, 140)
	chat.add_theme_constant_override("separation", 1)
	add_child(chat)
	chat_input.placeholder_text = "대화..."
	chat_input.max_length = 40
	chat_input.custom_minimum_size = Vector2(67, 16)
	chat_input.add_theme_font_size_override("font_size", 7)
	chat.add_child(chat_input)
	chat_input.text_submitted.connect(_send_chat)
	_add_action_button(chat, "전송", func() -> void: _send_chat(chat_input.text))
	var communication := HBoxContainer.new()
	communication.position = Vector2(4, 161)
	communication.add_theme_constant_override("separation", 1)
	add_child(communication)
	_add_action_button(communication, "말하기", open_chat)
	voice_button = Button.new()
	voice_button.text = "MIC"
	voice_button.custom_minimum_size = Vector2(28, 16)
	voice_button.add_theme_font_size_override("font_size", 6)
	voice_button.pressed.connect(func() -> void: voice_requested.emit())
	communication.add_child(voice_button)
	voice_settings_button = Button.new()
	voice_settings_button.text = "음성"
	voice_settings_button.custom_minimum_size = Vector2(28, 16)
	voice_settings_button.add_theme_font_size_override("font_size", 6)
	voice_settings_button.pressed.connect(func() -> void: voice_panel.visible = not voice_panel.visible)
	communication.add_child(voice_settings_button)
	voice_panel = ColorRect.new()
	voice_panel.position = Vector2(183, 113)
	voice_panel.size = Vector2(133, 62)
	voice_panel.color = Color(0.04, 0.035, 0.09, 0.96)
	voice_panel.visible = false
	voice_panel.z_index = 20
	add_child(voice_panel)
	voice_rows = VBoxContainer.new()
	voice_rows.position = Vector2(3, 3)
	voice_rows.add_theme_constant_override("separation", 1)
	voice_panel.add_child(voice_rows)
	var mic_row := HBoxContainer.new()
	mic_row.name = "MicGainRow"
	voice_rows.add_child(mic_row)
	var mic_label := Label.new()
	mic_label.name = "MicGainLabel"
	mic_label.text = "내 감도 100%"
	mic_label.custom_minimum_size = Vector2(70, 14)
	mic_label.add_theme_font_size_override("font_size", 6)
	mic_row.add_child(mic_label)
	_add_action_button(mic_row, "-", func() -> void: voice_gain_requested.emit(-0.1))
	_add_action_button(mic_row, "+", func() -> void: voice_gain_requested.emit(0.1))
	market_background = ColorRect.new()
	market_background.position = Vector2(134, 62)
	market_background.size = Vector2(180, 77)
	market_background.color = Color(0.04, 0.035, 0.09, 0.91)
	market_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	market_background.visible = false
	add_child(market_background)
	market_panel = VBoxContainer.new()
	market_panel.position = Vector2(137, 65)
	market_panel.add_theme_constant_override("separation", 1)
	market_panel.visible = false
	add_child(market_panel)
	var market_title := Label.new()
	market_title.text = "단추상점 · 카드 70 보풀"
	market_title.add_theme_font_size_override("font_size", 8)
	var market_header := HBoxContainer.new()
	market_panel.add_child(market_header)
	market_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	market_header.add_child(market_title)
	market_title.text = "단추의 행동표 상점"
	market_panel.z_index = 40
	market_background.z_index = 39
	market_panel.position = Vector2(27,17)
	market_background.position = Vector2(22,12)
	market_background.size = Vector2(276,155)
	market_background.color = Color(0.16,0.125,0.10,0.96)
	var shop_theme := preload("res://assets/fonts/game_theme.tres").duplicate(true) as Theme
	for entry in [["normal","403a33"],["hover","655245"],["pressed","46726b"]]:
		var shop_style := shop_theme.get_stylebox(str(entry[0]),"Button") as StyleBoxFlat
		shop_style.bg_color = Color(str(entry[1]))
		shop_style.border_color = Color("bea477")
	market_panel.theme = shop_theme
	var close_market := Button.new()
	close_market.text = "거래 마치기"
	close_market.size_flags_horizontal = Control.SIZE_SHRINK_END
	close_market.add_theme_font_size_override("font_size",7)
	close_market.pressed.connect(func() -> void:
		market_open = false
		render_state(game.call("state")))
	market_header.add_child(close_market)
	market_button = Button.new()
	market_button.text = "단추상점 거래"
	market_button.position = Vector2(244,140)
	market_button.add_theme_font_size_override("font_size",7)
	market_button.pressed.connect(open_market)
	market_button.hide()
	add_child(market_button)
	var sections := TabContainer.new()
	sections.custom_minimum_size = Vector2(264,72)
	sections.add_theme_font_size_override("font_size",7)
	market_panel.add_child(sections)
	var card_page := VBoxContainer.new()
	card_page.add_theme_constant_override("separation",1)
	card_page.name = "카드 3장 중 선택"
	sections.add_child(card_page)
	var market_buttons := HBoxContainer.new()
	card_page.add_child(market_buttons)
	for index in 3:
		var product := Button.new()
		product.custom_minimum_size = Vector2(82,56)
		var picture := CardFace.new()
		picture.name = "Picture"
		picture.position = Vector2(21,1)
		picture.size = Vector2(40,54)
		product.add_child(picture)
		var back := CardFace.new()
		back.name = "Back"
		back.position = picture.position
		back.size = picture.size
		back.back = true
		product.add_child(back)
		var caption := Label.new()
		caption.name = "Caption"
		caption.position = Vector2(2,45)
		caption.size = Vector2(78,10)
		caption.add_theme_font_size_override("font_size",6)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
		product.add_child(caption)
		product.pressed.connect(func() -> void:
			if market_reveal_elapsed < MARKET_REVEAL_DURATION or index >= game.call("state").get("market_offer",[]).size(): return
			market_selection = index
			render_state(game.call("state")))
		market_products.append(product)
		market_buttons.add_child(product)
	market_description = Label.new()
	market_description.custom_minimum_size = Vector2(264,22)
	market_description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	market_description.add_theme_font_size_override("font_size",6)
	market_description.add_theme_constant_override("line_spacing",-1)
	card_page.add_child(market_description)
	market_buy = Button.new()
	market_buy.add_theme_font_size_override("font_size",7)
	market_buy.pressed.connect(buy_selected_market_card)
	card_page.add_child(market_buy)
	var finance_buttons := HBoxContainer.new()
	finance_buttons.name = "담보 대출"
	sections.add_child(finance_buttons)
	for entry in [["실밥1 잠금 → 150 대출", "loan"], ["이자 포함 상환", "repay"]]:
		_add_action_button(finance_buttons, str(entry[0]), func() -> void: market_requested.emit(str(entry[1])))
	var roulette := HBoxContainer.new()
	roulette.name = "룰렛"
	sections.add_child(roulette)
	_add_action_button(roulette,"20보풀 베팅",func() -> void: market_requested.emit("roulette:20"))
	market_notice.add_theme_font_size_override("font_size", 5)
	market_notice.hide()
	market_notice.clip_text = true
	market_notice.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	market_notice.custom_minimum_size = Vector2(224, 8)
	market_panel.add_child(market_notice)
	played_background = ColorRect.new()
	played_background.position = Vector2(134, 62)
	played_background.size = Vector2(180, 48)
	played_background.color = Color(0.04, 0.055, 0.09, 0.9)
	played_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	played_background.visible = false
	add_child(played_background)
	played_panel = VBoxContainer.new()
	played_panel.position = Vector2(137, 65)
	played_panel.add_theme_constant_override("separation", 0)
	played_panel.visible = false
	add_child(played_panel)
	played_title.add_theme_font_size_override("font_size", 7)
	played_panel.add_child(played_title)
	played_panel.add_child(played_icons)
	played_names.add_theme_font_size_override("font_size", 7)
	played_names.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	played_names.custom_minimum_size = Vector2(160, 0)
	played_panel.add_child(played_names)
	result_panel = PanelContainer.new()
	result_panel.position = Vector2(28,43)
	result_panel.custom_minimum_size = Vector2(264,100)
	result_panel.z_index = 35
	var result_style := StyleBoxFlat.new()
	result_style.bg_color = Color("101c2a")
	result_style.border_color = Color("d2b16e")
	result_style.set_border_width_all(1)
	result_style.content_margin_left = 6
	result_style.content_margin_right = 6
	result_style.content_margin_top = 5
	result_style.content_margin_bottom = 5
	result_panel.add_theme_stylebox_override("panel",result_style)
	add_child(result_panel)
	var result_layout := VBoxContainer.new()
	result_panel.add_child(result_layout)
	var result_title := Label.new()
	result_title.text = "최종 결산 · 현금 + 물품 감정가 − 빚"
	result_title.add_theme_font_size_override("font_size",8)
	result_layout.add_child(result_title)
	result_grid = GridContainer.new()
	result_grid.columns = 5
	result_grid.add_theme_constant_override("h_separation",4)
	result_grid.add_theme_constant_override("v_separation",6)
	result_layout.add_child(result_grid)
	result_panel.hide()


func set_appraisal_access(available: bool, anchor := Vector2(112,150)) -> void:
	if appraisal_near != available:
		appraisal_near = available
		render_state(game.call("state"))
	var position := Vector2(clampf(anchor.x-35,28,160),clampf(anchor.y+2,128,143))
	sell_button.position = position
	sale_previous.position = position-Vector2(23,0)
	sale_next.position = position+Vector2(97,0)
	sale_label.position = position+Vector2(0,22)

func set_market_access(available: bool) -> void:
	if not available: market_open = false
	if market_near != available:
		market_near = available
		render_state(game.call("state"))

func buy_selected_market_card() -> void:
	var offer: Array = game.call("state").get("market_offer", [])
	if market_buy.disabled or market_reveal_elapsed < MARKET_REVEAL_DURATION: return
	if offer.is_empty():
		market_buy.disabled = true
		market_requested.emit("pack")
		return
	if market_selection < 0 or market_selection >= offer.size(): return
	var card_id := str(offer[market_selection])
	market_selection = -1
	market_buy.disabled = true
	market_requested.emit(card_id)

func open_market() -> void:
	if market_near:
		market_open = true
		render_state(game.call("state"))

func set_voice_status(status: String) -> void:
	if voice_button != null:
		voice_button.text = "MIC" if status == "MIC OFF" else status.left(6)

func set_voice_peers(players: Dictionary, suspicious_ids: Array = [], kick_votes: Dictionary = {}) -> void:
	if voice_rows == null:
		return
	var ids: Array[int] = []
	var signature_parts: Array[String] = []
	for raw_id in players:
		var peer_id := int(raw_id)
		if peer_id != int(game.get("local_player_id")):
			ids.append(peer_id)
	ids.sort()
	for peer_id in ids:
		var profile: Dictionary = players.get(peer_id, players.get(str(peer_id), {})).get("profile", {})
		signature_parts.append("%d:%s:%s:%s" % [peer_id, str(profile.get("nickname", "")), suspicious_ids.has(peer_id) or suspicious_ids.has(str(peer_id)), str(kick_votes.get(str(peer_id), kick_votes.get(peer_id, 0)))])
	var signature := ",".join(signature_parts)
	if signature == voice_peer_signature:
		return
	voice_peer_signature = signature
	for child in voice_rows.get_children():
		if child.name != "MicGainRow":
			child.free()
	for raw_id in players:
		var peer_id := int(raw_id)
		if peer_id == int(game.get("local_player_id")):
			continue
		var state: Dictionary = players.get(peer_id, players.get(str(peer_id), {}))
		var profile: Dictionary = state.get("profile", {})
		var row := HBoxContainer.new()
		row.name = "Peer-%d" % peer_id
		var label := Label.new()
		label.text = str(profile.get("nickname", "AI-%d" % (peer_id - 99)))
		if suspicious_ids.has(peer_id) or suspicious_ids.has(str(peer_id)):
			label.text = "⚠ " + label.text
			label.add_theme_color_override("font_color", Color("ff6b6b"))
		label.set_meta("voice_name", label.text)
		label.custom_minimum_size = Vector2(57, 14)
		label.add_theme_font_size_override("font_size", 6)
		row.add_child(label)
		var mute := Button.new()
		mute.text = "🔊"
		mute.custom_minimum_size = Vector2(22, 14)
		mute.add_theme_font_size_override("font_size", 6)
		mute.pressed.connect(func() -> void: voice_peer_mute_requested.emit(peer_id))
		row.add_child(mute)
		_add_action_button(row, "-", func() -> void: voice_peer_volume_requested.emit(peer_id, -0.1))
		_add_action_button(row, "+", func() -> void: voice_peer_volume_requested.emit(peer_id, 0.1))
		if peer_id > 1 and not bool(state.get("bot", false)):
			var vote := Button.new()
			vote.text = "퇴장 %d" % int(kick_votes.get(str(peer_id), kick_votes.get(peer_id, 0)))
			vote.tooltip_text = "추방 투표"
			vote.add_theme_font_size_override("font_size", 6)
			vote.pressed.connect(func() -> void: vote_kick_requested.emit(peer_id))
			row.add_child(vote)
		voice_rows.add_child(row)

func set_voice_gain(value: float) -> void:
	if voice_rows == null:
		return
	var label := voice_rows.get_node_or_null("MicGainRow/MicGainLabel")
	if label != null:
		label.text = "내 감도 %d%%" % roundi(value * 100.0)

func set_peer_mute(peer_id: int, muted: bool) -> void:
	var row := voice_rows.get_node_or_null("Peer-%d" % peer_id) if voice_rows != null else null
	if row != null:
		for child in row.get_children():
			if child is Button and child.text in ["🔊", "🔇"]:
				child.text = "🔇" if muted else "🔊"

func set_peer_volume(peer_id: int, value: float) -> void:
	var row := voice_rows.get_node_or_null("Peer-%d" % peer_id) if voice_rows != null else null
	if row != null and not row.get_children().is_empty():
		var label = row.get_child(0)
		label.text = "%s %d%%" % [str(label.get_meta("voice_name", "상대")), roundi(value * 100.0)]

func _send_chat(message: String) -> void:
	if not message.strip_edges().is_empty():
		chat_requested.emit(message)
		chat_input.clear()
		chat_input.release_focus()
		chat_composer.hide()

func open_chat() -> void:
	chat_composer.show()
	chat_input.grab_focus()

func set_chat_anchor(screen_position: Vector2) -> void:
	if chat_composer != null:
		var bounds := get_viewport().get_visible_rect().size
		chat_composer.position = Vector2(clampf(screen_position.x - 50, 4, maxf(4, bounds.x - 110)), clampf(screen_position.y - 90, 55, maxf(55, bounds.y - 24)))

func _add_action_button(parent: HBoxContainer, text_value: String, action: Callable) -> void:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size = Vector2(24, 16)
	button.add_theme_font_size_override("font_size", 6)
	button.pressed.connect(action)
	parent.add_child(button)

func _process(delta: float) -> void:
	if market_reveal_elapsed < MARKET_REVEAL_DURATION:
		market_reveal_elapsed = minf(MARKET_REVEAL_DURATION,market_reveal_elapsed+delta)
		_update_market_reveal()
		if market_reveal_elapsed >= MARKET_REVEAL_DURATION:
			render_state(game.call("state"))
	played_remaining = maxf(0.0, played_remaining - delta)
	if played_remaining <= 0.0 and played_panel != null:
		played_panel.hide()
		played_background.hide()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_ESCAPE and chat_composer.visible:
			chat_input.release_focus()
			chat_composer.hide()
			get_viewport().set_input_as_handled()
			return
		if get_viewport().gui_get_focus_owner() is LineEdit:
			return
		if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
			if not selected_indices.is_empty(): submit_selected()
			else: open_chat()
			get_viewport().set_input_as_handled()
			return
		if event.keycode == KEY_B:
			game.call("request_bid")
		elif event.keycode == KEY_H:
			game.call("buy_hint")
		elif event.keycode == KEY_C:
			toggle_card_id("inspect")
		elif event.keycode == KEY_G:
			toggle_card_id("shield")
		elif event.keycode == KEY_P:
			game.call("request_fold")
		elif event.keycode == KEY_T:
			game.call("request_pass")
		elif event.keycode >= KEY_1 and event.keycode <= KEY_5:
			toggle_hand(event.keycode - KEY_1)

func toggle_hand(index: int) -> void:
	var state: Dictionary = game.call("state")
	var cards: Array = state.get("hand", [])
	if index < 0 or index >= cards.size():
		return
	var local_id := int(game.get("local_player_id"))
	var is_bid := str(cards[index].get("id", "")) == "bid"
	var is_my_turn := int(state.get("turn_id", -1)) == local_id
	var can_interrupt_bid: bool = str(state.get("phase", "")) == "auction" and is_bid and int(state.get("leader", -1)) != local_id and not state.get("folded", []).has(local_id) and not state.get("card_blocked", []).has(local_id)
	if not is_my_turn and not can_interrupt_bid:
		return
	if int(state.get("turn_id", -1)) == -1 and not is_bid:
		return
	if not selected_indices.has(index):
		selected_indices.clear()
	if selected_indices.has(index):
		selected_indices.erase(index)
	else:
		selected_indices.append(index)
	render_state(game.call("state"))

func play_dropped_card(index: int) -> void:
	var state: Dictionary = game.call("state")
	var cards: Array = state.get("hand", [])
	if index < 0 or index >= cards.size():
		return
	var local_id := int(game.get("local_player_id"))
	var is_bid := str(cards[index].get("id", "")) == "bid"
	var can_interrupt_bid: bool = str(state.get("phase", "")) == "auction" and is_bid and int(state.get("leader", -1)) != local_id and not state.get("folded", []).has(local_id) and not state.get("card_blocked", []).has(local_id)
	if int(state.get("turn_id", -1)) != local_id and not can_interrupt_bid:
		return
	toggle_hand(index)

func toggle_card_id(card_id: String) -> void:
	var cards: Array = game.call("state").get("hand", [])
	for index in cards.size():
		if cards[index].get("id", "") == card_id:
			toggle_hand(index)
			return

func submit_selected() -> void:
	if selected_indices.is_empty():
		return
	var cards: Array = game.call("state").get("hand", [])
	if selected_indices.size() == 1 and str(cards[selected_indices[0]].id) == "bid":
		game.call("request_bid")
	else:
		game.call("submit_hand", selected_indices.duplicate())
	selected_indices.clear()
	render_state(game.call("state"))

func shift_sale_selection(direction: int) -> void:
	var inventory: Array = game.call("state").get("inventory", [])
	if not inventory.is_empty():
		sale_index = posmod(sale_index + direction, inventory.size())
		render_state(game.call("state"))

func _update_market_reveal() -> void:
	var offer: Array = game.call("state").get("market_offer",[])
	for index in market_products.size():
		var product := market_products[index]
		var picture := product.get_node("Picture") as BidCardFace
		var back := product.get_node("Back") as BidCardFace
		var caption := product.get_node("Caption") as Label
		var t := clampf((market_reveal_elapsed-float(index)*0.15)/0.45,0.0,1.0)
		var paid := index < offer.size()
		picture.visible = paid and t >= 0.5
		back.visible = not paid or t < 0.5
		caption.visible = not paid or t >= 1.0
		picture.pivot_offset = picture.size*0.5
		back.pivot_offset = back.size*0.5
		var width := maxf(0.06,absf(t*2.0-1.0)) if paid else 1.0
		picture.scale.x = width
		back.scale.x = width
		if paid and t >= 1.0 and not market_reveal_sparks.has(index):
			market_reveal_sparks.append(index)
			if market_panel.visible:
				var sparkle := preload("res://scripts/pixelfx_sprite_2d.gd").new()
				product.add_child(sparkle)
				sparkle.play_effect("pickups/collect-burst",Vector2(36,18))
				sparkle.scale = Vector2.ONE*0.12

func render_state(state: Dictionary) -> void:
	var offer: Array = state.get("market_offer", [])
	var offer_signature := JSON.stringify(offer)
	if market_offer_signature != offer_signature:
		market_selection = -1
		market_reveal_elapsed = 0.0 if not offer.is_empty() and not market_offer_signature.is_empty() else MARKET_REVEAL_DURATION
		market_reveal_sparks.clear()
		market_offer_signature = offer_signature
	for index in market_products.size():
		var product := market_products[index]
		product.disabled = index >= offer.size() or market_reveal_elapsed < MARKET_REVEAL_DURATION
		if index >= offer.size():
			product.get_node("Picture").set_card({})
			product.get_node("Caption").text = "? · 결제 후 공개"
			product.tooltip_text = ""
			product.modulate = Color.WHITE
		if index < offer.size():
			var card: Dictionary = game.call("card_definition", str(offer[index]))
			product.get_node("Caption").text = str(card.name)
			product.tooltip_text = "%s · 실밥%d\n%s" % [card.name,card.cost,card.text]
			product.get_node("Picture").set_card(card)
			product.modulate = Color("ffe0a0") if index == market_selection else Color.WHITE
	market_description.text = "70보풀을 먼저 내면 무작위 3장이 공개됩니다. 그중 1장을 가져가세요." if offer.is_empty() else "결제 완료 · 3장 중 1장을 골라 보관함으로 가져가세요."
	market_buy.text = "봉투 구매 · 70보풀" if offer.is_empty() else "선택한 1장 가져가기 · 추가 결제 없음"
	market_buy.disabled = int(state.get("cash",{}).get(game.get("local_player_id"),0)) < 70 if offer.is_empty() else market_selection < 0
	if market_selection >= 0 and market_selection < offer.size():
		var chosen: Dictionary = game.call("card_definition",str(offer[market_selection]))
		market_description.text = str(chosen.text)
	if market_reveal_elapsed < MARKET_REVEAL_DURATION:
		market_buy.disabled = true
		market_buy.text = "봉투 개봉 중…"
		market_description.text = "결제 완료! 카드 3장을 차례대로 공개합니다."
	_update_market_reveal()
	var results: Array = state.get("final_standings",[])
	result_panel.visible = str(state.get("phase")) == "finished" and not results.is_empty()
	var result_key := JSON.stringify(results)
	if result_signature != result_key:
		result_signature = result_key
		for child in result_grid.get_children():
			result_grid.remove_child(child)
			child.queue_free()
		var cells: Array = ["참가자","현금","물품","빚","순자산"]
		for row in results:
			cells.append_array(["%d위 %s" % [int(row.rank),str(row.name)],str(row.cash),str(row.goods),str(row.debt),str(row.score)])
		for index in cells.size():
			var cell := Label.new()
			cell.text = str(cells[index])
			cell.tooltip_text = cell.text
			cell.add_theme_font_size_override("font_size",6)
			cell.custom_minimum_size.x = 98 if index%5 == 0 else 30
			cell.clip_text = true
			if index%5 != 0: cell.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			if index >= 5 and int(results[(index-5)/5].rank) == 1: cell.modulate = Color("ffe0a0")
			result_grid.add_child(cell)
	var cards: Array = state.get("hand", [])
	var local_id := int(game.get("local_player_id"))
	var hand_signature := JSON.stringify(cards)
	var has_bid := cards.any(func(card: Dictionary) -> bool: return str(card.get("id", "")) == "bid")
	var can_interrupt_bid: bool = str(state.get("phase", "")) == "auction" and has_bid and int(state.get("leader", -1)) != local_id and not state.get("folded", []).has(local_id) and not state.get("card_blocked", []).has(local_id)
	var can_stage: bool = int(state.get("turn_id", -1)) == local_id or can_interrupt_bid
	if staged_hand != hand_signature or str(state.get("phase")) != "auction" or not can_stage:
		selected_indices.clear()
	staged_hand = hand_signature
	selected_indices = selected_indices.filter(func(index: int) -> bool: return index >= 0 and index < cards.size())
	var staged_cost := 0
	for index in selected_indices: staged_cost += int(cards[index].get("cost", 0))
	submit_button.visible = not selected_indices.is_empty()
	clear_button.visible = submit_button.visible
	submit_button.text = "② 카드 1장 제출 · 실밥%d" % staged_cost
	submit_button.disabled = staged_cost > int(state.get("energy",0))
	var market_message := str(state.get("announcement", ""))
	market_notice.text = market_message if market_message.contains("단추상점") or market_message.contains("덱은") or market_message.contains("보풀") or market_message.contains("룰렛") else "구매한 카드는 보관함으로 · 덱 편성은 덱 버튼"
	var lot: Dictionary = state.get("lot", {})
	var phase := str(state.get("phase", "waiting"))
	exploration_controls.visible = phase in ["waiting","appraisal"]
	guide_label.position.y = 23.0 if phase == "auction" else 4.0
	fold_button.visible = phase == "auction"
	pass_button.visible = phase == "auction"
	lot_label.text = "LOT %d/%d  %s" % [int(state.get("cycle", 0)), int(state.get("goal_rounds", 5)), "방장 연결 중…" if phase == "connecting" else lot.get("name", "준비 중")]
	var hints: Array = state.get("hints", [])
	var latest_hint := ", ".join(hints) if not hints.is_empty() else "없음"
	detail_label.text = "공개: %s" % latest_hint
	var private_hints: Array = state.get("private_hints", [])
	if not private_hints.is_empty():
		detail_label.text += "\n나만: %s" % ", ".join(private_hints)
	detail_label.text += "\n가치↑: 희소성 > 출처 > 상태"
	var value_range: Array = state.get("value_range", [20, 20])
	if value_range.size() >= 2:
		detail_label.text += "\n예상가: %d~%d 보풀" % [int(value_range[0]), int(value_range[1])]
	detail_label.clip_text = false
	status_label.text = "%d 보풀 · 망치 %d/3 · %.0f초" % [state.get("bid", 0), state.get("hammer", 0), state.get("timer", 0.0)]
	leader_label.visible = phase == "auction"
	leader_label.text = "최고 입찰자  %s  ·  %d보풀" % [str(state.get("leader_name", "없음")), int(state.get("bid", 0))] if int(state.get("leader", -1)) >= 0 else "최고 입찰자  없음 · 첫 입찰 대기"
	if phase == "connecting":
		status_label.text = "경매장 연결 중…"
	elif phase == "finished":
		status_label.text = "최종 순위 확정 · %d명" % results.size()
	elif phase == "waiting":
		status_label.text = "준비 중 · 착석 %d/%d" % [int(state.get("table_count", 0)), int(state.get("table_total", 0))]
	var cash: Dictionary = state.get("cash", {})
	var debt: Dictionary = state.get("debt", {})
	var locked: Dictionary = state.get("locked_energy", {})
	cash_label.text = "보풀 %d · 빚 %d · 실밥 %d" % [int(cash.get(local_id, cash.get(str(local_id), 0))), int(debt.get(local_id, debt.get(str(local_id), 0))), int(state.get("energy", 0))]
	var played: Dictionary = state.get("last_play", {})
	if phase == "auction" and not played.is_empty() and int(played.get("sequence", -1)) != played_sequence:
		played_remaining = PLAYED_DISPLAY_SECONDS
	played_panel.visible = phase == "auction" and not played.is_empty() and played_remaining > 0.0
	played_background.visible = played_panel.visible
	if played_panel.visible and int(played.get("sequence", -1)) != played_sequence:
		played_sequence = int(played.get("sequence", -1))
		played_title.text = "%s의 제출 카드" % str(played.get("player_name", "참가자"))
		for icon in played_icons.get_children():
			played_icons.remove_child(icon)
			icon.queue_free()
		var names: Array[String] = []
		for card in played.get("cards", []):
			var icon := CardFace.new()
			icon.set_card(card)
			icon.custom_minimum_size = Vector2(22, 30)
			played_icons.add_child(icon)
			names.append("%s (실밥 %d)" % [str(card.get("name", "카드")), int(card.get("cost", 0))])
		played_names.text = " · ".join(names)
	elif played.is_empty():
		played_sequence = -1
	if market_panel != null:
		market_button.visible = market_near and phase in ["waiting", "appraisal"]
		market_panel.visible = market_button.visible and market_open
		market_background.visible = market_panel.visible
	var inventory: Array = state.get("inventory", [])
	if inventory.is_empty():
		sale_index = 0
	else:
		sale_index = clampi(sale_index, 0, inventory.size() - 1)
	if sell_button != null:
		sell_button.visible = appraisal_near and not market_near and phase == "appraisal" and not inventory.is_empty() and not bool(state.get("sold", false))
		sale_previous.visible = sell_button.visible and inventory.size() > 1
		sale_next.visible = sell_button.visible and inventory.size() > 1
		sale_label.visible = false
		if sell_button.visible:
			var item: Dictionary = inventory[sale_index]
			sell_button.text = "%d보풀에 판매" % int(item.get("appraisal", 0))
			sale_label.text = "%d/%d %s\n낙찰가 %d · 감정가 %d" % [sale_index + 1, inventory.size(), item.get("name", "물품"), int(item.get("paid", 0)), int(item.get("appraisal", 0))]
			sell_button.tooltip_text = sale_label.text
	if phase == "connecting":
		guide_label.text = "방장에게서 경매장 정보를 받는 중…"
	elif phase == "waiting":
		guide_label.text = "준비 %d초 · 상점 방문 / 덱 편성\n모두 착석하면 일찍 시작" % ceili(float(state.get("timer",0))) if float(state.get("timer",0)) > 0 else "상점 / 덱 편성 가능 · 빈 좌석을 눌러 착석"
	elif phase == "appraisal":
		guide_label.text = "준비 %d초 · 판매·단추상점·덱 편성 · 재착석 %d/%d" % [ceili(float(state.get("timer",0))),int(state.get("table_count",0)),int(state.get("table_total",0))]
	elif phase == "finished":
		var winners := results.filter(func(row: Dictionary) -> bool: return int(row.rank) == 1)
		guide_label.text = "경매 종료 · 공동 우승 %d명" % winners.size() if winners.size() > 1 else "경매 종료 · %s 우승" % str(winners[0].name) if not winners.is_empty() else "경매 종료"
	elif phase != "auction":
		guide_label.text = str(state.get("announcement", "결과 확인 중"))
	elif int(state.get("turn_id", -1)) < 0:
		guide_label.text = "최종 입찰 구간 · 선두 %s · 입찰 카드/B 가능" % str(state.get("leader_name", "없음"))
	elif int(state.get("turn_id", -1)) != local_id:
		guide_label.text = "%s 차례 · 입찰 카드는 지금도 제출 가능 · %d초" % [str(state.get("turn_name","참가자")),ceili(float(state.get("timer",0)))] if can_interrupt_bid else "%s 차례 · %d초" % [str(state.get("turn_name","참가자")),ceili(float(state.get("timer",0)))]
	elif state.get("card_blocked", []).has(local_id):
		guide_label.text = "봉쇄! 방어·공격 1장으로 해제 후 차례 종료 · 또는 넘김"
	elif cards.any(func(card: Dictionary) -> bool: return card.get("id", "") == "bid"):
		guide_label.text = "▶ 내 차례 · %d초 · 카드 1장씩 제출, 끝나면 넘김" % ceili(float(state.get("timer",0)))
	else:
		guide_label.text = "▶ 내 차례 · %d초 · 입찰 카드 없음" % ceili(float(state.get("timer",0)))
	if card_fan != null:
		card_fan.visible = phase == "auction"
		card_fan.set("play_allowed", phase == "auction" and (int(state.get("turn_id", -1)) == local_id or can_interrupt_bid))
		card_fan.set("drop_card_ids", ["bid"] if can_interrupt_bid and int(state.get("turn_id", -1)) != local_id else [])
		var piles: Dictionary = state.get("pile_counts",{})
		card_fan.set("draw_pile_count",int(piles.get("draw",0)))
		card_fan.set("discard_count",int(piles.get("discard",0)))
		card_fan.set("available_energy",int(state.get("energy",0)))
		card_fan.call("set_cards", cards, selected_indices)
