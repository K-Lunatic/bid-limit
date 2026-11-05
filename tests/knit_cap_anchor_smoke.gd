extends SceneTree
const Layout = preload("res://scripts/art_layout.gd")
const Parts = preload("res://scripts/sock_puppet_parts_2d.gd")
func _init() -> void:
	var cap: Image = load("res://assets/sprites/sock_puppet/accessories/knit-cap-v1.png").get_image()
	assert(cap.get_size() == Vector2i(48,28))
	for frame in 8:
		var body: Image = load("res://assets/sprites/sock_puppet/cozy_v3/frames/%02d.png" % frame).get_image()
		var origin: Vector2i = Layout.NEAR_EYE_PIXELS[frame]+Layout.CAP_OFFSET_PIXEL-Layout.CAP_ANCHOR_PIXEL
		var overlap := 0
		var hair_origin := Vector2(Layout.NEAR_EYE_PIXELS[frame])+Parts.HAIR_OFFSET-Parts.HAIR_ROOT
		var hair: Image = Parts.HAIRSTYLES[0].get_image()
		for y in 28:
			for x in 48:
				var alpha := cap.get_pixel(x,y).a
				assert(alpha == 0.0 or alpha == 1.0)
				if alpha == 0.0: continue
				var point := origin+Vector2i(x,y)
				assert(Vector2(point-Layout.NEAR_EYE_PIXELS[frame]).length() > 4)
				assert(Vector2(point-Layout.FAR_EYE_PIXELS[frame]).length() > 3)
				if Rect2i(0,0,96,128).has_point(point):
					var color := body.get_pixelv(point)
					var hair_point := point-Vector2i(hair_origin)
					if color.a > 0 or (Rect2i(0,0,64,48).has_point(hair_point) and hair.get_pixelv(hair_point).a > 0): overlap += 1
		assert(overlap > 10, "Cap does not meet yarn at frame %d" % frame)
	print("Knit cap: binary alpha, 8-frame contact, button-eye clearance: PASS")
	quit()
