extends SceneTree
## 踩地雷邏輯單元測試。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_minesweeper_logic.gd

const Logic := preload("res://scripts/minesweeper/minesweeper_logic.gd")

var failures := 0


func _initialize() -> void:
	_test_neighbors()
	_test_generate()
	_test_flood()
	_test_win()
	_test_all_difficulties()

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


func _test_neighbors() -> void:
	_check(Logic.neighbors(9, 9, 0).size() == 3, "角落 3 個鄰居")
	_check(Logic.neighbors(9, 9, 4).size() == 5, "邊緣 5 個鄰居")
	_check(Logic.neighbors(9, 9, 40).size() == 8, "中央 8 個鄰居")


func _test_generate() -> void:
	var safe := 40  # 中央
	var gen := Logic.generate(9, 9, 10, _rng(7), safe)
	var mines: Array[bool] = gen["mines"]
	var counts: Array[int] = gen["counts"]
	var n := 0
	for m in mines:
		if m:
			n += 1
	_check(n == 10, "地雷數正確（%d）" % n)
	_check(not mines[safe], "首挖格無雷")
	var neighbors_safe := true
	for j in Logic.neighbors(9, 9, safe):
		if mines[j]:
			neighbors_safe = false
	_check(neighbors_safe, "首挖周圍無雷")
	# 數字正確性抽查：每個非雷格的 counts = 周圍雷數
	var counts_ok := true
	for i in 81:
		if mines[i]:
			if counts[i] != -1:
				counts_ok = false
			continue
		var expect := 0
		for j in Logic.neighbors(9, 9, i):
			if mines[j]:
				expect += 1
		if counts[i] != expect:
			counts_ok = false
	_check(counts_ok, "周圍雷數計算正確")
	# 同種子同首挖 → 同盤面（每日挑戰依賴）
	var gen2 := Logic.generate(9, 9, 10, _rng(7), safe)
	_check(gen2["mines"] == gen["mines"], "同種子產生相同佈雷")


func _test_flood() -> void:
	var gen := Logic.generate(9, 9, 10, _rng(3), 40)
	var mines: Array[bool] = gen["mines"]
	var counts: Array[int] = gen["counts"]
	var revealed: Array[bool] = []
	revealed.resize(81)
	var flagged: Array[bool] = []
	flagged.resize(81)
	var opened := Logic.flood_reveal(9, 9, mines, counts, revealed, flagged, 40)
	_check(opened.size() >= 1, "翻開至少一格")
	# 首挖周圍保證安全 → counts[40] == 0 → 必定連鎖展開
	_check(counts[40] == 0 and opened.size() >= 9, "0 格連鎖展開（開了 %d 格）" % opened.size())
	var no_mine_opened := true
	for i in opened:
		if mines[i]:
			no_mine_opened = false
	_check(no_mine_opened, "連鎖不翻開地雷")


func _test_win() -> void:
	var mines: Array[bool] = [true, false, false, false]
	var revealed: Array[bool] = [false, true, true, false]
	_check(not Logic.is_win(mines, revealed), "未全開不算贏")
	revealed[3] = true
	_check(Logic.is_win(mines, revealed), "非雷格全開即贏")


func _test_all_difficulties() -> void:
	for d in Logic.Difficulty.values():
		var cfg: Dictionary = Logic.CONFIG[d]
		var w := int(cfg["w"])
		var h := int(cfg["h"])
		var gen := Logic.generate(w, h, int(cfg["mines"]), _rng(d + 1), 0)
		var n := 0
		for m in gen["mines"]:
			if m:
				n += 1
		_check(n == int(cfg["mines"]), "難度 %d：%d×%d 佈 %d 雷" % [d, w, h, n])
