class_name TetherLink2D
extends Node2D

var source: Node2D
var target: Node2D
var source_offset := Vector2.ZERO
var target_offset := Vector2.ZERO
var line_color := Color("b64e61")
var thickness := 2.0
var max_length := 180.0

func bind(source_node: Node2D, target_node: Node2D, source_point := Vector2.ZERO, target_point := Vector2.ZERO) -> void:
	source = source_node
	target = target_node
	source_offset = source_point
	target_offset = target_point
	queue_redraw()

func _process(_delta: float) -> void:
	queue_redraw()

func _draw() -> void:
	if not is_instance_valid(source) or not is_instance_valid(target):
		return
	var a := source.global_position + source_offset
	var b := target.global_position + target_offset
	var delta := b - a
	if delta.length() > max_length:
		b = a + delta.normalized() * max_length
	draw_line(to_local(a), to_local(b), line_color, thickness, true)
