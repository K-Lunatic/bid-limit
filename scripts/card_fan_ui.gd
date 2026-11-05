class_name CardFanUI
extends Control

signal card_dropped(index: int)

const CARD_SCALE := 0.75
const DRAG_THRESHOLD := 5.0
const CardFace = preload("res://scripts/card_face_ui.gd")
const CARD_ART = CardFace.ART
const FX = preload("res://scripts/pixelfx_sprite_2d.gd")
const ART_INDEX := CardFace.ART_INDEX
var cards: Array = []
var selected: Array[int] = []
var drag_index := -1
var drag_position := Vector2.ZERO
var press_position := Vector2.ZERO
var drag_touch := -1
var preview_index := -1
var dragging := false
var play_allowed := true
var drop_card_ids: Array[String] = []
var incoming := {}
var submission := {}
var draw_pile_count := 0
var discard_count := 0
var available_energy := 3

func art_region(card_id: String) -> Rect2:
	return CardFace.art_region(card_id)

func card_texture(_card_id: String) -> Texture2D:
	return CARD_ART

func card_region(card_id: String, _legacy_style: int = 0) -> Rect2:
	return art_region(card_id)

func drop_zone() -> Rect2:
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(320,180)
	return Rect2(viewport_size.x*0.5-48,viewport_size.y*0.5-24,96,48)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_exited.connect(func() -> void:
		if drag_index < 0:
			preview_index = -1
			queue_redraw())

func set_cards(next_cards: Array, selected_indices: Array) -> void:
	if cards != next_cards:
		var previous_counts := {}
		for card in cards:
			var id := str(card.get("id",""))
			previous_counts[id] = int(previous_counts.get(id,0))+1
		incoming.clear()
		for index in next_cards.size():
			var id := str(next_cards[index].get("id",""))
			if int(previous_counts.get(id,0)) > 0:
				previous_counts[id] -= 1
			else:
				incoming[index] = -float(incoming.size())*0.09
		preview_index = -1
		drag_index = -1
		drag_touch = -1
		dragging = false
	cards = next_cards.duplicate(true)
	selected.clear()
	for index in selected_indices: selected.append(int(index))
	queue_redraw()

func _has_point(point: Vector2) -> bool:
	return drag_index >= 0 or _card_at(point) >= 0

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed: _begin_drag(event.position)
		elif drag_touch == -1: _end_drag(event.position)
	elif event is InputEventMouseMotion and drag_touch == -1:
		if drag_index >= 0: _move_drag(event.position)
		else:
			preview_index = _card_at(event.position)
			queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed and drag_index < 0:
			_begin_drag(event.position)
			if drag_index >= 0: drag_touch = event.index
		elif not event.pressed and event.index == drag_touch:
			_end_drag(event.position)
	elif event is InputEventScreenDrag and event.index == drag_touch:
		_move_drag(event.position)

func _begin_drag(point: Vector2) -> void:
	if drag_index >= 0: return
	drag_index = _card_at(point)
	preview_index = drag_index
	press_position = point
	drag_position = point
	dragging = false
	queue_redraw()

func _move_drag(point: Vector2) -> void:
	drag_position = point
	if point.distance_to(press_position) >= DRAG_THRESHOLD: dragging = true
	queue_redraw()

func _end_drag(point: Vector2) -> void:
	var index := drag_index
	var moved := dragging or point.distance_to(press_position) >= DRAG_THRESHOLD
	drag_index = -1
	drag_touch = -1
	dragging = false
	var card_allowed := drop_card_ids.is_empty() or (index >= 0 and index < cards.size() and str(cards[index].get("id", "")) in drop_card_ids)
	if moved and play_allowed and card_allowed and index >= 0 and index < cards.size() and drop_zone().has_point(point):
		submission = {"card":cards[index].duplicate(true),"from":point,"age":0.0}
		preview_index = -1
		card_dropped.emit(index)
	queue_redraw()

func _card_at(point: Vector2) -> int:
	if preview_index >= 0 and preview_index < cards.size() and not dragging:
		var origin := _card_transform(preview_index,cards.size()).origin - Vector2(0,9)
		if CardFace.FRAME.grow(1).has_point((point-origin)/0.95): return preview_index
	for index in range(cards.size()-1,-1,-1):
		var transform := _card_transform(index,cards.size())
		var local := (point-transform.origin).rotated(-transform.get_rotation())/CARD_SCALE
		if CardFace.FRAME.grow(1).has_point(local): return index
	return -1

func _card_transform(index: int, count: int) -> Transform2D:
	var ratio := 0.5 if count <= 1 else float(index)/float(count-1)
	var viewport_size := get_viewport_rect().size if is_inside_tree() else Vector2(320,180)
	if selected.has(index):
		return Transform2D(0,Vector2(viewport_size.x*0.5+(selected.find(index)-float(selected.size()-1)*0.5)*27,100))
	return Transform2D(lerpf(-0.16,0.16,ratio),Vector2(viewport_size.x*0.5+(index-float(count-1)*0.5)*29,viewport_size.y-27-sin(ratio*PI)*5))

func _process(delta: float) -> void:
	var changed := false
	for index in incoming.keys():
		incoming[index] += delta
		if incoming[index] >= 0.55:
			incoming.erase(index)
			if visible and index < cards.size(): _spark(_card_transform(index,cards.size()).origin)
		changed = true
	if not submission.is_empty():
		submission.age += delta
		if submission.age >= 0.4: submission.clear()
		changed = true
	if changed: queue_redraw()

func _spark(at: Vector2) -> void:
	var fx := FX.new()
	add_child(fx)
	fx.play_effect("pickups/collect-burst",at)
	fx.scale = Vector2.ONE*0.16

func _paint_card(card: Dictionary, origin: Vector2, angle: float, scale_value: Vector2, back := false) -> void:
	draw_set_transform(origin,angle,scale_value)
	CardFace.paint(self,card,back,int(card.get("cost",0)) <= available_energy)
	draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)

func _draw() -> void:
	if cards.is_empty(): return
	var bounds := get_viewport_rect().size
	draw_string(ThemeDB.fallback_font,Vector2(bounds.x*0.5-80,bounds.y-49),"위로 끌어놓기 → 제출" if play_allowed else "상대 차례 · 끌어서 효과 확인",HORIZONTAL_ALIGNMENT_CENTER,160,5,Color("f4e6c8"))
	if dragging and drag_index >= 0:
		var zone := drop_zone()
		var card_allowed := drop_card_ids.is_empty() or str(cards[drag_index].get("id", "")) in drop_card_ids
		var can_drop := play_allowed and card_allowed
		var color := Color("a6e5cf") if can_drop else Color("e88989")
		draw_rect(zone,Color(color,0.15))
		draw_rect(zone,color,false,1)
		draw_string(ThemeDB.fallback_font,zone.position+Vector2(3,9),"① 여기에 놓기" if can_drop else ("입찰 카드만 가능" if play_allowed else "내 차례를 기다려요"),HORIZONTAL_ALIGNMENT_LEFT,90,7,color)
		var card: Dictionary = cards[drag_index]
		draw_rect(Rect2(4,46,109,101),Color("403734"))
		draw_rect(Rect2(5,47,107,99),Color("f4e6c8"))
		draw_string(ThemeDB.fallback_font,Vector2(9,58),str(card.get("name","카드")),HORIZONTAL_ALIGNMENT_LEFT,98,7,Color("493d38"))
		draw_texture_rect_region(CARD_ART,Rect2(9,64,25,22),art_region(str(card.id)))
		draw_string(ThemeDB.fallback_font,Vector2(39,72),"실밥 %d 필요" % int(card.get("cost",0)),HORIZONTAL_ALIGNMENT_LEFT,69,7,Color("65513e"))
		draw_string(ThemeDB.fallback_font,Vector2(39,83),str(card.get("kind","행동표")),HORIZONTAL_ALIGNMENT_LEFT,69,6,Color("367d78"))
		draw_multiline_string(ThemeDB.fallback_font,Vector2(9,97),str(card.get("text","")),HORIZONTAL_ALIGNMENT_LEFT,99,6,5,Color("493d38"))
		draw_string(ThemeDB.fallback_font,Vector2(9,141),str(card.get("flavor","")),HORIZONTAL_ALIGNMENT_LEFT,99,5,Color("826d5d"))
	for index in cards.size():
		if index == drag_index and dragging: continue
		if index == preview_index: continue
		var transform := _card_transform(index,cards.size())
		var scale_value := Vector2.ONE*CARD_SCALE
		var back := false
		if incoming.has(index):
			var t := clampf(float(incoming[index])/0.55,0.0,1.0)
			var eased := 1.0-pow(1.0-t,3)
			transform.origin = Vector2(get_viewport_rect().size.x-18,get_viewport_rect().size.y-12).lerp(transform.origin,eased)
			transform = Transform2D(lerpf(-0.5,transform.get_rotation(),eased),transform.origin)
			scale_value.x *= maxf(0.12,absf(2*t-1))
			back = t < 0.5
		_paint_card(cards[index],transform.origin,transform.get_rotation(),scale_value,back)
	if preview_index >= 0 and preview_index < cards.size() and not dragging:
		var transform := _card_transform(preview_index,cards.size())
		_paint_card(cards[preview_index],transform.origin-Vector2(0,9),0,Vector2.ONE*0.95)
	if dragging and drag_index >= 0:
		_paint_card(cards[drag_index],drag_position,0,Vector2.ONE*0.88)
	if not submission.is_empty():
		var t := clampf(float(submission.age)/0.4,0,1)
		_paint_card(submission.card,Vector2(submission.from).lerp(drop_zone().get_center(),t),0,Vector2.ONE*lerpf(0.88,0.25,t))
	draw_string(ThemeDB.fallback_font,Vector2(bounds.x-76,bounds.y-28),"덱 %d · 버림 %d" % [draw_pile_count,discard_count],HORIZONTAL_ALIGNMENT_RIGHT,70,5,Color("d2b16e"))
