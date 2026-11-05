class_name PixelfxSprite2D
extends Node2D

var effect_id := ""
var sprite: AnimatedSprite2D

func play_effect(id: String, at: Vector2) -> void:
	effect_id = id
	position = at
	var base_name := id.get_file()
	var texture: Texture2D = load("res://assets/pixelfx/%s.png" % base_name)
	var data_file := FileAccess.open("res://assets/pixelfx/%s.json" % base_name, FileAccess.READ)
	if texture == null or data_file == null:
		queue_free()
		return
	var data = JSON.parse_string(data_file.get_as_text())
	var meta: Dictionary = data.get("meta", {}).get("pixelfx", {})
	var frame_size: Array = meta.get("frameSize", [64, 64])
	var pivot: Array = meta.get("pivot", [frame_size[0] / 2, frame_size[1] / 2])
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	frames.add_animation(base_name)
	frames.set_animation_speed(base_name, float(meta.get("fps", 30)))
	frames.set_animation_loop(base_name, bool(meta.get("loop", false)))
	var columns: int = meta.get("columns", 1)
	var frame_count: int = meta.get("frames", data.get("frames", []).size())
	for index in frame_count:
		var atlas := AtlasTexture.new()
		atlas.atlas = texture
		atlas.region = Rect2((index % columns) * frame_size[0], (index / columns) * frame_size[1], frame_size[0], frame_size[1])
		frames.add_frame(base_name, atlas)
	sprite = AnimatedSprite2D.new()
	sprite.sprite_frames = frames
	sprite.animation = base_name
	sprite.centered = false
	sprite.position = -Vector2(pivot[0], pivot[1])
	sprite.scale = Vector2(1.5, 1.5)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 30
	add_child(sprite)
	sprite.animation_finished.connect(queue_free)
	sprite.play()
