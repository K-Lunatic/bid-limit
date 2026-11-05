class_name ButtonCoinFX2D
extends Node2D

var origin := Vector2.ZERO
var elapsed := 0.0
const DURATION := 0.95

func setup(at: Vector2) -> void:
	origin = at
	position = at
	queue_redraw()

func _process(delta: float) -> void:
	elapsed += delta
	var t := clampf(elapsed / DURATION, 0.0, 1.0)
	position = origin + Vector2(0, -sin(t * PI) * 44.0 - t * 18.0)
	var flip := absf(cos(t * TAU * 1.25))
	scale = Vector2(maxf(0.12, flip), 1.0) * (0.82 + sin(t * PI) * 0.12)
	rotation = sin(t * PI) * 0.18
	queue_redraw()
	if t >= 1.0:
		queue_free()

func _draw() -> void:
	draw_circle(Vector2(0, 2), 16, Color("6b3f58"))
	draw_circle(Vector2.ZERO, 14, Color("f0c768"))
	draw_circle(Vector2.ZERO, 11, Color("d99a50"))
	draw_rect(Rect2(-6, -4, 4, 4), Color("7b5360"))
	draw_rect(Rect2(2, -4, 4, 4), Color("7b5360"))
	draw_rect(Rect2(-6, 4, 4, 4), Color("7b5360"))
	draw_rect(Rect2(2, 4, 4, 4), Color("7b5360"))
	draw_string(ThemeDB.fallback_font, Vector2(-18, -22), "단추 동전", HORIZONTAL_ALIGNMENT_CENTER, 36, 6, Color("ffe8a9"))
