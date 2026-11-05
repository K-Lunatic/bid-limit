@tool
class_name SacredHand2D
extends Node2D

const ArtLayout = preload("res://scripts/art_layout.gd")
var sprite: Sprite2D
var elapsed := 0.0
var strike_time := 0.0
var last_hammer := 0

func _ready() -> void:
	sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite != null:
		z_index = 3
		if Engine.is_editor_hint(): set_process(false)
		return
	position = Vector2(1450,355)
	z_index = 3
	sprite = Sprite2D.new()
	sprite.texture = load("res://assets/npc/mending-glove-v2.png")
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.scale = Vector2.ONE * ArtLayout.ACTOR_DRAW_SCALE
	sprite.modulate = ArtLayout.ROOM_AMBIENT
	add_child(sprite)

func set_auction_state(state: Dictionary) -> void:
	var hammer := int(state.get("hammer",0))
	if hammer > last_hammer:
		strike_time = 0.5
	last_hammer = hammer

func _process(delta: float) -> void:
	elapsed += delta
	strike_time = maxf(0.0,strike_time-delta)
	var bob := roundf(sin(elapsed*1.5)*2.0)
	var strike := roundf(sin((0.5-strike_time)*PI/0.5)*12.0) if strike_time > 0.0 else 0.0
	sprite.position.y = (bob+strike)*ArtLayout.ACTOR_DRAW_SCALE
