extends SceneTree
## 五子棋邏輯單元測試。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_gomoku_logic.gd

const Logic := preload("res://scripts/gomoku/gomoku_logic.gd")

var failures := 0


func _initialize() -> void:
	_test_win_detection()
	_test_immediate_win()
	_test_block()
	_test_ai_vs_ai()
	_test_expert_speed()

	if failures == 0:
		print("[test] PASS")
		quit(0)
	else:
		print("[test] FAIL（%d 項）" % failures)
		quit(1)


func _empty_board() -> Array[int]:
	var b: Array[int] = []
	b.resize(Logic.CELLS)
	return b


func _place(board: Array[int], cells: Array, p: int) -> void:
	for c in cells:
		board[Logic.idx(c[0], c[1])] = p


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK：" + msg)
	else:
		print("FAIL：" + msg)
		failures += 1


func _test_win_detection() -> void:
	# 橫向五連
	var b := _empty_board()
	_place(b, [[3, 7], [4, 7], [5, 7], [6, 7], [7, 7]], Logic.BLACK)
	_check(Logic.check_win(b, Logic.idx(5, 7)), "橫向五連判定")

	# 直向四連不算贏
	var b2 := _empty_board()
	_place(b2, [[7, 3], [7, 4], [7, 5], [7, 6]], Logic.WHITE)
	_check(not Logic.check_win(b2, Logic.idx(7, 5)), "四連不判贏")

	# 斜向五連
	var b3 := _empty_board()
	_place(b3, [[2, 2], [3, 3], [4, 4], [5, 5], [6, 6]], Logic.BLACK)
	_check(Logic.check_win(b3, Logic.idx(4, 4)), "斜向五連判定")

	# 反斜五連
	var b4 := _empty_board()
	_place(b4, [[10, 2], [9, 3], [8, 4], [7, 5], [6, 6]], Logic.WHITE)
	_check(Logic.check_win(b4, Logic.idx(8, 4)), "反斜五連判定")


func _test_immediate_win() -> void:
	# 白棋已有四連（一端開放），AI 必須下在致勝點
	var b := _empty_board()
	_place(b, [[3, 7], [4, 7], [5, 7], [6, 7]], Logic.WHITE)
	_place(b, [[3, 8], [4, 8], [5, 8]], Logic.BLACK)
	b[Logic.idx(2, 7)] = Logic.BLACK  # 堵住左端，只剩 (7,7) 能贏
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for diff in Logic.Difficulty.values():
		var mv: int = Logic.choose_move(b.duplicate(), Logic.WHITE, diff, rng)
		_check(mv == Logic.idx(7, 7), "難度 %d 取即勝點" % diff)


func _test_block() -> void:
	# 黑棋四連只剩一個活口，AI（普通以上）必須擋
	var b := _empty_board()
	_place(b, [[3, 7], [4, 7], [5, 7], [6, 7]], Logic.BLACK)
	b[Logic.idx(2, 7)] = Logic.WHITE  # 左端已堵，威脅點只剩 (7,7)
	_place(b, [[4, 6], [5, 6]], Logic.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	for diff in [Logic.Difficulty.NORMAL, Logic.Difficulty.HARD, Logic.Difficulty.EXPERT]:
		var mv: int = Logic.choose_move(b.duplicate(), Logic.WHITE, diff, rng)
		_check(mv == Logic.idx(7, 7), "難度 %d 擋對手即勝點" % diff)


func _test_ai_vs_ai() -> void:
	# 普通 vs 困難完整對局：必須正常結束且不逾時
	var b := _empty_board()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var t0 := Time.get_ticks_msec()
	var player := Logic.BLACK
	var winner := 0
	var n := 0
	while n < Logic.CELLS:
		var diff: int = Logic.Difficulty.NORMAL if player == Logic.BLACK else Logic.Difficulty.HARD
		var mv: int = Logic.choose_move(b, player, diff, rng)
		if mv < 0:
			break
		b[mv] = player
		n += 1
		if Logic.check_win(b, mv):
			winner = player
			break
		player = Logic.opponent(player)
	var ms := Time.get_ticks_msec() - t0
	print("AI 對弈：%d 手，勝方 %d，共 %d ms（平均 %d ms/手）" % [n, winner, ms, ms / maxi(n, 1)])
	_check(winner != 0 or n >= Logic.CELLS, "AI 對弈正常結束")
	_check(ms / maxi(n, 1) < 3000, "每手思考時間 < 3 秒")


func _test_expert_speed() -> void:
	# 中盤局面下，專家級（深度 3）單手思考時間必須在行動裝置可接受範圍
	var b := _empty_board()
	_place(b, [[7, 7], [8, 8], [6, 6], [9, 7], [7, 9], [6, 8]], Logic.BLACK)
	_place(b, [[8, 7], [7, 8], [9, 9], [6, 7], [8, 6], [10, 8]], Logic.WHITE)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	var t0 := Time.get_ticks_msec()
	var mv: int = Logic.choose_move(b, Logic.WHITE, Logic.Difficulty.EXPERT, rng)
	var ms := Time.get_ticks_msec() - t0
	print("專家級中盤一手：%d ms" % ms)
	_check(mv >= 0 and b[mv] == Logic.EMPTY, "專家級回傳合法手")
	_check(ms < 5000, "專家級單手 < 5 秒")
