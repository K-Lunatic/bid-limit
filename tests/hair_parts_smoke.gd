extends SceneTree
const Parts = preload("res://scripts/sock_puppet_parts_2d.gd")
const Layout = preload("res://scripts/art_layout.gd")
func _init() -> void:
	var silhouettes: Array[PackedByteArray] = []
	for texture in Parts.HAIRSTYLES:
		var hair: Image = texture.get_image()
		assert(hair.get_size() == Vector2i(64,48))
		assert(not silhouettes.has(hair.get_data()),"Hairstyles must be visibly different assets")
		silhouettes.append(hair.get_data())
		for frame in 8:
			var body: Image = load("res://assets/sprites/sock_puppet/cozy_v3/frames/%02d.png" % frame).get_image()
			var origin := Vector2i(Vector2(Layout.NEAR_EYE_PIXELS[frame])+Parts.HAIR_OFFSET-Parts.HAIR_ROOT)
			var overlap := 0
			for y in 48:
				for x in 64:
					var alpha := hair.get_pixel(x,y).a
					assert(alpha == 0.0 or alpha == 1.0)
					if alpha == 0: continue
					var point := origin+Vector2i(x,y)
					assert(Rect2i(0,0,96,128).has_point(point),"Hair leaves source canvas")
					if body.get_pixelv(point).a > 0: overlap += 1
			assert(overlap > 10,"Hair root floats away from head at frame %d" % frame)
	print("3 distinct hair parts, binary pixels, all 8 frames touch head inside canvas: PASS")
	quit()
