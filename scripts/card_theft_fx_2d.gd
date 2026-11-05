class_name CardTheftFX2D
extends Node2D

var start_point := Vector2.ZERO
var end_point := Vector2.ZERO
var elapsed := 0.0
var duration := 0.52
var card_label := "훔침"

func setup(from: Vector2, to: Vector2, label := "훔침") -> void:
	start_point = from
	end_point = to
	card_label = label
	position = from
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / duration, 0.0, 1.0)
	var eased := 1.0 - pow(1.0 - t, 3.0)
	position = start_point.lerp(end_point, eased) + Vector2(0, -sin(t * PI) * 46.0)
	rotation = sin(t * PI) * 0.18
	scale = Vector2.ONE * (0.72 + sin(t * PI) * 0.16)
	queue_redraw()
	if t >= 1.0:
		queue_free()

func _draw() -> void:
	draw_rect(Rect2(-15, -21, 30, 42), Color("2a2334"))
	draw_rect(Rect2(-13, -19, 26, 38), Color("f2d7a4"))
	draw_rect(Rect2(-11, -15, 22, 7), Color("ad5149"))
	draw_circle(Vector2(0, 2), 6, Color("f0c46d"))
	draw_string(ThemeDB.fallback_font, Vector2(-11, 15), card_label.left(5), HORIZONTAL_ALIGNMENT_CENTER, 22, 6, Color("493d38"))
