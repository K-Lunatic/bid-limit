extends SceneTree

const PARTS := [
	"mouth_closed", "mouth_open", "mouth_wide", "eyes_buttons", "hair_blue",
	"glasses_round", "cap_red", "badge_gold"
]

func _init() -> void:
	var ok := true
	var body := load("res://assets/sprites/sock_puppet/frames/00.png") as Texture2D
	print("body frame 00 size=%s used=%s" % [body.get_size(), body.get_image().get_used_rect()])
	for frame_index in 8:
		var body_only := Image.load_from_file(ProjectSettings.globalize_path("res://assets/sprites/sock_puppet/cozy_v3/frames/%02d.png" % frame_index))
		if body_only == null or body_only.get_size() != Vector2i(96, 128):
			push_error("body-only frame contract failed: %02d" % frame_index)
			ok = false
			continue
		if body_only.get_pixel(0, 0).a > 0.0:
			push_error("body-only frame has opaque corner: %02d" % frame_index)
			ok = false
		print("body-only %02d size=%s used=%s" % [frame_index, body_only.get_size(), body_only.get_used_rect()])
	for part_id in PARTS:
		var texture := load("res://assets/sprites/sock_puppet/parts/v2/%s.png" % part_id) as Texture2D
		if texture == null:
			push_error("missing part: %s" % part_id)
			ok = false
			continue
		var image := texture.get_image()
		var used := image.get_used_rect()
		assert(image.get_format() == Image.FORMAT_RGBA8 or image.get_format() == Image.FORMAT_RGBAF)
		assert(used.size.x > 0 and used.size.y > 0)
		if image.get_pixel(0, 0).a > 0.0:
			push_error("part has opaque corner: %s" % part_id)
			ok = false
		print("part %-14s size=%-12s used=%s" % [part_id, texture.get_size(), used])
	if not ok:
		quit(1)
		return
	print("Pixel parts inspection: PASS")
	quit()
