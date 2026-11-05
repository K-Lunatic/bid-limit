@tool
class_name AuctionHall2D
extends Node2D

const LayerScript = preload("res://scripts/auction_hall_layer_2d.gd")
var seat_occupants: Dictionary = {}

func _ready() -> void:
	if get_child_count() > 0: return
	# Separate depth layers keep the Perlin-built hall editable and readable.
	for descriptor in [[0, -20], [2, -10], [1, 0]]:
		var layer: Node2D = LayerScript.new()
		layer.call("configure", int(descriptor[0]), 811 + int(descriptor[0]) * 37)
		layer.z_index = int(descriptor[1])
		add_child(layer)

func set_seat_occupants(snapshot: Dictionary) -> void:
	seat_occupants.clear()
	for key in snapshot:
		var seat := int(snapshot[key].get("seat", -1))
		if seat >= 0:
			seat_occupants[seat] = snapshot[key]
	for child in get_children():
		child.call("set_seat_occupants", seat_occupants)
