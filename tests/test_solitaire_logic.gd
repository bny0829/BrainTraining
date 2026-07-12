extends SceneTree
## 接龍邏輯單元測試。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_solitaire_logic.gd

const Logic := preload("res://scripts/solitaire/solitaire_logic.gd")

var failures := 0


func _initialize() -> void:
	_test_card_helpers()
	_test_deal()
	_test_rules()

	if failures == 0:
		print("[test] PASS")
		quit(0)
	else:
		print("[test] FAIL（%d 項）" % failures)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK：" + msg)
	else:
		print("FAIL：" + msg)
		failures += 1


func _test_card_helpers() -> void:
	_check(Logic.suit_of(0) == Logic.SPADE and Logic.rank_of(0) == 0, "0 = 黑桃 A")
	_check(Logic.suit_of(51) == Logic.CLUB and Logic.rank_of(51) == 12, "51 = 梅花 K")
	_check(Logic.is_red(13) and Logic.is_red(26), "紅心與方塊是紅色")
	_check(not Logic.is_red(0) and not Logic.is_red(39), "黑桃與梅花是黑色")


func _test_deal() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	var deal := Logic.new_deal(rng)
	# 52 張不重複
	var seen := {}
	var total := 0
	for card in deal["stock"]:
		seen[card] = true
		total += 1
	for col in deal["columns"]:
		for card in col:
			seen[card] = true
			total += 1
	_check(total == 52 and seen.size() == 52, "發牌 52 張不重複")
	# 牌桌 1~7 張、庫存 24 張
	var sizes_ok := true
	for c in 7:
		if (deal["columns"][c] as Array).size() != c + 1:
			sizes_ok = false
	_check(sizes_ok, "七列各 1~7 張")
	_check((deal["stock"] as Array).size() == 24, "庫存 24 張")
	# 同種子重現
	var rng2 := RandomNumberGenerator.new()
	rng2.seed = 42
	var deal2 := Logic.new_deal(rng2)
	_check(deal2["stock"] == deal["stock"] and deal2["columns"] == deal["columns"], "同種子同牌局")


func _test_rules() -> void:
	# 牌桌疊牌：紅 Q(紅心 Q = 13+11 = 24) 可疊在黑 K(黑桃 K = 12) 上
	_check(Logic.can_stack(24, 12), "紅 Q 疊黑 K")
	_check(not Logic.can_stack(11, 12), "同色不能疊")
	_check(not Logic.can_stack(24, 11), "點數不連續不能疊")
	# 基礎堆
	_check(Logic.can_foundation(0, []), "空基礎堆收 A")
	_check(not Logic.can_foundation(5, []), "空基礎堆不收其他牌")
	_check(Logic.can_foundation(1, [0]), "同花 2 疊 A")
	_check(not Logic.can_foundation(14, [0]), "異花不能疊基礎堆")
	# 勝利判定
	var full: Array = [[], [], [], []]
	for s in 4:
		for r in 13:
			(full[s] as Array).append(s * 13 + r)
	_check(Logic.is_won(full), "52 張上基礎堆即勝")
	_check(not Logic.is_won([[], [], [], [0]]), "未收完不算勝")
