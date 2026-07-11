extends Node
## 全流程自動化測試：模擬玩家操作首頁與數獨畫面。
## 執行方式（PowerShell）：
##   $env:BRAINCLUB_AUTOTEST = "1"; Godot執行檔 --headless --path 專案目錄
## 全部通過會印出 [autotest] PASS 並以代碼 0 結束。


func _ready() -> void:
	# 逾時保險：測試卡住時不要讓程序掛著
	var watchdog := get_tree().create_timer(30.0)
	watchdog.timeout.connect(_on_timeout)
	_run.call_deferred()


func _on_timeout() -> void:
	printerr("[autotest] TIMEOUT")
	get_tree().quit(1)


func _run() -> void:
	var tree := get_tree()
	await tree.process_frame
	await tree.process_frame

	var main := Main.instance
	_check(main.current_screen() is HomeScreen, "首頁未建立")
	print("[autotest] 首頁 OK")

	main.open_sudoku({"mode": "normal", "difficulty": SudokuLogic.Difficulty.EASY, "seed": 123})
	await tree.process_frame
	var screen := main.current_screen() as SudokuScreen
	_check(screen != null, "數獨畫面未建立")

	# 輸入正確數字
	var idx := -1
	for i in 81:
		if not screen.board.given[i]:
			idx = i
			break
	screen._on_cell_pressed(idx)
	screen._on_number(screen.solution[idx])
	_check(screen.board.values[idx] == screen.solution[idx], "輸入正確數字失敗")
	_check(screen.mistakes == 0, "正確輸入不應計入錯誤")

	# 筆記模式
	var idx2 := -1
	for i in 81:
		if screen.board.values[i] == 0:
			idx2 = i
			break
	screen._on_cell_pressed(idx2)
	screen.notes_mode = true
	screen._on_number(5)
	_check(screen.board.notes[idx2] == 1 << 4, "筆記寫入失敗")
	screen._on_number(5)
	_check(screen.board.notes[idx2] == 0, "筆記切換清除失敗")
	screen.notes_mode = false

	# 錯誤輸入與復原
	var wrong: int = screen.solution[idx2] % 9 + 1
	screen._on_number(wrong)
	_check(screen.mistakes == 1, "錯誤計數失敗")
	_check(screen.board.errors[idx2], "錯誤格未標記")
	screen._on_undo()
	_check(screen.board.values[idx2] == 0, "復原失敗")

	# 擦除與提示
	screen._on_cell_pressed(idx2)
	screen._on_hint()
	_check(screen.board.values[idx2] == screen.solution[idx2], "提示失敗")
	await _shot("sudoku.png")

	# 存檔還原
	var saved := SaveManager.get_in_progress()
	_check(not saved.is_empty(), "進行中存檔遺失")
	print("[autotest] 數獨操作 OK")

	main.goto_home()
	await tree.process_frame
	_check(main.current_screen() is HomeScreen, "返回首頁失敗")
	print("[autotest] 返回首頁 OK")

	# 還原剛才的進度
	main.open_sudoku({"mode": "resume"})
	await tree.process_frame
	var resumed := main.current_screen() as SudokuScreen
	_check(resumed != null, "續玩畫面未建立")
	_check(resumed.board.values[idx2] == resumed.solution[idx2], "續玩資料還原失敗")
	print("[autotest] 存檔續玩 OK")

	# ---- 五子棋 ----
	main.goto_home()
	await tree.process_frame
	main.open_gomoku({"mode": "normal", "difficulty": GomokuLogic.Difficulty.BEGINNER})
	await tree.process_frame
	var g := main.current_screen() as GomokuScreen
	_check(g != null, "五子棋畫面未建立")

	# 玩家下中央，等 AI 回應（背景執行緒）
	g._on_cell_pressed(GomokuLogic.idx(7, 7))
	_check(g.moves.size() == 1, "玩家落子失敗")
	await _wait_for_ai(g)
	_check(g.moves.size() == 2, "AI 未回應")
	_check(g.board.stones[g.moves[1]] == GomokuLogic.WHITE, "AI 落子顏色錯誤")

	# 悔棋收回雙方各一手
	g._on_undo()
	_check(g.moves.size() == 0, "悔棋失敗")

	# 再下一手並測試存檔續玩
	g._on_cell_pressed(GomokuLogic.idx(7, 7))
	await _wait_for_ai(g)
	await _shot("gomoku.png")
	var saved_moves: int = g.moves.size()
	main.goto_home()
	await tree.process_frame
	main.open_gomoku({"mode": "resume"})
	await tree.process_frame
	var g2 := main.current_screen() as GomokuScreen
	_check(g2 != null, "五子棋續玩畫面未建立")
	_check(g2.moves.size() == saved_moves, "五子棋續玩還原失敗")

	# 重新開始必須清空棋盤
	g2._new_game()
	_check(g2.moves.is_empty(), "重新開始未清空手數")
	var leftover := 0
	for i in GomokuLogic.CELLS:
		if g2.board.stones[i] != GomokuLogic.EMPTY:
			leftover += 1
	_check(leftover == 0, "重新開始後棋盤仍有殘子")
	_check(g2.board.last_move == -1, "重新開始未清除最後一手標記")
	print("[autotest] 五子棋 OK")

	print("[autotest] PASS")
	get_tree().quit(0)


## 等待五子棋 AI 執行緒完成並套用落子
func _wait_for_ai(g: GomokuScreen) -> void:
	var tries := 0
	while g._ai_pending or g._ai_thread != null:
		await get_tree().process_frame
		tries += 1
		if tries > 600:
			_check(false, "等待 AI 逾時")
			return


func _check(cond: bool, msg: String) -> void:
	if not cond:
		printerr("[autotest] FAIL：" + msg)
		get_tree().quit(1)


## 視覺驗證：設定 BRAINCLUB_SHOT=資料夾 且非 headless 時，存下畫面截圖
func _shot(fname: String) -> void:
	var dir := OS.get_environment("BRAINCLUB_SHOT")
	if dir == "" or DisplayServer.get_name() == "headless":
		return
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(fname))
	print("[autotest] 截圖：" + fname)
