@tool
class_name SockPuppet2D
extends CharacterBody2D

const TetherScript = preload("res://scripts/tether_link_2d.gd")
const CardArcScript = preload("res://scripts/card_arc_2d.gd")
const PartsScript = preload("res://scripts/sock_puppet_parts_2d.gd")
const SockTint = preload("res://shaders/sock_tint.gdshader")
const ArtLayout = preload("res://scripts/art_layout.gd")
const BODY_ONLY_FRAME_DIR := "res://assets/sprites/sock_puppet/cozy_v3/frames/"
const LEGACY_FRAME_DIR := "res://assets/sprites/sock_puppet/frames/"

signal strike_landed

@export var sock_color := Color("d95b68"):
	set(value):
		sock_color = value
		if pixel_sprite != null and pixel_sprite.material is ShaderMaterial:
			pixel_sprite.material.set_shader_parameter("sock_tint",value)
@export var hair_color := Color("35a7d7"):
	set(value):
		hair_color = value
		if pixel_sprite != null and pixel_sprite.material is ShaderMaterial:
			pixel_sprite.material.set_shader_parameter("hair_tint",value)
		if parts != null: parts.call("configure",hair_color,chosen_hair_style,chosen_accessory)
@export var puppet_name := "BIDDER"
var is_current_turn := false
var is_player := false
var ai_phase := 0.0
var ai_style := 0
var animation_time := 0.0
var reaction := 0.0
var speech := ""
var speech_time := 0.0
var visual_tilt := 0.0
var visual_squash := 0.0
var previous_velocity := Vector2.ZERO
var attack_clock := -1.0
var pixel_sprite: AnimatedSprite2D
var current_animation := ""
var external_input := Vector2.ZERO
var facing := 1
var remote_moving := false
var turn_clock := 0.0
var turn_from_facing := 1
var target_facing := 1
var card_arc: Node2D
var parts: Node2D
@export var chosen_hair_style := 0:
	set(value):
		chosen_hair_style = value
		if parts != null: parts.call("configure",hair_color,chosen_hair_style,chosen_accessory)
@export var chosen_accessory := 0:
	set(value):
		chosen_accessory = value
		if parts != null: parts.call("configure",hair_color,chosen_hair_style,chosen_accessory)
var action_state := "waiting"
var action_clock := 0.0
var queued_action := ""
var queued_duration := 0.0
var using_body_only := false

func _ready() -> void:
	# The authored concept frames are the visual source; physics remains independent.
	using_body_only = ResourceLoader.exists(BODY_ONLY_FRAME_DIR + "00.png")
	pixel_sprite = get_node_or_null("Body") as AnimatedSprite2D
	if pixel_sprite == null:
		pixel_sprite = AnimatedSprite2D.new()
		pixel_sprite.name = "Body"
		var frames := SpriteFrames.new()
		frames.remove_animation("default")
		_add_animation(frames, "waiting", [1], 1.0, true)
		_add_animation(frames, "idle", [1], 1.0, true)
		_add_animation(frames, "walk", [1], 1.0, true)
		_add_animation(frames, "turn", [1, 5, 1, 5, 1], 12.0, false)
		_add_animation(frames, "steal", [1, 5, 6, 5, 1], 9.0, false)
		_add_animation(frames, "coin", [1, 5, 0, 5, 1], 8.0, false)
		_add_animation(frames, "talk", [1,0,1,6], 7.0, true)
		_add_animation(frames, "attack", [5, 6, 5, 6], 9.0, false)
		_add_animation(frames, "bid", [5, 6, 5, 6], 7.0, false)
		_add_animation(frames, "hurt", [0, 5, 0], 7.0, false)
		_add_animation(frames, "victory", [5, 6], 6.0, true)
		pixel_sprite.sprite_frames = frames
		add_child(pixel_sprite)
	pixel_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	pixel_sprite.animation = "idle"
	var tint := ShaderMaterial.new()
	tint.shader = SockTint
	tint.set_shader_parameter("sock_tint", sock_color)
	tint.set_shader_parameter("hair_tint", hair_color)
	tint.set_shader_parameter("room_light", ArtLayout.ROOM_AMBIENT)
	pixel_sprite.material = tint
	pixel_sprite.play()
	parts = get_node_or_null("Parts")
	if parts == null:
		parts = PartsScript.new()
		parts.name = "Parts"
		parts.z_index = 2
		add_child(parts)
	parts.modulate = ArtLayout.ROOM_AMBIENT
	parts.call("set_integrated_base", using_body_only)
	parts.call("configure", hair_color, chosen_hair_style, chosen_accessory)
	if Engine.is_editor_hint():
		pixel_sprite.stop()
		pixel_sprite.position = ArtLayout.SPRITE_OFFSET
		pixel_sprite.scale = Vector2.ONE*ArtLayout.ACTOR_DRAW_SCALE
		parts.position = pixel_sprite.position
		parts.scale = pixel_sprite.scale
		set_physics_process(false)
		return
	card_arc = CardArcScript.new()
	card_arc.z_index = 5
	add_child(card_arc)
	card_arc.visible = not is_player

func _add_animation(frames: SpriteFrames, name: String, indexes: Array, speed: float, loop: bool) -> void:
	frames.add_animation(name)
	frames.set_animation_speed(name, speed)
	frames.set_animation_loop(name, loop)
	for index in indexes:
		var frame_dir := BODY_ONLY_FRAME_DIR if using_body_only else LEGACY_FRAME_DIR
		var texture := load(frame_dir + "%02d.png" % int(index)) as Texture2D
		if texture != null:
			frames.add_frame(name, texture)

func setup(label: String, color: Color, hair: Color, player := false, style := 0, hair_style := 0, accessory_style := 0) -> void:
	puppet_name = label
	set_sock_color(color)
	set_hair_color(hair)
	is_player = player
	ai_style = style
	chosen_hair_style = hair_style
	chosen_accessory = accessory_style
	target_facing = facing
	ai_phase = float(style) * 1.65 + (0.0 if player else 0.35)
	if parts != null:
		parts.call("configure", hair_color, hair_style, accessory_style)
	if card_arc != null:
		card_arc.visible = not is_player
	position.y = ArtLayout.FLOOR_Y
	queue_redraw()

func set_external_input(value: Vector2) -> void:
	external_input = value.limit_length(1.0)

func turn_to(direction: int) -> void:
	var next_facing := 1 if direction >= 0 else -1
	if next_facing == target_facing:
		return
	turn_from_facing = facing
	target_facing = next_facing
	turn_clock = 0.34
	current_animation = ""
	queue_redraw()

func set_card_count(count: int, selected := 0) -> void:
	if card_arc != null:
		card_arc.call("set_count", count, selected)

func set_accessory(hair_style: int, accessory_style: int) -> void:
	chosen_hair_style = hair_style
	chosen_accessory = accessory_style
	if parts != null:
		parts.call("configure", hair_color, hair_style, accessory_style)

func set_hair_color(color: Color) -> void:
	hair_color = color
	if pixel_sprite != null and pixel_sprite.material is ShaderMaterial:
		pixel_sprite.material.set_shader_parameter("hair_tint", color)
	if parts != null:
		parts.call("configure",hair_color,chosen_hair_style,chosen_accessory)

func set_sock_color(color: Color) -> void:
	sock_color = color
	if pixel_sprite != null and pixel_sprite.material is ShaderMaterial:
		pixel_sprite.material.set_shader_parameter("sock_tint", color)

func play_action(state: String, duration := 0.62) -> void:
	if action_clock > 0.0 and action_state != "waiting" and action_state != state:
		queued_action = state
		queued_duration = duration
		return
	action_state = state
	action_clock = duration
	if parts != null:
		parts.call("set_motion", state)
	if pixel_sprite != null:
		_set_pixel_animation(state if state != "waiting" else "waiting")

func _physics_process(delta: float) -> void:
	animation_time += delta
	if speech_time > 0.0:
		speech_time -= delta
		if speech_time <= 0.0:
			speech = ""
	if action_clock > 0.0:
		action_clock = maxf(0.0, action_clock - delta)
		if action_clock <= 0.0:
			if not queued_action.is_empty():
				var next_action := queued_action
				var next_duration := queued_duration
				queued_action = ""
				queued_duration = 0.0
				play_action(next_action, next_duration)
			else:
				action_state = "waiting"
	if reaction > 0.0:
		reaction -= delta
	if turn_clock > 0.0:
		var was_before_half := turn_clock > 0.17
		turn_clock = maxf(0.0, turn_clock - delta)
		if was_before_half and turn_clock <= 0.17:
			facing = target_facing
		if turn_clock <= 0.0:
			facing = target_facing
	if attack_clock >= 0.0:
		attack_clock -= delta
		if attack_clock <= 0.18 and attack_clock + delta > 0.18:
			strike_landed.emit()
		if attack_clock < 0.0:
			attack_clock = -1.0
	if is_player and int(get_meta("seat",-1)) < 0:
		var axis := external_input.x
		if absf(axis) < 0.001 and not get_viewport().gui_get_focus_owner() is LineEdit:
			axis = float(Input.is_physical_key_pressed(KEY_RIGHT) or Input.is_physical_key_pressed(KEY_D)) - float(Input.is_physical_key_pressed(KEY_LEFT) or Input.is_physical_key_pressed(KEY_A))
		var desired_speed := axis * 330.0
		if absf(axis) > 0.05:
			turn_to(1 if axis > 0 else -1)
		velocity.x = move_toward(velocity.x, desired_speed, delta * 1800.0)
	else:
		velocity.x = 0.0
	velocity.y = 0.0
	move_and_slide()
	position.x = clampf(position.x, ArtLayout.WORLD_X_MARGIN, ArtLayout.WORLD_WIDTH - ArtLayout.WORLD_X_MARGIN)
	var acceleration := (velocity.x - previous_velocity.x) / maxf(delta, 0.001)
	visual_tilt = lerpf(visual_tilt, clampf(-acceleration * 0.00004, -0.12, 0.12), 1.0 - exp(-delta * 9.0))
	visual_squash = lerpf(visual_squash, clampf(abs(acceleration) * 0.000025, 0.0, 0.08), 1.0 - exp(-delta * 11.0))
	previous_velocity = velocity
	if pixel_sprite != null:
		var bob := sin(animation_time * (1.8 + ai_style * 0.18) + ai_phase) * (1.2 + ai_style * 0.25)
		# Keep the physics root smooth, but put the drawn sprite on the half-screen-pixel world grid.
		var grid_x := snappedf(global_position.x, ArtLayout.ACTOR_DRAW_SCALE) - global_position.x
		var bob_pixel := roundf(bob * 0.22)
		pixel_sprite.position = ArtLayout.SPRITE_OFFSET + Vector2(grid_x, bob_pixel)
		pixel_sprite.rotation = 0.0
		var draw_facing := facing
		var turn_width := 1.0
		if turn_clock > 0.0:
			var turn_progress := 1.0 - turn_clock / 0.34
			draw_facing = turn_from_facing if turn_progress < 0.5 else target_facing
			# Discrete widths preserve the pixel silhouette while the sock turns.
			turn_width = 1.0 if turn_progress < 0.2 or turn_progress > 0.8 else (0.62 if turn_progress < 0.5 else 0.42)
		pixel_sprite.scale = Vector2(ArtLayout.ACTOR_DRAW_SCALE * draw_facing * turn_width, ArtLayout.ACTOR_DRAW_SCALE)
		if parts != null:
			parts.position = pixel_sprite.position
			parts.rotation = pixel_sprite.rotation
			parts.scale = pixel_sprite.scale
			var texture := pixel_sprite.sprite_frames.get_frame_texture(pixel_sprite.animation, pixel_sprite.frame)
			parts.call("set_source_frame", texture.resource_path.get_file().get_basename().to_int())
		if attack_clock >= 0.0:
			_set_pixel_animation("attack")
		elif reaction > 0.0:
			_set_pixel_animation("hurt")
		elif turn_clock > 0.0:
			_set_pixel_animation("turn")
		elif action_clock > 0.0:
			_set_pixel_animation(action_state)
		elif speech_time > 0.0:
			_set_pixel_animation("talk")
		elif absf(velocity.x) > 12.0 or (not is_player and remote_moving):
			_set_pixel_animation("walk")
		else:
			_set_pixel_animation("waiting")
		if not pixel_sprite.is_playing() and (action_clock <= 0.0 or action_state == "waiting" or action_state == "walk"):
			pixel_sprite.play()
	queue_redraw()

func _set_pixel_animation(name: String) -> void:
	if current_animation == name:
		return
	current_animation = name
	pixel_sprite.play(name)

func react(message: String) -> void:
	reaction = 0.7
	speech = message
	speech_time = 2.0
	play_action("hurt", 0.45)
	queue_redraw()

func attack() -> void:
	if attack_clock >= 0.0:
		return
	attack_clock = 0.46
	speech = "간다!"
	speech_time = 2.0
	play_action("attack", 0.46)
	queue_redraw()

func say(message: String) -> void:
	speech = message.left(40)
	speech_time = 6.0
	queue_redraw()

func _draw() -> void:
	var bob := sin(animation_time * 2.0 + ai_phase) * 5.0
	var tilt := visual_tilt + sin(animation_time * 1.4 + ai_phase) * 0.035
	if attack_clock >= 0.0:
		tilt -= sin((0.36 - attack_clock) / 0.36 * PI) * 0.16
	if reaction > 0.0:
		bob += sin(reaction * 40.0) * 5.0
	if is_current_turn:
		draw_ellipse_custom(Vector2(0,38),Vector2(72,18),Color("d8b963"))
		draw_string(ThemeDB.fallback_font,Vector2(-58,-220),"▼ 현재 차례",HORIZONTAL_ALIGNMENT_CENTER,116,12,Color("ffe69c"))
	if pixel_sprite != null:
		draw_ellipse_custom(Vector2(0, 38), Vector2(66, 15), Color(0.02, 0.025, 0.07, 0.28))
		if not speech.is_empty():
			draw_speech_bubble()
		draw_string(ThemeDB.fallback_font, Vector2(-58, -155), puppet_name, HORIZONTAL_ALIGNMENT_CENTER, 116, 13, Color("f6d9a1"))
		return
	draw_set_transform(Vector2(0, bob), tilt, Vector2(1.0 + visual_squash, 1.0 - visual_squash))
	# Shadow and the one continuous sock tube: no torso, arms, or robot joints.
	draw_ellipse_custom(Vector2(0, 38), Vector2(66, 15), Color(0.02, 0.025, 0.07, 0.28))
	var body := PackedVector2Array([Vector2(-48, 22), Vector2(-60, -48), Vector2(-51, -128), Vector2(-35, -164), Vector2(0, -176), Vector2(35, -164), Vector2(51, -128), Vector2(60, -48), Vector2(48, 22)])
	draw_colored_polygon(body, sock_color)
	draw_polyline(body + PackedVector2Array([body[0]]), sock_color.darkened(0.36), 5.0, false)
	# Ribbed cuff and soft, uneven fabric folds.
	for index in 5:
		var y := -8.0 + index * 7.0
		draw_line(Vector2(-47, y), Vector2(47, y + sin(index * 2.1) * 2.0), sock_color.lightened(0.18), 3.0)
	for index in 8:
		var x := -40.0 + index * 11.0
		var fold := PackedVector2Array([Vector2(x, -38), Vector2(x + sin(index * 4.0) * 7.0, -78), Vector2(x - 3.0, -120)])
		draw_polyline(fold, sock_color.darkened(0.18), 2.5)
	# The folded mouth clearly shows the hand inside the sock.
	var mouth := PackedVector2Array([Vector2(-42, -95), Vector2(-28, -111), Vector2(0, -116), Vector2(28, -111), Vector2(42, -95), Vector2(27, -73), Vector2(0, -66), Vector2(-27, -73)])
	draw_colored_polygon(mouth, Color("241923"))
	draw_polyline(mouth + PackedVector2Array([mouth[0]]), Color("6e2638"), 4.0, true)
	for tooth_x in [-22.0, -8.0, 8.0, 22.0]:
		draw_rect(Rect2(tooth_x - 4.0, -107.0, 8.0, 10.0), Color("f4dfbc"))
	# Button eyes, yarn hair, and silly loose strands.
	for eye_x in [-23.0, 23.0]:
		draw_circle(Vector2(eye_x, -142), 13.0, Color("f4eadc"))
		draw_circle(Vector2(eye_x + sin(animation_time * 1.3) * 2.0, -142), 4.8, Color("26334d"))
	for strand in 7:
		var hair_x := -43.0 + strand * 14.0
		draw_line(Vector2(hair_x, -168), Vector2(hair_x + sin(animation_time * 1.2 + strand) * 8.0, -195 - (strand % 2) * 12.0), hair_color, 5.0)
	if not speech.is_empty():
		draw_style_box(make_bubble(), Rect2(-82, -245, 164, 42))
		draw_multiline_string(ThemeDB.fallback_font, Vector2(-73, -229), speech.left(24), HORIZONTAL_ALIGNMENT_LEFT, 146, 10, 2, Color("fff5dc"))
	draw_string(ThemeDB.fallback_font, Vector2(-58, -220), puppet_name, HORIZONTAL_ALIGNMENT_CENTER, 116, 11, Color("f6d9a1"))

func draw_ellipse_custom(center: Vector2, radius: Vector2, color: Color) -> void:
	var points := PackedVector2Array()
	for index in 24:
		var angle := TAU * float(index) / 24.0
		points.append(center + Vector2(cos(angle) * radius.x, sin(angle) * radius.y))
	draw_colored_polygon(points, color)

func make_bubble() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color("29324a")
	box.border_color = Color("d9a35d")
	box.set_border_width_all(2)
	box.corner_radius_top_left = 12
	box.corner_radius_top_right = 12
	box.corner_radius_bottom_left = 12
	box.corner_radius_bottom_right = 12
	return box

func draw_speech_bubble() -> void:
	var font := ThemeDB.fallback_font
	var text_size := font.get_multiline_string_size(speech, HORIZONTAL_ALIGNMENT_LEFT, 146, 12, 4)
	var height := text_size.y + 12.0
	draw_style_box(make_bubble(), Rect2(-82, -178 - height, 164, height))
	draw_multiline_string(font, Vector2(-73, -178 - height + font.get_ascent(12) + 6), speech, HORIZONTAL_ALIGNMENT_LEFT, 146, 12, 4, Color("fff5dc"))
