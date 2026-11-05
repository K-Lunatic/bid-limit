extends SceneTree
const Game = preload("res://scripts/auction_game.gd")
const Face = preload("res://scripts/card_face_ui.gd")
func _init() -> void: call_deferred("capture")
func capture() -> void:
	var background := ColorRect.new()
	background.size = Vector2(320,180)
	background.color = Color("403734")
	root.add_child(background)
	var game := Game.new()
	for index in 12:
		var face := Face.new()
		face.position = Vector2(6+index%6*53,4+index/6*90)
		face.size = Vector2(42,58)
		var caption := Label.new()
		if index < Game.MARKET_POOL.size():
			face.set_card(game.card_definition(Game.MARKET_POOL[index]))
			caption.text = str(face.card.name)
		else:
			face.back = true
			caption.text = "행동표 뒷면"
		background.add_child(face)
		caption.position = Vector2(2+index%6*53,64+index/6*90)
		caption.size = Vector2(50,20)
		caption.add_theme_font_size_override("font_size",5)
		caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		background.add_child(caption)
	await RenderingServer.frame_post_draw
	assert(root.get_texture().get_image().save_png("/private/tmp/bid-card-styles.png") == OK)
	game.free()
	background.queue_free()
	await process_frame
	print("11 card faces and shared button reverse captured: PASS")
	quit()
