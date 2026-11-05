extends SceneTree
const Puppet = preload("res://scripts/sock_puppet_2d.gd")
const Layout = preload("res://scripts/art_layout.gd")
func own(node: Node, parent: Node, root_node: Node) -> void:
	parent.add_child(node)
	node.owner = root_node
func save_scene(node: Node, path: String) -> void:
	var scene := PackedScene.new()
	assert(scene.pack(node) == OK)
	assert(ResourceSaver.save(scene,path) == OK)
func _init() -> void:
	if FileAccess.file_exists("res://scenes/auction_world.tscn"):
		printerr("Authored scenes already exist. Edit them in Godot; this bootstrap will not overwrite them.")
		quit(1)
		return
	var puppet := Puppet.new()
	puppet.name = "SockPuppet"
	puppet.using_body_only = true
	var body := AnimatedSprite2D.new()
	body.name = "Body"
	body.position = Layout.SPRITE_OFFSET
	body.scale = Vector2.ONE*Layout.ACTOR_DRAW_SCALE
	body.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for clip in [["idle",[0,1,0,1],5.0,true],["waiting",[0,1,0,1],5.0,true],["walk",[0,1,0,1],8.0,true],["attack",[5,6,5,6],9.0,false],["bid",[5,6,5,6],7.0,false],["hurt",[0,5,0],7.0,false],["victory",[5,6],6.0,true]]:
		puppet._add_animation(frames,clip[0],clip[1],clip[2],clip[3])
	body.sprite_frames = frames
	body.animation = "idle"
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/sock_tint.gdshader")
	material.set_shader_parameter("sock_tint",puppet.sock_color)
	material.set_shader_parameter("hair_tint",puppet.hair_color)
	body.material = material
	own(body,puppet,puppet)
	var parts := load("res://scripts/sock_puppet_parts_2d.gd").new() as Node2D
	parts.name = "Parts"
	parts.position = body.position
	parts.scale = body.scale
	parts.z_index = 2
	parts.integrated_base = true
	own(parts,puppet,puppet)
	save_scene(puppet,"res://scenes/sock_puppet.tscn")
	puppet.free()
	var world := Node2D.new()
	world.name = "World"
	var seats := Node2D.new()
	seats.name = "Seats"
	own(seats,world,world)
	for index in 4:
		var marker := Marker2D.new()
		marker.name = "Seat%d" % (index+1)
		marker.position = Layout.SEAT_POSITIONS[index]
		own(marker,seats,world)
	var hall := load("res://scripts/auction_hall_2d.gd").new() as Node2D
	hall.name = "AuctionHall"
	own(hall,world,world)
	for row in [["Backdrop",0,-20,811],["SeatLayer",1,0,848],["Decorations",2,-5,885]]:
		var layer := load("res://scripts/auction_hall_layer_2d.gd").new() as Node2D
		layer.name = row[0]
		layer.layer_kind = row[1]
		layer.z_index = row[2]
		layer.decoration_seed = row[3]
		if row[1] == 1:
			for index in 4: layer.seat_markers.append(NodePath("../../Seats/Seat%d" % (index+1)))
		own(layer,hall,world)
	for entry in [["Appraiser","감정사 보빈",Vector2(320,520),Color("d5b58d"),Color("b9b0a1")],["Merchant","단추상 · 암시장",Vector2(2750,520),Color("408677"),Color("d4ad68")]]:
		var npc := load("res://scenes/sock_puppet.tscn").instantiate() as Node2D
		npc.name = entry[0]
		npc.position = entry[2]
		npc.puppet_name = entry[1]
		npc.sock_color = entry[3]
		npc.hair_color = entry[4]
		npc.chosen_accessory = 1
		var tint: ShaderMaterial = npc.get_node("Body").material.duplicate()
		tint.set_shader_parameter("sock_tint",entry[3])
		tint.set_shader_parameter("hair_tint",entry[4])
		npc.get_node("Body").material = tint
		npc.get_node("Parts").accessory = 1
		own(npc,world,world)
	var hand := load("res://scripts/sacred_hand_2d.gd").new() as Node2D
	hand.name = "Auctioneer"
	hand.position = Vector2(1450,355)
	hand.z_index = -1
	own(hand,world,world)
	var hand_sprite := Sprite2D.new()
	hand_sprite.name = "Sprite"
	hand_sprite.texture = load("res://assets/npc/sacred-hand-v1.png")
	hand_sprite.scale = Vector2.ONE*Layout.ACTOR_DRAW_SCALE
	hand_sprite.modulate = Layout.ROOM_AMBIENT
	hand_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	own(hand_sprite,hand,world)
	var monitor := load("res://scripts/lot_monitor_2d.gd").new() as Node2D
	monitor.name = "LotMonitor"
	monitor.position = Vector2(1450,205)
	monitor.z_index = 6
	own(monitor,world,world)
	var lot := load("res://scripts/auction_lot_2d.gd").new() as Node2D
	lot.name = "LotItem"
	lot.position = Layout.LOT_STAGE_POSITION
	lot.z_index = 4
	own(lot,world,world)
	var camera := Camera2D.new()
	camera.name = "GameCamera"
	camera.position = Vector2(1450,340)
	camera.zoom = Vector2.ONE*0.30
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	own(camera,world,world)
	save_scene(world,"res://scenes/auction_world.tscn")
	world.free()
	print("Editor scenes saved: persistent world + reusable puppet")
	quit()
