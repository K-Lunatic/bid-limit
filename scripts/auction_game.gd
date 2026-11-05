class_name BidAuctionGame
extends Node

const LotRulesScript = preload("res://scripts/lot_rules.gd")
const Identity = preload("res://scripts/bidder_identity.gd")

signal changed(state: Dictionary)
signal defense_card_requested(player_id: int)
signal action_requested(action: String)

const BOT_IDS := [100, 101, 102]
const LOTS_PER_MATCH := 5
const MATCH_GOAL_TEXT := "5라운드 후 순자산이 가장 높은 플레이어"
const DEFAULT_DECK_IDS := ["bid", "bid", "bid", "luck", "inspect", "publish", "shield", "attack", "steal", "draw", "rumor", "raise"]
const RANDOM_CARD_POOL := ["bid", "bid", "bid", "inspect", "publish", "shield", "attack", "draw", "rumor", "raise", "steal"]
const DEFAULT_HAND_SIZE := 4
const MAX_HAND_SIZE := 5
const MAX_DECK_SIZE := 15
const MIN_DECK_SIZE := 8
const STARTING_ENERGY := 3
const ENERGY_REGEN_PER_TURN := 1
const MARKET_CARD_COST := 70
const BOT_ARCHETYPE_NAMES := ["감정사 덱", "허풍쟁이 덱", "도둑시장 덱"]
const LOAN_PRINCIPAL := 150
const LOAN_INTEREST := 30
const MAX_LOCKED_ENERGY := 2
const ROULETTE_MIN_BET := 20
const ROULETTE_MAX_BET := 100
const TURN_TIME_LIMIT := 25.0
const HAMMER_INTERVAL := 2.0
const INTERMISSION_SECONDS := 45.0
const INITIAL_PREPARATION_SECONDS := 60.0
const BOT_ACTION_DELAY := 4.0
var active_bot_ids: Array = BOT_IDS.duplicate()
var active_player_ids: Array = [1, 100, 101, 102]
var bot_bias: Dictionary = {}
var bot_strategy: Dictionary = {}
var bot_fortune: Dictionary = {}

var rng := RandomNumberGenerator.new()
var cash := {1: 500, 100: 500, 101: 500, 102: 500}
var inventories: Dictionary = {}
var final_scores: Dictionary = {}
var remote_final_standings: Array = []
var sold_this_cycle: Array = []
var remote_inventory: Array = []
var remote_sold := false
var lot: Dictionary = {}
var bid := 0
var leader := -1
var folded: Array = []
var turn_id := -1
var passed_since_bid: Array = []
var card_blocked: Array = []
var player_weapons: Dictionary = {}
var player_names: Dictionary = {}
var last_play: Dictionary = {}
var play_sequence := 0
var hammer := 0
var hammer_delay := 0.0
var timer := 4.0
var phase := "auction"
var cycle := 0
var hint_level := 0
var announcement := "경매사가 첫 번째 물품을 공개했다."
var round_route := "waiting"
var next_lot_hint_bonus := 0
var public_pressure := 0
var public_rumor_shift := 0
var round_decisions: Dictionary = {}
var last_round_decisions: Dictionary = {}
var decision_history: Array = []
var bot_cooldown := BOT_ACTION_DELAY
var bot_interrupt_cooldown := BOT_ACTION_DELAY * 0.5
var card_energy := 3
var deck: Array[Dictionary] = []
var hand: Array = []
var discard: Array[Dictionary] = []
var decks: Dictionary = {}
var hands: Dictionary = {}
var discards: Dictionary = {}
var market_offers: Dictionary = {}
var remote_market_offer: Array = []
var remote_turn_name := ""
var remote_leader_name := "없음"
const MARKET_POOL = ["bid", "attack", "shield", "inspect", "publish", "draw", "rumor", "raise", "steal", "luck", "gacha"]
var reserves: Dictionary = {}
var dirty_decks: Dictionary = {}
var remote_deck_view: Array = []
var remote_pile_counts := {"draw":0,"discard":0}
var energy_by_player: Dictionary = {}
var locked_energy: Dictionary = {}
var debt_by_player: Dictionary = {}
var roulette_used: Dictionary = {}
var remote_hand_counts: Dictionary = {}
var remote_hints: Array = []
var remote_value_range: Array = [20, 20]
var private_hint_indices: Dictionary = {}
var hint_deal_offset := 0
var remote_private_hints: Array = []
var remote_bot_archetypes: Dictionary = {}
var local_player_id := 1
var authoritative := true
var auction_started := false
var table_ready := false
var table_count := 0
var table_total := 4

func _ready() -> void:
	rng.randomize()
	reset_cards()
	if authoritative:
		start_lot()
		auction_started = false
		phase = "waiting"
		announcement = "모두 경매 참여 구역에 들어오면 시작합니다."
	else:
		# Guests wait for the host snapshot instead of inventing a local lot.
		lot.clear()
		last_play.clear()
		auction_started = false
		phase = "connecting"
		announcement = "방장과 경매 상태를 연결하는 중입니다."
		table_ready = false
		table_count = 0
		table_total = 0

func _process(delta: float) -> void:
	if not authoritative:
		return
	if phase == "finished":
		return
	if not auction_started:
		if phase == "waiting": timer = maxf(0.0,timer-delta)
		emit_state()
		return
	timer -= delta
	if phase == "auction":
		bot_interrupt_cooldown -= delta
		if turn_id != -1:
			if active_bot_ids.has(turn_id):
				bot_cooldown -= delta
				if bot_cooldown <= 0.0:
					make_bot_bid()
			elif timer <= 0.0:
				pass_turn(turn_id)
			if bot_interrupt_cooldown <= 0.0:
				bot_interrupt_cooldown = BOT_ACTION_DELAY
				_try_bot_interrupt_bid()
		else:
			bot_cooldown -= delta
			if timer > 0.0 and bot_cooldown <= 0.0:
				bot_cooldown = HAMMER_INTERVAL
				_try_bot_last_bid()
			if turn_id == -1 and timer <= 0.0:
				_tick_hammer()
	elif timer <= 0.0:
		if cycle >= LOTS_PER_MATCH:
			finish_match()
		else:
			start_lot()
	emit_state()

func _tick_hammer() -> void:
	if leader == -1:
		close_auction()
		return
	hammer += 1
	timer = HAMMER_INTERVAL
	bot_cooldown = HAMMER_INTERVAL * 0.6
	announcement = "%d번째 망치. 입찰 카드로 마지막 입찰 가능!" % hammer
	if hammer >= 3:
		close_auction()

func _bot_bid_limit(bot_id: int) -> float:
	var fortune_modifier := (float(bot_fortune.get(bot_id, 50)) - 50.0) / 200.0
	return bot_estimate(bot_id) * ([0.9, 1.2, 1.0][int(bot_strategy.get(bot_id, posmod(bot_id, 3)))] + fortune_modifier)

func _try_bot_last_bid() -> bool:
	if phase != "auction" or turn_id != -1 or leader == -1:
		return false
	var next_bid := bid + 20
	for bot_id in active_bot_ids:
		if not active_player_ids.has(bot_id) or bot_id == leader or folded.has(bot_id) or card_blocked.has(bot_id):
			continue
		if _find_card_index(hands.get(bot_id, []), "bid") < 0 or int(cash.get(bot_id, 0)) < next_bid:
			continue
		if next_bid <= _bot_bid_limit(bot_id) and place_bid(bot_id):
			return true
	return false

func _try_bot_interrupt_bid() -> bool:
	if phase != "auction" or turn_id == -1:
		return false
	var next_bid := 20 if bid == 0 else bid + 20
	for bot_id in active_bot_ids:
		if bot_id == turn_id or not active_player_ids.has(bot_id) or bot_id == leader or folded.has(bot_id) or card_blocked.has(bot_id):
			continue
		if _find_card_index(hands.get(bot_id, []), "bid") < 0 or int(cash.get(bot_id, 0)) < next_bid:
			continue
		if next_bid <= _bot_bid_limit(bot_id) and place_bid(bot_id):
			return true
	return false

func request_bid() -> void:
	if not authoritative:
		action_requested.emit("bid")
		return
	place_bid(local_player_id)

func place_bid(player_id: int) -> bool:
	# A bid is an interrupt action: the player may answer from any seat, but still spends a bid card and cash.
	if phase != "auction" or not active_player_ids.has(player_id) or card_blocked.has(player_id):
		return false
	var next_bid := 20 if bid == 0 else bid + 20
	if cash.get(player_id, 0) < next_bid or leader == player_id or folded.has(player_id):
		return false
	var player_hand: Array = hands.get(player_id, [])
	var bid_index := -1
	for index in player_hand.size():
		if player_hand[index].get("id", "") == "bid":
			bid_index = index
			break
	if bid_index < 0:
		return false
	var bid_card: Dictionary = player_hand.pop_at(bid_index)
	discards[player_id].append(bid_card)
	_record_play(player_id, [bid_card])
	bid = next_bid
	leader = player_id
	hammer = 0
	passed_since_bid.clear()
	_record_decision(player_id, "bid", str(bid))
	announcement = "%s번이 %d 보풀로 입찰했다." % [bidder_name(player_id), bid]
	_sync_local_hand()
	advance_turn(player_id)
	emit_state()
	return true

func request_pass() -> void:
	if not authoritative:
		action_requested.emit("pass")
		return
	pass_turn(local_player_id)

func pass_turn(player_id: int) -> bool:
	if phase != "auction" or player_id != turn_id:
		return false
	if not passed_since_bid.has(player_id):
		passed_since_bid.append(player_id)
	card_blocked.erase(player_id)
	_record_decision(player_id, "pass")
	announcement = "%s 차례 넘김" % bidder_name(player_id)
	advance_turn(player_id)
	emit_state()
	return true

func advance_turn(previous_id: int) -> void:
	turn_id = -1
	var start := active_player_ids.find(previous_id)
	for step in range(1, active_player_ids.size() + 1):
		var candidate := int(active_player_ids[(start + step) % active_player_ids.size()])
		if candidate != leader and not folded.has(candidate) and not passed_since_bid.has(candidate):
			turn_id = candidate
			break
	timer = TURN_TIME_LIMIT if turn_id != -1 else HAMMER_INTERVAL + hammer_delay
	if turn_id != -1:
		var locked := int(locked_energy.get(turn_id, 0))
		var energy_cap := maxi(0, STARTING_ENERGY - locked)
		energy_by_player[turn_id] = mini(energy_cap, int(energy_by_player.get(turn_id, 0)) + ENERGY_REGEN_PER_TURN)
		draw_card_for(turn_id)
		_sync_local_hand()
	if turn_id == -1:
		hammer_delay = 0.0
	bot_cooldown = BOT_ACTION_DELAY if turn_id != -1 else HAMMER_INTERVAL * 0.6
	bot_interrupt_cooldown = BOT_ACTION_DELAY

func set_active_players(player_ids: Array) -> void:
	if active_player_ids == player_ids:
		return
	var old_turn := turn_id
	var leader_left := leader != -1 and not player_ids.has(leader)
	active_player_ids = player_ids.duplicate()
	if phase != "auction":
		return
	if leader_left:
		leader = -1
		bid = 0
		hammer = 0
		passed_since_bid.clear()
		announcement = "최고 입찰자가 떠나 현재 입찰이 취소됐다."
	if (old_turn != -1 and not active_player_ids.has(old_turn)) or (leader_left and old_turn == -1):
		advance_turn(old_turn)
	emit_state()

func request_fold() -> void:
	if not authoritative:
		action_requested.emit("fold")
		return
	fold_player(local_player_id)

func fold_player(player_id: int) -> bool:
	if phase != "auction" or player_id != turn_id or not active_player_ids.has(player_id) or player_id == leader or folded.has(player_id):
		return false
	folded.append(player_id)
	card_blocked.erase(player_id)
	_record_decision(player_id, "fold")
	announcement = "%s 경매 포기" % bidder_name(player_id)
	advance_turn(player_id)
	emit_state()
	return true

func register_player(player_id: int) -> void:
	if not cash.has(player_id):
		cash[player_id] = 500
	if not hands.has(player_id):
		_create_player_deck(player_id)
	if not inventories.has(player_id):
		inventories[player_id] = []
	if not locked_energy.has(player_id):
		locked_energy[player_id] = 0
	if not debt_by_player.has(player_id):
		debt_by_player[player_id] = 0
	if not roulette_used.has(player_id):
		roulette_used[player_id] = false
	if authoritative and lot.has("hints") and not private_hint_indices.has(player_id):
		assign_initial_hint(player_id)
	_sync_local_hand()

func assign_initial_hint(player_id: int) -> void:
	var hidden_count: int = lot.get("hints", []).size() - hint_level
	if hidden_count > 0:
		private_hint_indices[player_id] = [hint_level + posmod(player_id + hint_deal_offset, hidden_count)]

func buy_hint_for(player_id: int) -> void:
	register_player(player_id)
	if phase != "auction" or player_id != turn_id or folded.has(player_id) or cash[player_id] < 20:
		return
	if not reveal_private_hint(player_id):
		announcement = "모든 옵션이 공개되어 더 살 힌트가 없다."
		emit_state()
		return
	cash[player_id] -= 20
	_record_decision(player_id, "hint", "paid")
	announcement = "%s번이 감정 힌트를 샀다." % bidder_name(player_id)
	advance_turn(player_id)
	emit_state()

func reveal_private_hint(player_id: int) -> bool:
	var known: Array = private_hint_indices.get(player_id, [])
	for index in range(hint_level, lot.hints.size()):
		if not known.has(index):
			known.append(index)
			private_hint_indices[player_id] = known
			return true
	return false

func buy_hint() -> void:
	if not authoritative:
		action_requested.emit("hint")
		return
	buy_hint_for(local_player_id)

func use_inspect_card() -> void:
	if not authoritative:
		action_requested.emit("inspect")
	if not authoritative:
		return
	for index in hand.size():
		if hand[index].get("id", "") == "inspect":
			play_card(index)
			return

func request_card(card_id: String) -> void:
	if not authoritative:
		action_requested.emit("card:" + card_id)
		return
	play_card_id(card_id)

func request_hand_card(index: int) -> void:
	if not authoritative:
		return
	play_card(index, local_player_id)

func submit_hand(indices: Array, player_id := 1) -> void:
	if not authoritative:
		var encoded: Array[String] = []
		for index in indices:
			encoded.append(str(int(index)))
		action_requested.emit("submit:" + ",".join(encoded))
		return
	play_card_indices(indices, player_id)

func play_card_id(card_id: String, player_id := 1) -> void:
	var player_hand: Array = hands.get(player_id, hand)
	for index in player_hand.size():
		if player_hand[index].get("id", "") == card_id:
			play_card(index, player_id)
			return

func reset_cards() -> void:
	card_blocked.clear()
	deck.clear()
	hand.clear()
	discard.clear()
	decks.clear()
	hands.clear()
	discards.clear()
	reserves.clear()
	market_offers.clear()
	dirty_decks.clear()
	energy_by_player.clear()
	locked_energy.clear()
	debt_by_player.clear()
	roulette_used.clear()
	bot_bias.clear()
	bot_strategy.clear()
	bot_fortune.clear()
	for player_id in [1, 100, 101, 102]:
		_create_player_deck(player_id)
	_sync_local_hand()

func _create_player_deck(player_id: int) -> void:
	var player_deck: Array[Dictionary] = []
	for card_id in DEFAULT_DECK_IDS:
		player_deck.append(card_definition(card_id))
	player_deck.shuffle()
	decks[player_id] = player_deck
	hands[player_id] = []
	discards[player_id] = []
	reserves[player_id] = []
	market_offers[player_id] = []
	energy_by_player[player_id] = STARTING_ENERGY
	locked_energy[player_id] = 0
	debt_by_player[player_id] = 0
	roulette_used[player_id] = false
	for index in DEFAULT_HAND_SIZE:
		draw_card_for(player_id)

func _sync_local_hand() -> void:
	hand = hands.get(local_player_id, [])
	card_energy = int(energy_by_player.get(local_player_id, 3))

func deck_view(player_id: int) -> Array:
	if not authoritative:
		return remote_deck_view.duplicate(true)
	var counts := {}
	for pile in [decks.get(player_id,[]), hands.get(player_id,[]), discards.get(player_id,[])]:
		for card in pile:
			var id := str(card.id)
			if not counts.has(id): counts[id] = {"active":0,"reserve":0}
			counts[id].active += 1
	for card in reserves.get(player_id,[]):
		var id := str(card.id)
		if not counts.has(id): counts[id] = {"active":0,"reserve":0}
		counts[id].reserve += 1
	var view: Array = []
	var ids: Array = counts.keys()
	ids.sort()
	for id in ids:
		var entry := card_definition(id)
		entry.merge(counts[id])
		view.append(entry)
	return view

func all_deck_views() -> Dictionary:
	var views := {}
	if authoritative:
		for id in active_player_ids:
			views[id] = deck_view(int(id))
	return views

func pile_counts(player_id: int) -> Dictionary:
	return {"draw":decks.get(player_id,[]).size(),"discard":discards.get(player_id,[]).size()} if authoritative else remote_pile_counts

func all_pile_counts() -> Dictionary:
	var counts := {}
	if authoritative:
		for id in active_player_ids: counts[id] = pile_counts(int(id))
	return counts

func request_deck_change(card_id: String, adding: bool) -> void:
	if authoritative:
		change_deck_card(local_player_id, card_id, adding)
	else:
		action_requested.emit("deck:%s:%s" % ["add" if adding else "remove", card_id])

func change_deck_card(player_id: int, card_id: String, adding: bool) -> bool:
	if not authoritative or phase not in ["waiting","appraisal"] or not active_player_ids.has(player_id):
		return false
	var total := 0
	var bids := 0
	for entry in deck_view(player_id):
		total += int(entry.active)
		if entry.id == "bid": bids = int(entry.active)
	if (adding and total >= MAX_DECK_SIZE) or (not adding and (total <= MIN_DECK_SIZE or (card_id == "bid" and bids <= 1))):
		return false
	var source_piles: Array = [reserves.get(player_id,[])] if adding else [decks.get(player_id,[]),discards.get(player_id,[]),hands.get(player_id,[])]
	for pile in source_piles:
		for index in pile.size():
			if str(pile[index].id) != card_id: continue
			var card: Dictionary = pile.pop_at(index)
			if adding:
				discards[player_id].append(card)
			else:
				reserves[player_id].append(card)
			dirty_decks[player_id] = true
			_sync_local_hand()
			announcement = "덱 편집 완료 · 다음 경매 시작 시 섞습니다."
			emit_state()
			return true
	return false

func _prepare_edited_decks() -> void:
	for id in dirty_decks:
		var cards: Array = decks.get(id,[])
		cards.append_array(hands.get(id,[]))
		cards.append_array(discards.get(id,[]))
		cards.shuffle()
		decks[id] = cards
		hands[id] = []
		discards[id] = []
		for count in DEFAULT_HAND_SIZE:
			draw_card_for(int(id))
	dirty_decks.clear()
	_sync_local_hand()

func set_player_identity(player_id: int, nickname: String, weapon: int) -> void:
	player_names[player_id] = nickname.left(12)
	player_weapons[player_id] = clampi(weapon, 0, 2)

func _record_play(player_id: int, cards: Array) -> void:
	play_sequence += 1
	var card_ids: Array[String] = []
	for card in cards:
		card_ids.append(str(card.get("id", "card")))
	round_decisions[player_id] = "card:" + ",".join(card_ids)
	_record_decision(player_id, "card", ",".join(card_ids))
	last_play = {"sequence": play_sequence, "player_id": player_id, "player_name": player_names.get(player_id, bidder_name(player_id)), "weapon": player_weapons.get(player_id, 0), "cards": cards.duplicate(true)}

func _record_decision(player_id: int, decision: String, detail := "") -> void:
	round_decisions[player_id] = decision if detail.is_empty() else "%s:%s" % [decision, detail]
	decision_history.append({"cycle": cycle, "player_id": player_id, "decision": decision, "detail": detail})
	if decision_history.size() > 24:
		decision_history.pop_front()

func jam_player(player_id: int) -> void:
	if authoritative and active_player_ids.has(player_id) and not card_blocked.has(player_id):
		card_blocked.append(player_id)
		announcement = "%s 카드 봉쇄! 다음 차례에 방어하거나 넘기세요." % bidder_name(player_id)
		emit_state()

func _roll_market_offer(player_id: int) -> void:
	var pool: Array = MARKET_POOL.duplicate()
	pool.shuffle()
	market_offers[player_id] = pool.slice(0, 3)

func buy_market_pack(player_id: int) -> bool:
	if not authoritative or phase not in ["waiting", "appraisal"] or not active_player_ids.has(player_id):
		return false
	if not market_offers.get(player_id, []).is_empty() or int(cash.get(player_id, 0)) < MARKET_CARD_COST:
		return false
	cash[player_id] -= MARKET_CARD_COST
	_roll_market_offer(player_id)
	announcement = "단추상점 봉투 개봉! 결제 완료 · 3장 중 1장을 고르세요."
	emit_state()
	return true

func buy_market_card(player_id: int, card_id: String) -> bool:
	if not authoritative or phase not in ["waiting", "appraisal"] or not active_player_ids.has(player_id):
		return false
	if not market_offers.get(player_id, []).has(card_id):
		return false
	reserves[player_id].append(card_definition(card_id))
	market_offers[player_id] = []
	announcement = "%s 단추상점 카드 획득! 보관함에 추가됐습니다. 덱 버튼에서 편성하세요." % bidder_name(player_id)
	emit_state()
	return true

func borrow_loan(player_id: int) -> bool:
	register_player(player_id)
	if not authoritative or phase not in ["waiting", "appraisal"] or not active_player_ids.has(player_id):
		return false
	if int(locked_energy.get(player_id, 0)) >= MAX_LOCKED_ENERGY:
		return false
	locked_energy[player_id] = int(locked_energy.get(player_id, 0)) + 1
	debt_by_player[player_id] = int(debt_by_player.get(player_id, 0)) + LOAN_PRINCIPAL + LOAN_INTEREST
	cash[player_id] = int(cash.get(player_id, 0)) + LOAN_PRINCIPAL
	energy_by_player[player_id] = mini(int(energy_by_player.get(player_id, STARTING_ENERGY)), STARTING_ENERGY - int(locked_energy[player_id]))
	_record_decision(player_id, "loan", str(LOAN_PRINCIPAL))
	announcement = "%s가 실밥 1개를 담보로 %d 보풀을 빌렸다. 상환액 %d." % [bidder_name(player_id), LOAN_PRINCIPAL, int(debt_by_player[player_id])]
	emit_state()
	return true

func repay_loan(player_id: int) -> bool:
	register_player(player_id)
	var debt := int(debt_by_player.get(player_id, 0))
	var released := int(locked_energy.get(player_id, 0))
	if not authoritative or phase not in ["waiting", "appraisal"] or debt <= 0 or int(cash.get(player_id, 0)) < debt:
		return false
	cash[player_id] = int(cash.get(player_id, 0)) - debt
	debt_by_player[player_id] = 0
	locked_energy[player_id] = 0
	energy_by_player[player_id] = mini(int(energy_by_player.get(player_id, 0)) + released, STARTING_ENERGY)
	_record_decision(player_id, "repay", str(debt))
	announcement = "%s가 이자 포함 %d 보풀을 갚고 잠긴 실밥을 모두 되찾았다." % [bidder_name(player_id), debt]
	emit_state()
	return true

func play_roulette(player_id: int, bet: int) -> bool:
	register_player(player_id)
	if not authoritative or phase not in ["waiting", "appraisal"] or not active_player_ids.has(player_id) or bool(roulette_used.get(player_id, false)):
		return false
	if bet < ROULETTE_MIN_BET or bet > ROULETTE_MAX_BET or int(cash.get(player_id, 0)) < bet:
		return false
	roulette_used[player_id] = true
	cash[player_id] = int(cash.get(player_id, 0)) - bet
	var roll := rng.randi_range(1, 100)
	var payout := 0
	if roll <= 5:
		payout = bet * 5
	elif roll <= 47:
		payout = bet * 2
	cash[player_id] += payout
	_record_decision(player_id, "roulette", "%d/%d" % [bet, payout])
	if payout == bet * 5:
		announcement = "%s의 룰렛 잭팟! %d 보풀을 받았다." % [bidder_name(player_id), payout]
	elif payout > 0:
		announcement = "%s의 룰렛 적중! %d 보풀을 받았다." % [bidder_name(player_id), payout]
	else:
		announcement = "%s의 룰렛 실패. %d 보풀을 잃었다." % [bidder_name(player_id), bet]
	emit_state()
	return true

func card_definition(card_id: String) -> Dictionary:
	match card_id:
		"bid": return {"id": "bid", "name": "입찰 +20", "label": "입찰", "kind": "입찰", "summary": "가격 +20", "cost": 0, "text": "현재 가격보다 20보풀 높게 입찰.\n입찰표 1장 사용. 낙찰 때 결제.", "flavor": "제 지갑이 울고 있어요"}
		"draw": return {"id": "draw", "name": "두 장 뽑기", "label": "두장뽑기", "kind": "보충", "summary": "손패 +2", "cost": 1, "text": "덱에서 2장을 뽑는다.\n손패는 최대 5장. 덱이 떨어지면\n버린 카드를 다시 섞는다.", "flavor": "소매 속에 두 장 더"}
		"inspect": return {"id": "inspect", "name": "몰래 감정", "label": "몰래감정", "kind": "정보", "summary": "나만 옵션 +1", "cost": 1, "text": "모르는 옵션 1개를 나만 확인.\n전체 공개와 함께 낼 수 없다.", "flavor": "돋보기는 입이 무거워요"}
		"publish": return {"id": "publish", "name": "전체 공개", "label": "전체공개", "kind": "정보", "summary": "모두 옵션 +1", "cost": 1, "text": "숨겨진 옵션 1개를 모두에게 공개.\n몰래 감정과 함께 낼 수 없다.", "flavor": "비밀인데 마이크가 켜졌어요"}
		"shield": return {"id": "shield", "name": "봉쇄 해제", "label": "봉쇄해제", "kind": "방어", "summary": "내 봉쇄 해제", "cost": 1, "text": "봉쇄당했을 때 이 카드 1장으로\n봉쇄를 풀고 차례를 마친다.", "flavor": "그 표는 못 가져가요"}
		"attack": return {"id": "attack", "name": "카드 봉쇄", "label": "카드봉쇄", "kind": "방해", "summary": "상대 봉쇄", "cost": 1, "text": "다음 입찰 가능한 상대를 봉쇄.\n상대는 방어·공격 1장으로 풀거나\n넘겨야 한다. 봉쇄 중 내면 해제만.", "flavor": "오늘은 제출대 휴무"}
		"rumor": return {"id": "rumor", "name": "허풍 떨기", "label": "허풍떨기", "kind": "방해", "summary": "예상가 ±35", "cost": 1, "text": "모두가 보는 예상 가치 신호를\n±35보풀 흔든다. 사람도 속을 수 있다.\n실제 물품 가치는 바뀌지 않는다.", "flavor": "이거 우리 할머니도 탐내요"}
		"raise": return {"id": "raise", "name": "망치 2초 지연", "label": "망치지연", "kind": "방해", "summary": "첫 망치 +2초", "cost": 2, "text": "첫 망치까지의 대기를 2초 늘린다.\n입찰 가격은 바뀌지 않는다.", "flavor": "망치님 화장실 좀요"}
		"steal": return {"id": "steal", "name": "카드 한 장 훔치기", "label": "카드훔침", "kind": "보충", "summary": "상대 손패 −1", "cost": 2, "text": "선두의 무작위 카드 1장을 가져온다.\n없으면 손패가 가장 많은 상대.\n내 손패가 5장이면 가져오지 못한다.", "flavor": "빌린 건데요?"}
		"luck": return {"id": "luck", "name": "단추 동전", "label": "운시험", "kind": "변수", "summary": "확률 효과", "cost": 1, "text": "40% 두 장 뽑기 · 35% 몰래 감정\n15% 전체 공개 · 10% 꽝.\n공개할 옵션이 없으면 실패.", "flavor": "소파 밑으로만 가지 마"}
		"gacha": return {"id": "gacha", "name": "랜덤 카드 뽑기", "label": "랜덤뽑기", "kind": "변수", "summary": "무작위 +1", "cost": 2, "text": "무작위 행동표 1장을 손패에 추가.\n손패가 5장이면 뽑지 못한다.", "flavor": "이 봉투는 환불 안 돼요"}
	return {"id": card_id, "name": "알 수 없는 카드", "cost": 1, "text": "효과를 확인할 수 없습니다."}

func draw_card() -> void:
	draw_card_for(local_player_id)
	_sync_local_hand()

func draw_card_for(player_id: int) -> void:
	var player_hand: Array = hands.get(player_id, [])
	if player_hand.size() >= MAX_HAND_SIZE:
		return
	var player_deck: Array = decks.get(player_id, [])
	var player_discard: Array = discards.get(player_id, [])
	if player_deck.is_empty() and not player_discard.is_empty():
		player_deck.append_array(player_discard)
		player_discard.clear()
		player_deck.shuffle()
	if not player_deck.is_empty():
		player_hand.append(player_deck.pop_back())
	hands[player_id] = player_hand
	decks[player_id] = player_deck
	discards[player_id] = player_discard

func draw_random_card_for(player_id: int) -> String:
	var player_hand: Array = hands.get(player_id, [])
	if player_hand.size() >= MAX_HAND_SIZE:
		return ""
	var card_id := str(RANDOM_CARD_POOL[rng.randi_range(0, RANDOM_CARD_POOL.size() - 1)])
	player_hand.append(card_definition(card_id))
	hands[player_id] = player_hand
	return card_id

func play_card(index: int, player_id := 1) -> void:
	play_card_indices([index], player_id)

func play_card_indices(indices: Array, player_id := 1) -> void:
	if phase != "auction" or player_id != turn_id or indices.is_empty():
		return
	if indices.size() != 1:
		announcement = "행동 카드는 한 번에 한 장씩만 낼 수 있다. 끝나면 넘김을 누르세요."
		emit_state()
		return
	register_player(player_id)
	var player_hand: Array = hands.get(player_id, [])
	var escaping := card_blocked.has(player_id)
	if escaping and (indices.size() != 1 or int(indices[0]) < 0 or int(indices[0]) >= player_hand.size() or not str(player_hand[int(indices[0])].get("id", "")) in ["shield", "attack"]):
		announcement = "공격받았다! 방어·공격 카드를 내거나 차례를 넘기세요."
		emit_state()
		return
	var unique_indices: Array[int] = []
	var total_cost := 0
	for raw_index in indices:
		var index := int(raw_index)
		if index < 0 or index >= player_hand.size() or unique_indices.has(index):
			return
		if player_hand[index].get("id", "") == "bid":
			return
		unique_indices.append(index)
		total_cost += int(player_hand[index].get("cost", 1))
	var inspect_count := 1 if str(player_hand[unique_indices[0]].get("id", "")) == "inspect" else 0
	var publish_count := 1 if str(player_hand[unique_indices[0]].get("id", "")) == "publish" else 0
	if publish_count > lot.hints.size() - hint_level or (publish_count > 0 and inspect_count > 0):
		announcement = "공개할 옵션이 없거나 감정 카드와 함께 낼 수 없다."
		emit_state()
		return
	var unknown_count := 0
	var known: Array = private_hint_indices.get(player_id, [])
	for index in range(hint_level, lot.hints.size()):
		if not known.has(index):
			unknown_count += 1
	if inspect_count > unknown_count:
		announcement = "더 확인할 비공개 옵션이 부족하다."
		emit_state()
		return
	var player_energy := int(energy_by_player.get(player_id, 3))
	if player_energy < total_cost:
		announcement = "제출한 덱의 실밥 코스트가 부족하다."
		emit_state()
		return
	unique_indices.sort()
	var selected: Array[Dictionary] = []
	for index in unique_indices:
		selected.append(player_hand[index])
	_record_play(player_id, selected)
	player_energy -= total_cost
	for index in range(unique_indices.size() - 1, -1, -1):
		player_hand.remove_at(unique_indices[index])
	hands[player_id] = player_hand
	for card in selected:
		discards[player_id].append(card)
		if escaping:
			card_blocked.erase(player_id)
			announcement = "%s 카드로 공격을 피했다!" % bidder_name(player_id)
		else:
			_apply_card_effect(card, player_id)
	energy_by_player[player_id] = player_energy
	_sync_local_hand()
	# Action cards keep the turn. Passing is the explicit handoff, so the player can chain cards one at a time.
	timer = maxf(timer, TURN_TIME_LIMIT)
	emit_state()

func _apply_card_effect(card: Dictionary, player_id := 1) -> void:
	match card.get("id", ""):
		"attack":
			var start := active_player_ids.find(player_id)
			for step in range(1, active_player_ids.size()):
				var target := int(active_player_ids[(start + step) % active_player_ids.size()])
				if target != leader and not folded.has(target) and not passed_since_bid.has(target):
					if not card_blocked.has(target):
						card_blocked.append(target)
					announcement = "%s 카드 사용 봉쇄!" % bidder_name(target)
					break
		"inspect":
			reveal_private_hint(player_id)
			announcement = "%s 님이 돋보기로 감정했다." % bidder_name(player_id)
		"publish":
			hint_level += 1
			public_pressure = mini(public_pressure + 1, 2)
			announcement = "모든 옵션이 공개됐다. 이제 가격과 심리전만 남았다." if hint_level >= lot.hints.size() else "비밀인데 마이크가 켜졌어요! 옵션이 공개됐다."
		"draw":
			draw_card_for(player_id)
			draw_card_for(player_id)
			announcement = "%s 카드 뽑기!" % bidder_name(player_id)
		"luck":
			var roll := rng.randi_range(1, 100)
			if roll <= 40:
				draw_card_for(player_id)
				draw_card_for(player_id)
				announcement = "%s 동전 앞면! 카드 2장 획득." % bidder_name(player_id)
			elif roll <= 75:
				if reveal_private_hint(player_id):
					announcement = "%s 동전의 앞면! 비공개 감정 성공." % bidder_name(player_id)
				else:
					announcement = "%s 동전은 굴렀지만 더 볼 힌트가 없다." % bidder_name(player_id)
			elif roll <= 90 and hint_level < lot.hints.size():
				hint_level += 1
				announcement = "%s 동전의 옆면! 옵션이 전체 공개됐다." % bidder_name(player_id)
			else:
				announcement = "%s 동전이 소파 밑으로 굴러갔다. 아무 일도 없다." % bidder_name(player_id)
		"gacha":
			var random_card_id := draw_random_card_for(player_id)
			if random_card_id.is_empty():
				announcement = "%s 손패가 가득해 캡슐을 열 수 없다." % bidder_name(player_id)
			else:
				announcement = "%s 단추상점 캡슐에서 무작위 카드를 뽑았다." % bidder_name(player_id)
		"shield":
			defense_card_requested.emit(player_id)
			announcement = "꿰맨 방패를 준비했다."
		"rumor":
			var swing := 35 if rng.randi_range(0, 1) == 0 else -35
			public_rumor_shift = clampi(public_rumor_shift + swing, -70, 70)
			for bot_id in active_bot_ids:
				if bot_id != player_id:
					bot_bias[bot_id] = int(bot_bias.get(bot_id, 0)) + swing
			announcement = "%s의 허풍! 공개 예상가가 %s%d 보풀 흔들렸다. 실제 가치는 그대로다." % [bidder_name(player_id), "+" if swing > 0 else "−", absi(swing)]
		"raise":
			hammer_delay += 2.0
			announcement = "망치님이 잠시 자리를 비웠다."
		"steal":
			var target_id := _steal_target(player_id)
			var target_hand: Array = hands.get(target_id, [])
			var own_hand: Array = hands.get(player_id, [])
			if not target_hand.is_empty() and own_hand.size() < 5:
				var stolen_card: Dictionary = target_hand.pop_at(rng.randi_range(0, target_hand.size() - 1))
				own_hand.append(stolen_card)
				last_play["target_id"] = target_id
				last_play["stolen_card_id"] = str(stolen_card.get("id", ""))
				announcement = "%s의 카드 한 장을 훔쳤다!" % bidder_name(target_id)
			else:
				announcement = "훔칠 카드가 없거나 손패가 가득 찼다."

func _steal_target(player_id: int) -> int:
	if leader != -1 and leader != player_id and active_player_ids.has(leader):
		if not (hands.get(leader, []) as Array).is_empty():
			return leader
	var target_id := -1
	var largest_hand := 0
	for candidate in active_player_ids:
		if candidate == player_id or folded.has(candidate):
			continue
		var candidate_size := (hands.get(candidate, []) as Array).size()
		if candidate_size > largest_hand:
			largest_hand = candidate_size
			target_id = candidate
	return target_id

func start_lot() -> void:
	if cycle > 0:
		for player_id in inventories:
			if not (inventories[player_id] as Array).is_empty() and not sold_this_cycle.has(player_id):
				_record_decision(int(player_id), "hold")
		last_round_decisions = round_decisions.duplicate(true)
		round_decisions.clear()
	last_play.clear()
	final_scores.clear()
	phase = "waiting"
	auction_started = false
	lot = LotRulesScript.make_lot(rng)
	bid = 0
	leader = -1
	folded.clear()
	sold_this_cycle.clear()
	passed_since_bid.clear()
	turn_id = -1
	hammer = 0
	hammer_delay = 0.0
	timer = INITIAL_PREPARATION_SECONDS if cycle == 0 else 0.0
	hint_level = clampi(1 + next_lot_hint_bonus + public_pressure, 1, lot.hints.size())
	next_lot_hint_bonus = 0
	public_pressure = maxi(0, public_pressure - 1)
	public_rumor_shift = 0
	private_hint_indices.clear()
	var hidden_option_count := maxi(1, lot.hints.size() - hint_level)
	hint_deal_offset = rng.randi_range(0, hidden_option_count - 1)
	for player_id in active_player_ids:
		assign_initial_hint(int(player_id))
	for bot_id in BOT_IDS:
		if not bot_strategy.has(bot_id):
			bot_strategy[bot_id] = rng.randi_range(0, 2)
			bot_fortune[bot_id] = rng.randi_range(0, 100)
		bot_bias[bot_id] = rng.randi_range(-50, 50)
	for player_id in energy_by_player:
		var locked := int(locked_energy.get(player_id, 0))
		if int(debt_by_player.get(player_id, 0)) > 0:
			debt_by_player[player_id] = int(debt_by_player[player_id]) + locked * LOAN_INTEREST
		energy_by_player[player_id] = maxi(0, STARTING_ENERGY - locked)
		roulette_used[player_id] = false
		var player_hand: Array = hands.get(player_id, [])
		for draw_index in maxi(0, DEFAULT_HAND_SIZE - player_hand.size()):
			draw_card_for(int(player_id))
	_sync_local_hand()
	announcement = "모두 경매 참여 구역에 들어오면 시작합니다."
	if round_route == "rejected":
		announcement = "유찰 여파로 다음 물품의 공개 힌트가 늘었습니다."
	elif last_round_decisions.values().any(func(decision: String) -> bool: return decision.begins_with("card:publish")):
		announcement = "지난 라운드의 폭로가 소문으로 남았습니다. 공개 힌트가 이어집니다."
	cycle += 1
	emit_state()
	if table_ready:
		begin_auction()

func set_table_status(ready: bool, count: int, total: int) -> void:
	table_ready = ready
	table_count = count
	table_total = total
	if authoritative and table_ready and phase == "appraisal":
		if cycle >= LOTS_PER_MATCH: finish_match()
		else: start_lot()
	elif authoritative and table_ready and not auction_started and phase != "finished":
		begin_auction()
	else:
		emit_state()

func begin_auction() -> void:
	if auction_started:
		return
	_prepare_edited_decks()
	auction_started = true
	phase = "auction"
	turn_id = int(active_player_ids[0]) if not active_player_ids.is_empty() else -1
	if turn_id != -1:
		draw_card_for(turn_id)
		_sync_local_hand()
	timer = TURN_TIME_LIMIT if turn_id != -1 else HAMMER_INTERVAL
	bot_cooldown = BOT_ACTION_DELAY
	announcement = "모두 준비 완료! 경매 시작!"
	emit_state()

func make_bot_bid() -> void:
	var candidates := [turn_id] if active_bot_ids.has(turn_id) else []
	for bot_id in candidates:
		if card_blocked.has(bot_id):
			var bot_hand: Array = hands.get(bot_id, [])
			for index in bot_hand.size():
				if bot_hand[index].get("id", "") in ["shield", "attack"] and int(energy_by_player.get(bot_id, 0)) >= int(bot_hand[index].get("cost", 0)):
					play_card_indices([index], bot_id)
					return
			pass_turn(bot_id)
			return
		var bot_hand: Array = hands.get(bot_id, [])
		if folded.has(bot_id) or bot_id == leader:
			continue
		var estimate := bot_estimate(bot_id)
		var next_bid := 20 if bid == 0 else bid + 20
		if _try_bot_tactic(bot_id, estimate, next_bid):
			return
		var bid_index := _find_card_index(bot_hand, "bid")
		if bid_index < 0:
			var draw_index := _find_card_index(bot_hand, "draw")
			if draw_index >= 0 and int(energy_by_player.get(bot_id, 0)) >= 1:
				play_card_indices([draw_index], bot_id)
			else:
				pass_turn(bot_id)
			return
		var willingness := _bot_bid_limit(bot_id)
		if next_bid > willingness or int(cash.get(bot_id, 0)) < next_bid:
			fold_player(bot_id)
		else:
			if not place_bid(bot_id) and turn_id == bot_id:
				pass_turn(bot_id)
			return

func _find_card_index(player_hand: Array, card_id: String) -> int:
	for index in player_hand.size():
		if player_hand[index].get("id", "") == card_id:
			return index
	return -1

func _shop_for_bot(bot_id: int) -> bool:
	if not authoritative or phase != "appraisal" or cycle >= LOTS_PER_MATCH or not active_bot_ids.has(bot_id) or not active_player_ids.has(bot_id):
		return false
	if market_offers.get(bot_id,[]).is_empty():
		if int(cash.get(bot_id,0)) < MARKET_CARD_COST*2+20 or not buy_market_pack(bot_id): return false
	var preferences: Array = [
		["inspect","publish","draw","bid","shield","luck","attack","steal","rumor","raise","gacha"],
		["rumor","raise","bid","draw","shield","luck","inspect","publish","attack","steal","gacha"],
		["steal","attack","shield","bid","draw","luck","inspect","publish","rumor","raise","gacha"]
	][int(bot_strategy.get(bot_id,0))]
	var offer: Array = market_offers[bot_id]
	var chosen := str(offer[0])
	for id in offer:
		if preferences.find(str(id)) < preferences.find(chosen): chosen = str(id)
	if not buy_market_card(bot_id,chosen): return false
	var total := 0
	var replacement := ""
	var worst_rank := preferences.find(chosen)
	for entry in deck_view(bot_id):
		total += int(entry.active)
		if int(entry.active) <= 0 or (entry.id == "bid" and int(entry.active) <= 2): continue
		var rank := preferences.find(str(entry.id))
		if rank > worst_rank:
			worst_rank = rank
			replacement = str(entry.id)
	if total >= MAX_DECK_SIZE:
		if replacement.is_empty() or not change_deck_card(bot_id,replacement,false): return true
	change_deck_card(bot_id,chosen,true)
	return true

func _try_bot_tactic(bot_id: int, estimate: float, next_bid: int) -> bool:
	var player_hand: Array = hands.get(bot_id, [])
	var energy := int(energy_by_player.get(bot_id, 0))
	var strategy := int(bot_strategy.get(bot_id, posmod(bot_id, 3)))
	var unknown_count: int = int(lot.get("options", []).size()) - hint_level - private_hint_indices.get(bot_id, []).size()
	if strategy == 0 and unknown_count > 0 and energy >= 1:
		var inspect_index := _find_card_index(player_hand, "inspect")
		if inspect_index >= 0:
			play_card_indices([inspect_index], bot_id)
			return true
	if strategy == 0 and hint_level < lot.get("options", []).size() and estimate >= 280.0 and energy >= 1:
		var publish_index := _find_card_index(player_hand, "publish")
		if publish_index >= 0:
			play_card_indices([publish_index], bot_id)
			return true
	if strategy == 1 and energy >= 1 and bid >= 40 and next_bid <= estimate + 40.0:
		var rumor_index := _find_card_index(player_hand, "rumor")
		if rumor_index >= 0:
			play_card_indices([rumor_index], bot_id)
			return true
	if strategy == 2 and leader != -1 and leader != bot_id and energy >= 2:
		var steal_index := _find_card_index(player_hand, "steal")
		if steal_index >= 0:
			play_card_indices([steal_index], bot_id)
			return true
	if int(bot_fortune.get(bot_id, 50)) >= 65 and energy >= 1:
		var luck_index := _find_card_index(player_hand, "luck")
		if luck_index >= 0:
			play_card_indices([luck_index], bot_id)
			return true
	return false

func score_for(player_id: int) -> int:
	var score := int(cash.get(player_id, 0)) - int(debt_by_player.get(player_id, 0))
	for item in inventories.get(player_id, []):
		score += int(item.get("appraisal", 0))
	return score

func bot_estimate(bot_id: int) -> float:
	return LotRulesScript.estimate(
		lot,
		hint_level,
		private_hint_indices.get(bot_id, []),
		float(bot_bias.get(bot_id, 0)) + (float(bot_fortune.get(bot_id, 50)) - 50.0) * 0.25,
		[0.85, 1.0, 1.15][posmod(bot_id - 100, 3)],
	)

func public_value_range() -> Array[int]:
	var lower := int(LotRulesScript.BASE_VALUE) + int(LotRulesScript.VALUE_NOISE_MIN)
	var upper := int(LotRulesScript.BASE_VALUE) + int(LotRulesScript.VALUE_NOISE_MAX)
	var options: Array = lot.get("options", [])
	for index in options.size():
		var option: Dictionary = options[index]
		var weight := int(option.get("weight", 0))
		if index < hint_level:
			var known_value := int(option.get("level", 3)) * weight
			lower += known_value
			upper += known_value
		else:
			lower += int(LotRulesScript.MIN_LEVEL) * weight
			upper += int(LotRulesScript.MAX_LEVEL) * weight
	lower += public_rumor_shift
	upper += public_rumor_shift
	return [maxi(20, lower), maxi(20, upper)]

func close_auction() -> void:
	phase = "appraisal"
	timer = INTERMISSION_SECONDS
	if leader != -1:
		round_route = "sold"
		register_player(leader)
		cash[leader] -= bid
		var appraisal: int = LotRulesScript.appraise(lot, rng)
		inventories[leader].append({"name": lot.name, "paid": bid, "appraisal": appraisal})
		announcement = "%s 낙찰! 감정 후 판매할 수 있다." % bidder_name(leader)
	else:
		round_route = "rejected"
		next_lot_hint_bonus = 1
		announcement = "유찰. 보유 물품을 감정하고 판매할 수 있다."
	var result_announcement := announcement
	for bot_id in active_bot_ids:
		if not inventories.get(bot_id, []).is_empty():
			sell_item(bot_id, 0)
		_shop_for_bot(bot_id)
	announcement = result_announcement

func request_sell(index: int) -> void:
	if not authoritative:
		action_requested.emit("sell:%d" % index)
		return
	sell_item(local_player_id, index)

func sell_item(player_id: int, index: int) -> bool:
	if phase != "appraisal" or not active_player_ids.has(player_id) or sold_this_cycle.has(player_id):
		return false
	var items: Array = inventories.get(player_id, [])
	if index < 0 or index >= items.size():
		return false
	var item: Dictionary = items.pop_at(index)
	cash[player_id] = int(cash.get(player_id, 0)) + int(item.get("appraisal", 0))
	sold_this_cycle.append(player_id)
	_record_decision(player_id, "sell", str(int(item.get("appraisal", 0))))
	announcement = "%s 물품 판매! %d 보풀 획득" % [bidder_name(player_id), int(item.get("appraisal", 0))]
	emit_state()
	return true

func final_standings() -> Array:
	if phase != "finished": return []
	if not authoritative: return remote_final_standings.duplicate(true)
	var rows: Array = []
	for player_id in final_scores:
		var id := int(player_id)
		var goods := 0
		for item in inventories.get(id,[]): goods += int(item.get("appraisal",0))
		rows.append({"id":id,"name":bidder_name(id),"cash":int(cash.get(id,0)),"goods":goods,"debt":int(debt_by_player.get(id,0)),"score":int(final_scores[id])})
	rows.sort_custom(func(a: Dictionary,b: Dictionary) -> bool: return a.score > b.score if a.score != b.score else a.id < b.id)
	var rank := 0
	var last_score := 0
	for index in rows.size():
		if index == 0 or int(rows[index].score) != last_score: rank = index+1
		rows[index]["rank"] = rank
		last_score = int(rows[index].score)
	return rows

func finish_match() -> void:
	phase = "finished"
	auction_started = false
	final_scores.clear()
	for player_id in active_player_ids:
		final_scores[player_id] = score_for(int(player_id))
	var winners: Array[String] = []
	var standings := final_standings()
	for row in standings:
		if row.rank == 1: winners.append(str(row.name))
	announcement = "경매 종료! %s %s" % [", ".join(winners),"공동 우승" if winners.size() > 1 else "우승"]
	timer = 0.0
	emit_state()

func bidder_name(player_id: int) -> String:
	return str(player_names.get(player_id, Identity.bot_name(player_id) if BOT_IDS.has(player_id) else "PLAYER-%d" % player_id))

func state() -> Dictionary:
	var visible_hints: Array = []
	if authoritative:
		for index in hint_level:
			visible_hints.append(lot.hints[index])
	else:
		visible_hints = remote_hints.duplicate()
	var hand_counts := {}
	if authoritative:
		for player_id in hands:
			hand_counts[str(player_id)] = hands[player_id].size()
	else:
		hand_counts = remote_hand_counts.duplicate()
	var private_by_player := {}
	if authoritative:
		for player_id in private_hint_indices:
			var hints_for_player: Array = []
			for index in private_hint_indices[player_id]:
				if index >= hint_level:
					hints_for_player.append(lot.hints[index])
			private_by_player[player_id] = hints_for_player
	var own_private: Array = private_by_player.get(local_player_id, []) if authoritative else remote_private_hints
	var own_inventory: Array = inventories.get(local_player_id, []) if authoritative else remote_inventory
	var bot_archetypes := remote_bot_archetypes.duplicate()
	if authoritative:
		bot_archetypes.clear()
		for bot_id in bot_strategy:
			bot_archetypes[str(bot_id)] = BOT_ARCHETYPE_NAMES[int(bot_strategy[bot_id])]
	var shown_value_range: Array = public_value_range() if authoritative else remote_value_range
	var shown_leader_name := bidder_name(leader) if authoritative and leader != -1 else (remote_leader_name if not authoritative else "없음")
	return {"final_standings":final_standings(), "turn_name": bidder_name(turn_id) if authoritative else remote_turn_name, "leader_name": shown_leader_name, "market_offers": market_offers.duplicate(true) if authoritative else {}, "market_offer": market_offers.get(local_player_id, []) if authoritative else remote_market_offer, "pile_counts": pile_counts(local_player_id), "all_pile_counts": all_pile_counts(), "deck_view": deck_view(local_player_id), "deck_views": all_deck_views(), "lot": lot, "bid": bid, "leader": leader, "turn_id": turn_id, "folded": folded.duplicate(), "card_blocked": card_blocked.duplicate(), "last_play": last_play.duplicate(true), "player_weapons": player_weapons.duplicate(), "hammer": hammer, "timer": maxf(timer, 0.0), "phase": phase, "cycle": cycle, "goal": MATCH_GOAL_TEXT, "goal_rounds": LOTS_PER_MATCH, "round_route": round_route, "round_decisions": round_decisions.duplicate(true), "last_round_decisions": last_round_decisions.duplicate(true), "decision_history": decision_history.duplicate(true), "bot_archetypes": bot_archetypes, "hints": visible_hints, "private_hints": own_private, "private_hints_by_player": private_by_player, "inventory": own_inventory, "inventories": inventories, "value_range": shown_value_range, "rumor_shift": public_rumor_shift, "sold": sold_this_cycle.has(local_player_id) if authoritative else remote_sold, "sold_players": sold_this_cycle.duplicate(), "cash": cash, "locked_energy": locked_energy, "debt": debt_by_player, "roulette_used": roulette_used, "final_scores": final_scores.duplicate(), "announcement": announcement, "energy": card_energy, "hand": hand, "hands": hands, "energies": energy_by_player, "hand_counts": hand_counts, "table_ready": table_ready, "table_count": table_count, "table_total": table_total}

func emit_state() -> void:
	changed.emit(state())

func set_authoritative(value: bool) -> void:
	authoritative = value

func apply_remote_state(remote_state: Dictionary) -> void:
	remote_final_standings = remote_state.get("final_standings",[])
	remote_turn_name = str(remote_state.get("turn_name", "참가자"))
	remote_leader_name = str(remote_state.get("leader_name", remote_leader_name))
	remote_market_offer = remote_state.get("market_offer", [])
	remote_deck_view = remote_state.get("deck_view", [])
	remote_pile_counts = remote_state.get("pile_counts",{"draw":0,"discard":0})
	lot = remote_state.get("lot", lot)
	cash = remote_state.get("cash", cash)
	locked_energy = remote_state.get("locked_energy", locked_energy)
	debt_by_player = remote_state.get("debt", debt_by_player)
	roulette_used = remote_state.get("roulette_used", roulette_used)
	bid = int(remote_state.get("bid", bid))
	leader = int(remote_state.get("leader", leader))
	turn_id = int(remote_state.get("turn_id", -1))
	folded = remote_state.get("folded", [])
	card_blocked = remote_state.get("card_blocked", [])
	last_play = remote_state.get("last_play", {})
	player_weapons = remote_state.get("player_weapons", {})
	hammer = int(remote_state.get("hammer", hammer))
	timer = float(remote_state.get("timer", timer))
	phase = str(remote_state.get("phase", phase))
	cycle = int(remote_state.get("cycle", cycle))
	round_route = str(remote_state.get("round_route", round_route))
	round_decisions = remote_state.get("round_decisions", round_decisions)
	last_round_decisions = remote_state.get("last_round_decisions", last_round_decisions)
	decision_history = remote_state.get("decision_history", decision_history)
	remote_bot_archetypes = remote_state.get("bot_archetypes", remote_bot_archetypes)
	hint_level = int(remote_state.get("hints", []).size())
	remote_hints = remote_state.get("hints", [])
	remote_value_range = remote_state.get("value_range", remote_value_range)
	public_rumor_shift = int(remote_state.get("rumor_shift", public_rumor_shift))
	remote_private_hints = remote_state.get("private_hints", [])
	remote_inventory = remote_state.get("inventory", [])
	remote_sold = bool(remote_state.get("sold", false))
	final_scores = remote_state.get("final_scores", final_scores)
	announcement = str(remote_state.get("announcement", announcement))
	card_energy = int(remote_state.get("energy", card_energy))
	hand = remote_state.get("hand", hand)
	remote_hand_counts = remote_state.get("hand_counts", {})
	energy_by_player = remote_state.get("energies", energy_by_player)
	if remote_state.has("hands"):
		hands = remote_state.get("hands", hands)
		_sync_local_hand()
	else:
		hands[local_player_id] = hand
	table_ready = bool(remote_state.get("table_ready", table_ready))
	table_count = int(remote_state.get("table_count", table_count))
	table_total = int(remote_state.get("table_total", table_total))
	auction_started = str(remote_state.get("phase", phase)) == "auction" or str(remote_state.get("phase", phase)) == "appraisal"
	changed.emit(state())
