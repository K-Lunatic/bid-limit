extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var scene := load("res://scenes/main_2d.tscn").instantiate() as Node
	root.add_child(scene)
	var lobby: Node = scene.get_node("TitleUI")
	var menu: VBoxContainer = lobby.get_node("Panel/TitleMenu")
	assert(lobby.title_menu == menu and lobby.content == menu)
	assert(menu.get_node("Identity/Nickname").max_length == 12)
	assert(menu.get_node("Identity/Nickname").text == str(lobby.profile.nickname))
	var count := menu.get_child_count()
	for index in 3:
		menu.get_node("HowToPlay").pressed.emit()
		assert(not menu.visible and lobby.content != menu)
		lobby.back_button.pressed.emit()
		assert(menu.visible and lobby.content == menu)
		menu.get_node("Customize").pressed.emit()
		assert(not menu.visible)
		lobby.back_button.pressed.emit()
		assert(menu.visible and menu.get_child_count() == count)
		assert(menu.get_node("Solo").get_signal_connection_list("pressed").size() == 1)
		await process_frame
	menu.get_node("RoomActions/CreateRoom").pressed.emit()
	assert(not menu.visible)
	lobby.back_button.pressed.emit()
	menu.get_node("Solo").pressed.emit()
	assert(scene.get("network").players.size() == 1)
	assert(not scene.get("started"))
	scene.queue_free()
	await process_frame
	print("Authored title UI: reusable menu, navigation, single signal connections and solo lobby: PASS")
	quit()
