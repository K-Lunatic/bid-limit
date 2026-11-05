extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
const UI = preload("res://scripts/auction_ui.gd")
const Face = preload("res://scripts/card_face_ui.gd")
func _init() -> void: call_deferred("run")
func run() -> void:
	var stage := SubViewport.new()
	stage.size = Vector2i(320,180)
	root.add_child(stage)
	var game := Game.new()
	stage.add_child(game)
	game.set_process(false)
	var ui := UI.new()
	stage.add_child(ui)
	ui.setup(game)
	ui.set_market_access(true)
	ui.open_market()
	await process_frame
	var font := ThemeDB.fallback_font
	ui.card_fan.set_cards(Game.MARKET_POOL.slice(0,5).map(func(id: String) -> Dictionary: return game.card_definition(id)),[])
	for index in 5:
		var transform: Transform2D = ui.card_fan._card_transform(index,5)
		for point in [Vector2(-21,-29),Vector2(21,-29),Vector2(-21,29),Vector2(21,29)]:
			var projected: Vector2 = transform*(point*ui.card_fan.CARD_SCALE)
			assert(Rect2(0,0,320,180).has_point(projected),"Resting card %d corner=%s projected=%s viewport=%s" % [index,point,projected,ui.card_fan.get_viewport_rect()])
	for id in Game.MARKET_POOL:
		var card := game.card_definition(id)
		assert(Face.ART_INDEX.has(id) and Face.COLORS.has(card.kind))
		assert(font.get_string_size(card.label,HORIZONTAL_ALIGNMENT_LEFT,-1,5).x <= 23,"Header overlaps cost: "+id)
		assert(font.get_string_size(card.summary,HORIZONTAL_ALIGNMENT_LEFT,-1,5).x <= 32,"Effect leaves frame: "+id)
		game.market_offers[1] = [id,id,id]
		ui.render_state(game.state())
		ui._process(1)
		ui.market_products[0].pressed.emit()
		await process_frame
		await process_frame
		assert(ui.market_background.get_global_rect().encloses(ui.market_panel.get_global_rect()),"Shop content leaves its frame: "+id+str(ui.market_panel.get_global_rect()))
		assert(ui.market_products[0].get_node("Picture").card.name == card.name)
	ui.deck_builder.toggle()
	await process_frame
	await process_frame
	assert(Rect2(0,0,320,180).encloses(ui.deck_builder.get_global_rect()),"Deck content leaves viewport")
	ui.queue_free()
	game.queue_free()
	stage.queue_free()
	await process_frame
	print("11 card labels/effects fit; shop details and deck remain inside frames: PASS")
	quit()
