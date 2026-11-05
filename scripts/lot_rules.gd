class_name BidLotRules
extends RefCounted

# One source of truth for lot generation, hints, valuation, and bot estimates.
const BASE_VALUE := 45
const MIN_LEVEL := 1
const MAX_LEVEL := 5
const VALUE_NOISE_MIN := -24
const VALUE_NOISE_MAX := 24
const APPRAISAL_NOISE_MIN := -18
const APPRAISAL_NOISE_MAX := 24
const OPTION_DEFINITIONS := [
	{"id": "condition", "label": "상태", "weight": 18},
	{"id": "rarity", "label": "희소성", "weight": 42},
	{"id": "provenance", "label": "출처 신뢰도", "weight": 27},
	{"id": "craftsmanship", "label": "마감도", "weight": 22},
	{"id": "demand", "label": "쓸모", "weight": 25},
]
const LOT_PREFIXES := ["무명", "실밥", "마지막", "손때 묻은"]
const LOT_FORMS := ["유리병", "배지", "모형", "낡은 상자", "찻잔", "가면", "실타래", "회중시계", "봉인 편지", "단추 액자"]
const LOT_ART_IDS := ["bottle", "badge", "puppet", "trunk", "teacup", "mask", "spool", "clock", "letter", "frame"]

static func make_lot(rng: RandomNumberGenerator) -> Dictionary:
	var options: Array[Dictionary] = []
	var levels := {}
	var value := BASE_VALUE
	for definition in OPTION_DEFINITIONS:
		var level := rng.randi_range(MIN_LEVEL, MAX_LEVEL)
		var id := str(definition["id"])
		var label := str(definition["label"])
		var weight := int(definition["weight"])
		levels[id] = level
		value += level * weight
		options.append({
			"id": id,
			"label": label,
			"level": level,
			"weight": weight,
			"hint": "%s: %d/5" % [label, level],
		})
	var rarity := int(levels.get("rarity", MIN_LEVEL))
	var provenance := int(levels.get("provenance", MIN_LEVEL))
	var form_index := rng.randi_range(0, LOT_FORMS.size() - 1)
	return {
		"name": "%s %s" % [LOT_PREFIXES[rarity % LOT_PREFIXES.size()], LOT_FORMS[form_index]],
		"art_id": LOT_ART_IDS[form_index],
		"value": value + rng.randi_range(VALUE_NOISE_MIN, VALUE_NOISE_MAX),
		"option_count": options.size(),
		"options": options,
		"hints": option_hints(options),
	}

static func option_hints(options: Array) -> Array[String]:
	var hints: Array[String] = []
	for option in options:
		hints.append(str(option.get("hint", "알 수 없는 옵션")))
	return hints

static func estimate(lot: Dictionary, visible_count: int, known_indices: Array, bias := 0.0, multiplier := 1.0) -> float:
	var estimate_value := float(BASE_VALUE) + float(bias)
	var options: Array = lot.get("options", [])
	for index in options.size():
		var option: Dictionary = options[index]
		var level := 3
		if index < visible_count or known_indices.has(index):
			level = int(option.get("level", 3))
		estimate_value += float(level * int(option.get("weight", 0)))
	return maxf(20.0, estimate_value * multiplier)

static func appraise(lot: Dictionary, rng: RandomNumberGenerator) -> int:
	return max(20, int(lot.get("value", 20)) + rng.randi_range(APPRAISAL_NOISE_MIN, APPRAISAL_NOISE_MAX))
