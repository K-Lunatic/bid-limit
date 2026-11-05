class_name FloatingPaddle2D
extends Node2D

var phase := 0.0
var weapon_style := 0

func _ready() -> void:
	z_index = 4

func _process(delta: float) -> void:
	phase += delta
	rotation = sin(phase * 1.8) * 0.12
	queue_redraw()

func _draw() -> void:
	var bob := sin(phase * 2.4) * 2.0
	draw_line(Vector2(-4, 8 + bob), Vector2(18, 30 + bob), Color("d9d0bc"), 6.0, true)
	match weapon_style:
		0:
			draw_circle(Vector2(-8, 3 + bob), 17.0, Color("b87d51"))
			draw_circle(Vector2(-8, 3 + bob), 12.0, Color("f3d9b1"))
			draw_circle(Vector2(-8, 3 + bob), 7.0, Color("8b5d48"))
		1:
			draw_circle(Vector2(-8, 3 + bob), 17.0, Color("3b4654"))
			draw_circle(Vector2(-8, 3 + bob), 12.0, Color("8996a0"))
		2:
			draw_colored_polygon(PackedVector2Array([Vector2(-26, 3 + bob), Vector2(-5, -10 + bob), Vector2(7, 3 + bob), Vector2(-5, 16 + bob)]), Color("66b5c1"))
			draw_circle(Vector2(-17, bob), 2.5, Color("101b30"))
