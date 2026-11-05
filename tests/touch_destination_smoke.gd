extends SceneTree

const TouchControls = preload("res://scripts/touch_controls.gd")

func _init() -> void:
	call_deferred("run_test")

func run_test() -> void:
	var controls := TouchControls.new()
	root.add_child(controls)
	var destinations: Array = []
	controls.destination_tapped.connect(func(point: Vector2) -> void: destinations.append(point))
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = Vector2(40, 80)
	touch.pressed = true
	controls._unhandled_input(touch)
	touch.pressed = false
	controls._unhandled_input(touch)
	assert(destinations == [Vector2(40, 80)])
	touch.pressed = true
	controls._unhandled_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = Vector2(60, 80)
	controls._unhandled_input(drag)
	touch.pressed = false
	touch.position = drag.position
	controls._unhandled_input(touch)
	assert(destinations.size() == 1)
	controls.free()
	print("Touch destination test: PASS")
	quit()
