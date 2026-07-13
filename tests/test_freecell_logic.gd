extends SceneTree
## 新接龍邏輯單元測試。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_freecell_logic.gd

const Logic := preload("res://scripts/freecell/freecell_logic.gd")
const Cards := preload("res://scripts/solitaire/solitaire_logic.gd")

var failures := 0


func _initialize() -> void:
	_test_deal()
	_test_run_rules()
	_test_supermove_cap()

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


func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = s
	return r


func _test_deal() -> void:
	var deal := Logic.new_deal(_rng(42))
	var seen := {}
	var total := 0
	for col in deal["cascades"]:
		for card in col:
			seen[card] = true
			total += 1
	_check(total == 52 and seen.size() == 52, "發牌 52 張不重複、全部明牌")
	var sizes_ok := true
	for c in 8:
		var expect := 7 if c < 4 else 6
		if (deal["cascades"][c] as Array).size() != expect:
			sizes_ok = false
	_check(sizes_ok, "前四列 7 張、後四列 6 張")
	_check((deal["free"] as Array).size() == 4, "四個自由格")
	# 同種子重現（每日挑戰依賴）
	var deal2 := Logic.new_deal(_rng(42))
	_check(deal2["cascades"] == deal["cascades"], "同種子同牌局")


func _test_run_rules() -> void:
	# 紅 Q(24)、黑 J(10)、紅 10(35=方塊10? 26+9=35) → 遞減紅黑交錯
	var run: Array = [12, 24, 10]  # 黑K、紅Q、黑J
	_check(Logic.is_valid_run(run), "合法連續段判定")
	_check(not Logic.is_valid_run([12, 11]), "同色連續段不合法")
	_check(not Logic.is_valid_run([12, 23]), "點數跳號不合法")
	_check(Logic.is_valid_run([5]), "單張必為合法段")


func _test_supermove_cap() -> void:
	# (空自由格+1) × 2^空列
	_check(Logic.max_run_size(4, 0, false) == 5, "4 自由格無空列可搬 5 張")
	_check(Logic.max_run_size(0, 0, false) == 1, "無資源只能搬 1 張")
	_check(Logic.max_run_size(2, 1, false) == 6, "2 自由格 1 空列可搬 6 張")
	_check(Logic.max_run_size(1, 1, true) == 2, "搬進空列時該列不計入")
	var free: Array[int] = [-1, 5, -1, -1]
	_check(Logic.count_free_slots(free) == 3, "空自由格計數")
	_check(Logic.count_empty_cascades([[], [1], [], [2, 3]]) == 2, "空列計數")
