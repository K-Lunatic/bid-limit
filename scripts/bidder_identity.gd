class_name BidderIdentity
extends RefCounted

const BOT_NAMES := ["보풀왕", "단추부인", "실밥도둑"]

static func bot_name(player_id: int) -> String:
	return "%s (AI)" % BOT_NAMES[posmod(player_id - 100, BOT_NAMES.size())]
