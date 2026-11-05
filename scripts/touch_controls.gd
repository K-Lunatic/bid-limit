class_name BidTouchControls
extends CanvasLayer

signal move_changed(move: Vector2)
signal look_changed(delta: Vector2)
signal destination_tapped(screen_position: Vector2)

class TouchVisual extends Control:
	var left_start := Vector2.ZERO
	var left_current := Vector2.ZERO
	var right_start := Vector2.ZERO

	func _draw() -> void:
		if left_start != Vector2.ZERO:
			draw_circle(left_start, 48.0, Color(0.78, 0.65, 0.4, 0.16))
			draw_arc(left_start, 48.0, 0.0, TAU, 32, Color(0.9, 0.75, 0.45, 0.48), 2.0)
			draw_circle(left_current, 22.0, Color(0.95, 0.82, 0.52, 0.36))
		if right_start != Vector2.ZERO:
			draw_circle(right_start, 36.0, Color(0.45, 0.72, 0.9, 0.14))

var left_touch := -1
var right_touch := -1
var left_start := Vector2.ZERO
var left_current := Vector2.ZERO
var right_last := Vector2.ZERO
var right_start := Vector2.ZERO
var right_moved := false
var left_moved := false
var visual := TouchVisual.new()

func _ready() -> void:
	visual.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	visual.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(visual)

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.position.x < get_viewport().get_visible_rect().size.x * 0.5 and left_touch == -1:
				left_touch = event.index
				left_start = event.position
				left_current = event.position
				left_moved = false
				visual.left_start = left_start
				visual.left_current = left_current
			elif right_touch == -1:
				right_touch = event.index
				right_last = event.position
				right_start = event.position
				right_moved = false
				visual.right_start = event.position
		elif event.index == left_touch:
			if not left_moved:
				destination_tapped.emit(event.position)
			left_touch = -1
			left_start = Vector2.ZERO
			left_current = Vector2.ZERO
			visual.left_start = Vector2.ZERO
			move_changed.emit(Vector2.ZERO)
		elif event.index == right_touch:
			if not right_moved:
				destination_tapped.emit(event.position)
			right_touch = -1
			visual.right_start = Vector2.ZERO
		visual.queue_redraw()
	elif event is InputEventScreenDrag:
		if event.index == left_touch:
			left_current = event.position
			left_moved = left_moved or event.position.distance_to(left_start) > 8.0
			visual.left_current = left_current
			move_changed.emit((left_current - left_start).limit_length(72.0) / 72.0)
			visual.queue_redraw()
		elif event.index == right_touch:
			right_moved = right_moved or event.position.distance_to(right_start) > 8.0
			look_changed.emit(event.position - right_last)
			right_last = event.position
