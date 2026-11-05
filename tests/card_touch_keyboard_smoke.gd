extends SceneTree
const Fan = preload("res://scripts/card_fan_ui.gd")
const Game = preload("res://scripts/auction_game.gd")
const UI = preload("res://scripts/auction_ui.gd")
func touch(fan: Control, index: int, point: Vector2, pressed: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	fan._gui_input(event)
func _init() -> void: call_deferred("run")
func run() -> void:
	var game := Game.new()
	root.add_child(game)
	game.set_process(false)
	game.reset_cards()
	game.start_lot()
	game.active_player_ids = [1,100]
	game.turn_id = 1
	game.phase = "auction"
	game.hands[1] = [game.card_definition("attack"),game.card_definition("rumor"),game.card_definition("draw"),game.card_definition("shield"),game.card_definition("bid")]
	game._sync_local_hand()
	var ui := UI.new()
	root.add_child(ui)
	ui.setup(game)
	ui.render_state(game.state())
	var fan: Control = ui.card_fan
	var point: Vector2 = fan._card_transform(0,5).origin
	touch(fan,0,point,true)
	touch(fan,0,point,false)
	assert(fan.preview_index == 0 and ui.selected_indices.is_empty())
	assert(game.turn_id == 1)
	touch(fan,0,point,true)
	touch(fan,1,Vector2(300,20),true)
	assert(fan.drag_touch == 0)
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = fan.drop_zone().get_center()
	fan._gui_input(drag)
	touch(fan,1,Vector2(300,20),false)
	assert(fan.drag_touch == 0)
	touch(fan,0,drag.position,false)
	assert(ui.selected_indices == [0] and game.turn_id == 1)
	var key := InputEventKey.new()
	key.pressed = true
	key.keycode = KEY_5
	ui._unhandled_input(key)
	assert(ui.selected_indices == [4])
	key.keycode = KEY_ENTER
	ui._unhandled_input(key)
	assert(game.bid == 20 and game.leader == 1)
	assert(not ui.chat_composer.visible and ui.selected_indices.is_empty())
	ui.queue_free()
	game.queue_free()
	await process_frame
	print("Touch preview, multitouch ownership, drag staging, key 5 and Enter bid: PASS")
	quit()
