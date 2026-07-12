extends SceneTree
## 黑白棋邏輯單元測試。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_reversi_logic.gd

const Logic := preload("res://scripts/reversi/reversi_logic.gd")

var failures := 0


func _initialize() -> void:
	_test_initial_moves()
	_test_flips()
	_test_pass_and_end()
	_test_ai_vs_ai()
	_test_expert_speed()

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


func _test_initial_moves() -> void:
	var b := Logic.initial_board()
	var c := Logic.count(b)
	_check(c[0] == 2 and c[1] == 2, "初始盤面黑白各 2 子")
	var moves := Logic.legal_moves(b, Logic.BLACK)
	moves.sort()
	var expected := [Logic.idx(3, 2), Logic.idx(2, 3), Logic.idx(5, 4), Logic.idx(4, 5)]
	expected.sort()
	_check(moves == expected, "黑棋開局 4 個合法手（%s）" % str(moves))


func _test_flips() -> void:
	var b := Logic.initial_board()
	# 黑下 (3,2)：翻轉 (3,3) 的白子
	var fl := Logic.flips_for(b, Logic.BLACK, Logic.idx(3, 2))
	_check(fl.size() == 1 and fl[0] == Logic.idx(3, 3), "開局落子翻轉正確")
	Logic.apply_move(b, Logic.BLACK, Logic.idx(3, 2), fl)
	var c := Logic.count(b)
	_check(c[0] == 4 and c[1] == 1, "翻轉後黑 4 白 1")
	# 已占用的格子不是合法手
	_check(Logic.flips_for(b, Logic.WHITE, Logic.idx(3, 3)).is_empty(), "已占用格非法")
	# 多方向翻轉：自製局面 黑(0,0) 白(1,0)(2,0)，黑下(3,0) 應翻 2 子
	var b2: Array[int] = []
	b2.resize(Logic.CELLS)
	b2[Logic.idx(0, 0)] = Logic.BLACK
	b2[Logic.idx(1, 0)] = Logic.WHITE
	b2[Logic.idx(2, 0)] = Logic.WHITE
	var fl2 := Logic.flips_for(b2, Logic.BLACK, Logic.idx(3, 0))
	_check(fl2.size() == 2, "整排夾吃翻轉 2 子")


func _test_pass_and_end() -> void:
	# 自製終局：黑無合法手、白也無 → 遊戲結束
	var b: Array[int] = []
	b.resize(Logic.CELLS)
	for i in Logic.CELLS:
		b[i] = Logic.BLACK
	b[0] = Logic.EMPTY
	_check(not Logic.has_move(b, Logic.BLACK) and not Logic.has_move(b, Logic.WHITE), "無夾吃可能時雙方皆無合法手")
	var c := Logic.count(b)
	_check(c[0] == 63 and c[1] == 0, "終局計數正確")


func _test_ai_vs_ai() -> void:
	# 普通 vs 困難完整對局：必須合法走完（含跳過），總子數守恆
	var b := Logic.initial_board()
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	var player := Logic.BLACK
	var passes := 0
	var t0 := Time.get_ticks_msec()
	var steps := 0
	while passes < 2 and steps < 200:
		var diff: int = Logic.Difficulty.NORMAL if player == Logic.BLACK else Logic.Difficulty.HARD
		var mv: int = Logic.choose_move(b, player, diff, rng)
		if mv < 0:
			passes += 1
		else:
			passes = 0
			var fl := Logic.flips_for(b, player, mv)
			if fl.is_empty():
				_check(false, "AI 回傳非法手")
				return
			Logic.apply_move(b, player, mv, fl)
		player = Logic.opponent(player)
		steps += 1
	var ms := Time.get_ticks_msec() - t0
	var c := Logic.count(b)
	print("AI 對弈：黑 %d 白 %d、共 %d 步、%d ms" % [c[0], c[1], steps, ms])
	_check(c[0] + c[1] + Logic.empties(b) == 64, "子數守恆")
	_check(passes >= 2 or Logic.empties(b) == 0, "對局正常結束")


func _test_expert_speed() -> void:
	# 專家級（深度 4）中盤單手思考時間
	var b := Logic.initial_board()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	# 先用普通級走 12 步做出中盤局面
	var player := Logic.BLACK
	for k in 12:
		var mv: int = Logic.choose_move(b, player, Logic.Difficulty.NORMAL, rng)
		if mv >= 0:
			Logic.apply_move(b, player, mv, Logic.flips_for(b, player, mv))
		player = Logic.opponent(player)
	var t0 := Time.get_ticks_msec()
	var mv2: int = Logic.choose_move(b, player, Logic.Difficulty.EXPERT, rng)
	var ms := Time.get_ticks_msec() - t0
	print("專家級中盤一手：%d ms" % ms)
	_check(mv2 >= 0 and not Logic.flips_for(b, player, mv2).is_empty(), "專家級回傳合法手")
	_check(ms < 5000, "專家級單手 < 5 秒")
