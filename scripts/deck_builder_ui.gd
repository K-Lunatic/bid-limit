class_name DeckBuilderUI
extends PanelContainer

const CardFace = preload("res://scripts/card_face_ui.gd")
var game: Node
var list: GridContainer
var deck_list: GridContainer
var summary: Label
var description: Label
var signature := ""
var selected_id := ""

func setup(session: Node) -> void:
	game = session
	position = Vector2(8,16)
	size = Vector2(304,150)
	z_index = 40
	var style := StyleBoxFlat.new()
	style.bg_color = Color("101c2a")
	style.border_color = Color("ba975e")
	style.set_border_width_all(1)
	style.content_margin_left = 5
	style.content_margin_right = 5
	style.content_margin_top = 4
	style.content_margin_bottom = 4
	add_theme_stylebox_override("panel",style)
	var layout := VBoxContainer.new()
	add_child(layout)
	var header := HBoxContainer.new()
	layout.add_child(header)
	summary = Label.new()
	summary.add_theme_font_size_override("font_size",8)
	summary.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(summary)
	var close := Button.new()
	close.text = "닫기"
	close.add_theme_font_size_override("font_size",7)
	close.pressed.connect(hide)
	header.add_child(close)
	var columns := HBoxContainer.new()
	columns.add_theme_constant_override("separation", 5)
	layout.add_child(columns)
	for is_collection in [true,false]:
		var column := VBoxContainer.new()
		columns.add_child(column)
		var title := Label.new()
		title.text = "보유 카드 · 눌러서 확인" if is_collection else "현재 덱 · 카드별 매수"
		title.add_theme_font_size_override("font_size",7)
		column.add_child(title)
		var scroll := ScrollContainer.new()
		scroll.custom_minimum_size = Vector2(177 if is_collection else 112,64)
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		column.add_child(scroll)
		if is_collection:
			list = GridContainer.new()
			list.columns = 3
			scroll.add_child(list)
		else:
			deck_list = GridContainer.new()
			deck_list.columns = 2
			deck_list.add_theme_constant_override("h_separation", 2)
			deck_list.add_theme_constant_override("v_separation", 2)
			scroll.add_child(deck_list)
	description = Label.new()
	description.add_theme_font_size_override("font_size",6)
	description.add_theme_constant_override("line_spacing",0)
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.custom_minimum_size.x = 276
	var detail_scroll := ScrollContainer.new()
	detail_scroll.custom_minimum_size = Vector2(280,25)
	detail_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(detail_scroll)
	detail_scroll.add_child(description)
	game.changed.connect(func(state: Dictionary) -> void:
		if visible: refresh(state))
	hide()

func toggle() -> void:
	visible = not visible
	if visible:
		signature = ""
		refresh(game.call("state"))

func refresh(state: Dictionary) -> void:
	var cards: Array = state.get("deck_view",[])
	var editable := str(state.get("phase","")) in ["waiting","appraisal"]
	var next_signature := JSON.stringify([cards,editable])
	if next_signature == signature: return
	signature = next_signature
	for container in [list,deck_list]:
		for child in container.get_children():
			container.remove_child(child)
			child.queue_free()
	var total := 0
	for card in cards: total += int(card.active)
	summary.text = "내 덱 %d/15   ·   보유 카드에서 + / −로 편성" % total
	for card in cards:
		var id := str(card.id)
		var row := VBoxContainer.new()
		row.custom_minimum_size.x = 55
		list.add_child(row)
		var detail := Button.new()
		detail.custom_minimum_size = Vector2(55,60)
		var face := CardFace.new()
		face.position = Vector2(7,1)
		face.size = Vector2(41,57)
		face.set_card(card)
		detail.add_child(face)
		detail.tooltip_text = str(card.name)
		detail.pressed.connect(func() -> void:
			selected_id = id
			description.text = "%s · 실밥%d\n%s" % [str(card.name),int(card.cost),str(card.text)])
		row.add_child(detail)
		var caption := Label.new()
		caption.text = "실밥%d · %d장" % [int(card.cost),int(card.active)+int(card.reserve)]
		caption.add_theme_font_size_override("font_size",6)
		row.add_child(caption)
		if int(card.active) > 0:
			var deck_entry := Button.new()
			deck_entry.custom_minimum_size = Vector2(53,60)
			var deck_face := CardFace.new()
			deck_face.position = Vector2(5,1)
			deck_face.size = Vector2(41,57)
			deck_face.set_card(card)
			deck_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
			deck_entry.add_child(deck_face)
			var deck_count := Label.new()
			deck_count.text = "×%d" % int(card.active)
			deck_count.position = Vector2(35,44)
			deck_count.size = Vector2(16,12)
			deck_count.add_theme_font_size_override("font_size",6)
			deck_count.add_theme_color_override("font_color",Color("fff2c6"))
			deck_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
			deck_entry.add_child(deck_count)
			deck_entry.pressed.connect(func() -> void: detail.pressed.emit())
			deck_list.add_child(deck_entry)
		var actions := HBoxContainer.new()
		row.add_child(actions)
		for adding in [false,true]:
			var button := Button.new()
			button.text = "+" if adding else "−"
			button.custom_minimum_size = Vector2(16,16)
			button.add_theme_font_size_override("font_size",7)
			button.disabled = not editable
			if adding:
				button.disabled = button.disabled or int(card.reserve) <= 0 or total >= 15
			else:
				button.disabled = button.disabled or int(card.active) <= 0 or total <= 8 or (id == "bid" and int(card.active) <= 1)
			button.pressed.connect(func() -> void: game.call("request_deck_change",id,adding))
			actions.add_child(button)
		if selected_id.is_empty() or selected_id == id:
			selected_id = id
			description.text = "%s: %s" % [str(card.name),str(card.text)]
