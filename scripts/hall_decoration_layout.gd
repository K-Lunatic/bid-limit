class_name HallDecorationLayout
extends RefCounted
const SPEC_PATH := "res://assets/maps/props/layout-v1.json"
static func build(seed_value := 811) -> Array[Dictionary]:
	var spec: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(SPEC_PATH))
	var noise := FastNoiseLite.new()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.seed = seed_value
	noise.frequency = float(spec.noise_frequency)
	var placements: Array[Dictionary] = []
	for slot in spec.decoration_slots:
		var sample := noise.get_noise_2d(float(slot), 17.0)
		var variant := clampi(floori((sample + 1.0) * 0.5 * spec.props.size()),0,spec.props.size()-1)
		var prop: Dictionary = spec.props[variant]
		var x := float(slot) + roundf(noise.get_noise_2d(float(slot), 297.0) * 20.0)
		var blocked := false
		for interval in spec.reserved_x:
			if x + 70.0 > float(interval[0]) and x - 70.0 < float(interval[1]): blocked = true
		if blocked: continue
		# The two floor props use their bottom pixel as the anchor; never leave them hovering above the walk lane.
		var y := 520.0 if int(prop.anchor[1]) >= 90 else float(prop.y)
		placements.append({"id":prop.id,"cell":[int(prop.cell[0]),int(prop.cell[1])],"anchor":prop.anchor,"position":Vector2(x,y)})
	return placements
