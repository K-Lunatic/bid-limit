class_name CardArc2D
extends Node2D
const CardFace = preload("res://scripts/card_face_ui.gd")

var card_count := 0
var selected_count := 0

func set_count(value: int, selected := 0) -> void:
	card_count = clampi(value, 0, 5)
	selected_count = clampi(selected, 0, card_count)
	queue_redraw()

func _draw() -> void:
	if card_count <= 0:
		return
	var center := Vector2(0, -164)
	for index in card_count:
		var ratio := 0.5 if card_count == 1 else float(index) / float(card_count - 1)
		var arc := lerpf(-0.72, 0.72, ratio)
		var position := center + Vector2(sin(arc) * 52.0, -cos(arc) * 26.0)
		var rotation := arc * 0.42
		draw_set_transform(position, rotation, Vector2.ONE*0.45)
		if index < selected_count: draw_rect(CardFace.FRAME.grow(3),Color("e4b766"))
		CardFace.paint(self,{},true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_string(ThemeDB.fallback_font, center + Vector2(-10, -42), "×%d" % card_count, HORIZONTAL_ALIGNMENT_LEFT, 24, 9, Color("fff1c4"))
