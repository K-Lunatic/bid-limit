@tool
class_name SockPuppetParts2D
extends Node2D

const CAP_TEXTURE = preload("res://assets/sprites/sock_puppet/accessories/knit-cap-v1.png")
const CapBackScript = preload("res://scripts/sock_cap_back_2d.gd")
const ArtLayout = preload("res://scripts/art_layout.gd")
const HAIRSTYLES := [preload("res://assets/sprites/sock_puppet/hair/0.png"),preload("res://assets/sprites/sock_puppet/hair/1.png"),preload("res://assets/sprites/sock_puppet/hair/2.png")]
const HAIR_NAMES := ["쓸어 넘긴 실머리","짧은 곱슬머리","높은 묶음머리"]
const HAIR_ROOT := Vector2(32,46)
const HAIR_OFFSET := Vector2(-15,2)
var hair_sprite: Sprite2D

@export var hair_color := Color("35a7d7")
var eye_color := Color("26334d")
@export var hair_style := 0
@export var accessory := 0
var motion_state := "waiting"
var blink_clock := 1.8
var phase := 0.0
@export var integrated_base := false
var cap_back: Node2D
var frame_index := 0

func set_source_frame(index: int) -> void:
	frame_index = clampi(index, 0, 7)
	var near_eye: Vector2 = Vector2(ArtLayout.NEAR_EYE_PIXELS[frame_index]) - Vector2(48,64)
	if cap_back != null:
		cap_back.position = near_eye + Vector2(ArtLayout.CAP_OFFSET_PIXEL)
	if hair_sprite != null:
		hair_sprite.position = near_eye+HAIR_OFFSET-HAIR_ROOT
	queue_redraw()

func _ready() -> void:
	hair_sprite = Sprite2D.new()
	hair_sprite.name = "YarnHair"
	hair_sprite.centered = false
	hair_sprite.z_index = -4
	hair_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var tint := ShaderMaterial.new()
	tint.shader = preload("res://shaders/sock_tint.gdshader")
	tint.set_shader_parameter("hair_only",true)
	tint.set_shader_parameter("room_light",Color.WHITE)
	hair_sprite.material = tint
	add_child(hair_sprite)
	cap_back = CapBackScript.new()
	cap_back.z_index = -3
	add_child(cap_back)
	configure(hair_color,hair_style,accessory)
	set_source_frame(0)

func set_integrated_base(value: bool) -> void:
	integrated_base = value
	if hair_sprite != null: hair_sprite.visible = integrated_base
	if cap_back != null:
		cap_back.call("set_active", integrated_base and accessory == 2)
	queue_redraw()

func configure(hair: Color, style: int, accessory_style: int) -> void:
	hair_color = hair
	hair_style = posmod(style, 3)
	accessory = posmod(accessory_style, 4)
	if hair_sprite != null:
		hair_sprite.texture = HAIRSTYLES[hair_style]
		hair_sprite.material.set_shader_parameter("hair_tint",hair_color)
		hair_sprite.visible = integrated_base
	if cap_back != null:
		cap_back.call("set_active", integrated_base and accessory == 2)
	queue_redraw()

func set_motion(state: String) -> void:
	motion_state = state
	queue_redraw()

func _process(delta: float) -> void:
	if Engine.is_editor_hint(): return
	phase += delta
	blink_clock -= delta
	if blink_clock <= 0.0:
		blink_clock = 2.2 + fmod(phase * 0.37, 2.8)
	queue_redraw()

func _draw() -> void:
	# This layer owns reusable hair/eye/accessory variations; the base sprite owns the sock silhouette.
	var blink := blink_clock < 0.12
	var eye_y := -18.0
	if not integrated_base:
		if blink:
			for eye_x in [-17.0, 17.0]:
				draw_line(Vector2(eye_x - 5, eye_y), Vector2(eye_x + 5, eye_y), eye_color, 2.0, true)
		else:
			for eye_x in [-17.0, 17.0]:
				draw_circle(Vector2(eye_x, eye_y), 3.2, eye_color)
		# Yarn highlights stay attached to the sprite root and change only by style.
		for strand in 5:
			var x := -28.0 + strand * 14.0
			var lift := -42.0 - float((strand + hair_style) % 2) * 5.0
			draw_line(Vector2(x, -31), Vector2(x + sin(phase * 1.2 + strand) * 2.0, lift), hair_color, 2.0, true)
	if accessory == 1:
		if integrated_base:
			var near_eye := Vector2(ArtLayout.NEAR_EYE_PIXELS[frame_index]) - Vector2(48,64)
			var far_eye := Vector2(ArtLayout.FAR_EYE_PIXELS[frame_index]) - Vector2(48,64)
			draw_arc(near_eye, 8.0, 0.0, TAU, 16, Color("e7be77"), 1.0, false)
			draw_arc(far_eye, 4.0, 0.0, TAU, 12, Color("e7be77"), 1.0, false)
			draw_line(near_eye + Vector2(8,0), far_eye - Vector2(4,0), Color("e7be77"), 1.0, false)
		else:
			draw_line(Vector2(-25, eye_y - 1), Vector2(-7, eye_y - 1), Color("d8ecf1"), 2.0, true)
			draw_line(Vector2(7, eye_y - 1), Vector2(25, eye_y - 1), Color("d8ecf1"), 2.0, true)
			draw_line(Vector2(-7, eye_y - 1), Vector2(7, eye_y - 1), Color("d8ecf1"), 1.0, true)
	elif accessory == 2:
		var crown := Vector2(ArtLayout.NEAR_EYE_PIXELS[frame_index]) - Vector2(48,64) + Vector2(ArtLayout.CAP_OFFSET_PIXEL)
		draw_texture(CAP_TEXTURE,crown-Vector2(ArtLayout.CAP_ANCHOR_PIXEL))
	elif accessory == 3:
		draw_circle(Vector2(28, 18), 6.0, Color("f0c47c"))
		draw_circle(Vector2(28, 18), 3.0, Color("8c4e70"))
