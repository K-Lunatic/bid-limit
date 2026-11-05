@tool
class_name LotMonitor2D
extends Node2D

var option_count := 0
var visible_options: Array = []

func set_options(count: int, options: Array) -> void:
	option_count = maxi(count, 0)
	visible_options = options.duplicate()
	queue_redraw()

func _draw() -> void:
	# CRT casing and scan lines are deliberately separate from the lot.
	draw_rect(Rect2(-112, -43, 224, 86), Color("282a35"))
	draw_rect(Rect2(-108, -39, 216, 78), Color("a48a68"))
	draw_rect(Rect2(-103, -34, 195, 68), Color("122d31"))
	draw_rect(Rect2(-99, -30, 187, 60), Color("1b4344"))
	for y in range(-28, 30, 4):
		draw_line(Vector2(-98, y), Vector2(87, y), Color(0.02, 0.10, 0.11, 0.25), 1.0)
	draw_string(ThemeDB.fallback_font, Vector2(-92, -21), "옵션 %d / %d 공개" % [visible_options.size(), option_count], HORIZONTAL_ALIGNMENT_LEFT, 176, 10, Color("c9f3c1"))
	for index in mini(option_count, 5):
		var label := str(visible_options[index]) if index < visible_options.size() else "???"
		draw_string(ThemeDB.fallback_font, Vector2(-92, -9 + index * 9), label, HORIZONTAL_ALIGNMENT_LEFT, 176, 9, Color("a8dbc1"))
	draw_circle(Vector2(100, 23), 3.0, Color("e7bf76"))
