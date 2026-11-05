extends SceneTree

const LotRules = preload("res://scripts/lot_rules.gd")

func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1042
	var lot: Dictionary = LotRules.make_lot(rng)
	assert(str(lot.art_id) in LotRules.LOT_ART_IDS)
	var options: Array = lot.options
	assert(options.size() == lot.option_count)
	assert(options.size() == LotRules.OPTION_DEFINITIONS.size())
	assert(lot.hints == LotRules.option_hints(options))
	var expected_value := LotRules.BASE_VALUE
	for option in options:
		assert(int(option.level) >= LotRules.MIN_LEVEL and int(option.level) <= LotRules.MAX_LEVEL)
		assert(str(option.hint).contains(str(option.level)))
		expected_value += int(option.level) * int(option.weight)
	assert(int(lot.value) >= expected_value + LotRules.VALUE_NOISE_MIN)
	assert(int(lot.value) <= expected_value + LotRules.VALUE_NOISE_MAX)
	var blind := LotRules.estimate(lot, 0, [])
	var known := LotRules.estimate(lot, options.size(), [])
	var forced_lot: Dictionary = lot.duplicate(true)
	forced_lot["options"][0]["level"] = 5 if int(forced_lot["options"][0]["level"]) != 5 else 1
	assert(LotRules.estimate(forced_lot, 0, [0]) != LotRules.estimate(forced_lot, 0, []))
	assert(LotRules.estimate(lot, 0, []) == blind)
	var appraisal := LotRules.appraise(lot, rng)
	assert(appraisal >= 20)
	var art_ids := {}
	for seed_value in 12:
		var varied_rng := RandomNumberGenerator.new()
		varied_rng.seed = seed_value + 900
		art_ids[LotRules.make_lot(varied_rng).art_id] = true
	assert(art_ids.size() >= 4)
	print("Lot rules smoke test: PASS")
	quit()
