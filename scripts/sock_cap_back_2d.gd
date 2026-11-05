@tool
class_name SockCapBack2D
extends Node2D

const CAP_TEXTURE = preload("res://assets/sprites/sock_puppet/accessories/knit-cap-v1.png")
var active := false

func set_active(value: bool) -> void:
	active = value
	queue_redraw()

func _draw() -> void:
	if not active:
		return
	draw_texture_rect_region(CAP_TEXTURE,Rect2(-24,-3,48,6),Rect2(0,22,48,6),Color(0.65,0.65,0.7))
