extends SceneTree

const ArtLayout = preload("res://scripts/art_layout.gd")

func _init() -> void:
	assert(ArtLayout.ACTOR_FRAME_PIXELS == Vector2(96, 128))
	assert(ArtLayout.PIXEL_FRAME_SIZE == Vector2i(96, 128))
	assert(ArtLayout.BODY_BASELINE_PIXEL_Y == 113)
	assert(ArtLayout.MOUTH_ANCHOR_PIXEL == Vector2i(48, 70))
	assert(is_equal_approx(ArtLayout.ACTOR_SCREEN_SIZE.y, 64.0))
	assert(is_equal_approx(ArtLayout.ACTOR_DRAW_SCALE, ArtLayout.BACKGROUND_WORLD_SCALE))
	assert(is_equal_approx(ArtLayout.ACTOR_DRAW_SCALE * ArtLayout.CAMERA_ZOOM, 0.5))
	assert(ArtLayout.NEAR_EYE_PIXELS.size() == 8 and ArtLayout.FAR_EYE_PIXELS.size() == 8)
	assert(ArtLayout.SEAT_POSITIONS.size() == 4)
	assert(ArtLayout.carry_source(-1).x == -32.0)
	print("Art layout contract smoke test: PASS")
	quit()
