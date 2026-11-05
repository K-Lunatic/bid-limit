extends SceneTree
func _init() -> void: call_deferred("run")
func run() -> void:
	var packed := load("res://scenes/main_2d.tscn") as PackedScene
	var scene := packed.instantiate()
	assert(scene.get_node("World/AuctionHall/Backdrop") != null)
	assert(scene.get_node("World/Appraiser/Body") is AnimatedSprite2D)
	assert(scene.get_node("World/Merchant/Parts") != null)
	assert(scene.get_node("World/Auctioneer/Sprite").texture != null)
	assert(scene.get_node("World/AuctionHall/Backdrop").z_index < scene.get_node("World/AuctionHall/Decorations").z_index)
	assert(scene.get_node("World/AuctionHall/Decorations").z_index < scene.get_node("World/AuctionHall/SeatLayer").z_index)
	assert(scene.get_node("World/Auctioneer").z_index > scene.get_node("World/AuctionHall/SeatLayer").z_index)
	assert(scene.get_node("World/LotItem").z_index > scene.get_node("World/Auctioneer").z_index)
	assert(scene.get_node("World/LotMonitor").z_index > scene.get_node("World/LotItem").z_index)
	var marker := scene.get_node("World/Seats/Seat1") as Marker2D
	marker.position += Vector2(20,0)
	root.add_child(scene)
	var network: Node = scene.get("network")
	assert(network.seat_positions[0] == marker.global_position)
	assert(network.create_host() == OK)
	scene.start_game()
	assert(scene.get("hall") == scene.get_node("World/AuctionHall"))
	assert(scene.get("appraiser") == scene.get_node("World/Appraiser"))
	assert(network.claim_seat(1,0))
	assert(network.players[1].position == marker.global_position)
	await process_frame
	assert(scene.get("player").get_node("Body") == scene.get("player").pixel_sprite)
	assert(scene.get("player").get_children().filter(func(child: Node) -> bool: return child is AnimatedSprite2D).size() == 1)
	scene.queue_free()
	await process_frame
	print("Authored world and puppet scenes, runtime reuse, editable seat markers, no duplicate body: PASS")
	quit()
