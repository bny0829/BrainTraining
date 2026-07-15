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
	await _shot("home.png")
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
	var saved := SaveManager.get_in_progress("sudoku")
	_check(not saved.is_empty(), "進行中存檔遺失")
	# 怎麼玩彈窗
	screen._show_how_to_play()
	await tree.process_frame
	await _shot("sudoku_howto.png")
	var sk_dlg: Array[Button] = []
	_collect_buttons(screen, sk_dlg)
	var sk_has_ok := false
	for b in sk_dlg:
		if b.text == "確定":
			sk_has_ok = true
			b.pressed.emit()
	_check(sk_has_ok, "數獨怎麼玩彈窗未建立")
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
	# 提示：輪到玩家時應標示一個合法的建議落點
	g2._on_hint()
	_check(g2.board.hint_index >= 0 and g2.board.stones[g2.board.hint_index] == GomokuLogic.EMPTY,
			"五子棋提示未標示合法落點")
	await _shot("gomoku_hint.png")
	# 怎麼玩彈窗
	g2._show_how_to_play()
	await tree.process_frame
	var g2_dlg: Array[Button] = []
	_collect_buttons(g2, g2_dlg)
	var g2_has_ok := false
	for b in g2_dlg:
		if b.text == "確定":
			g2_has_ok = true
			b.pressed.emit()
	_check(g2_has_ok, "五子棋怎麼玩彈窗未建立")
	print("[autotest] 五子棋 OK")

	# ---- 黑白棋 ----
	main.goto_home()
	await tree.process_frame
	main.open_reversi({"mode": "normal", "difficulty": ReversiLogic.Difficulty.BEGINNER})
	await tree.process_frame
	var rv := main.current_screen() as ReversiScreen
	_check(rv != null, "黑白棋畫面未建立")
	_check(not rv.board.hints.is_empty(), "開局未顯示合法手提示")

	# 玩家下一個合法手，等 AI 回應
	rv._on_cell_pressed(rv.board.hints[0])
	await _wait_for_reversi_ai(rv)
	var counts := ReversiLogic.count(rv.board.stones)
	_check(counts[0] + counts[1] >= 6, "雙方落子後子數不足（%s）" % str(counts))
	await _shot("reversi.png")

	# 悔棋回到玩家落子前
	rv._on_undo()
	var counts2 := ReversiLogic.count(rv.board.stones)
	_check(counts2[0] + counts2[1] == 4, "悔棋未還原至初始（%s）" % str(counts2))

	# 續玩還原
	rv._on_cell_pressed(rv.board.hints[0])
	await _wait_for_reversi_ai(rv)
	var saved_board: Array[int] = rv.board.stones.duplicate()
	main.goto_home()
	await tree.process_frame
	main.open_reversi({"mode": "resume"})
	await tree.process_frame
	var rv2 := main.current_screen() as ReversiScreen
	_check(rv2 != null, "黑白棋續玩畫面未建立")
	_check(rv2.board.stones == saved_board, "黑白棋續玩還原失敗")
	# 提示：輪到玩家時應標示一個合法的建議落點
	rv2._on_hint()
	_check(rv2.board.hint_index >= 0 and rv2.board.stones[rv2.board.hint_index] == ReversiLogic.EMPTY,
			"黑白棋提示未標示合法落點")
	await _shot("reversi_hint.png")
	# 怎麼玩彈窗
	rv2._show_how_to_play()
	await tree.process_frame
	var rv2_dlg: Array[Button] = []
	_collect_buttons(rv2, rv2_dlg)
	var rv2_has_ok := false
	for b in rv2_dlg:
		if b.text == "確定":
			rv2_has_ok = true
			b.pressed.emit()
	_check(rv2_has_ok, "黑白棋怎麼玩彈窗未建立")
	print("[autotest] 黑白棋 OK")

	# ---- 成就 ----
	SaveManager.record_result("gomoku", GomokuLogic.Difficulty.BEGINNER, true)
	_check(Achievements.is_unlocked("gomoku_first"), "五子棋首勝成就未解鎖")
	_check(not Achievements.is_unlocked("all_games"), "全能玩家不應提前解鎖")
	main.open_achievements()
	await tree.process_frame
	_check(main.current_screen() is AchievementScreen, "成就畫面未建立")
	_check(Achievements.unlocked_count() >= 1, "成就計數錯誤")
	await _shot("achievements.png")
	print("[autotest] 成就 OK")

	# ---- 每日挑戰設定 ----
	var ch := Daily.today_challenge()
	_check(["sudoku", "gomoku", "reversi", "minesweeper", "freecell"].has(String(ch["game"])), "每日挑戰遊戲無效")
	_check(int(ch["difficulty"]) >= 0 and int(ch["difficulty"]) <= 3, "每日挑戰難度無效")
	print("[autotest] 每日輪替 OK")

	# ---- 踩地雷 ----
	main.open_minesweeper({"mode": "normal", "difficulty": MinesweeperLogic.Difficulty.BEGINNER, "seed": 99})
	await tree.process_frame
	var msw := main.current_screen() as MinesweeperScreen
	_check(msw != null, "踩地雷畫面未建立")
	# 首挖中央：保證安全且連鎖展開
	msw._on_cell_tapped(40)
	_check(msw.started, "首挖未佈雷")
	_check(msw.board.revealed[40], "首挖未翻開")
	var opened_n := 0
	for i in 81:
		if msw.board.revealed[i]:
			opened_n += 1
	_check(opened_n >= 9, "首挖未連鎖展開（%d 格）" % opened_n)
	# 插旗：長按未翻開格
	var covered := -1
	for i in 81:
		if not msw.board.revealed[i]:
			covered = i
			break
	msw._on_cell_long_pressed(covered)
	_check(msw.board.flagged[covered], "長按插旗失敗")
	msw._on_cell_tapped(covered)
	_check(not msw.board.revealed[covered], "插旗格不應被挖開")
	await _shot("minesweeper.png")
	# 存檔續玩
	var saved_revealed: Array[bool] = msw.board.revealed.duplicate()
	main.goto_home()
	await tree.process_frame
	main.open_minesweeper({"mode": "resume"})
	await tree.process_frame
	var msw2 := main.current_screen() as MinesweeperScreen
	_check(msw2 != null, "踩地雷續玩畫面未建立")
	_check(msw2.board.revealed == saved_revealed, "踩地雷續玩還原失敗")
	_check(msw2.board.flagged[covered], "旗標未還原")
	# 怎麼玩彈窗
	msw2._show_how_to_play()
	await tree.process_frame
	var msw_dlg: Array[Button] = []
	_collect_buttons(msw2, msw_dlg)
	var msw_has_ok := false
	for b in msw_dlg:
		if b.text == "確定":
			msw_has_ok = true
			b.pressed.emit()
	_check(msw_has_ok, "踩地雷怎麼玩彈窗未建立")
	print("[autotest] 踩地雷 OK")

	# ---- 踩地雷每日挑戰（迴歸測試：標題「每日挑戰・踩地雷・難度」三段組合
	# 曾在英文介面撐出螢幕，這裡固定用最長的專家難度重現）----
	main.goto_home()
	await tree.process_frame
	main.open_minesweeper({
		"mode": "daily", "difficulty": MinesweeperLogic.Difficulty.EXPERT, "seed": 1234,
	})
	await tree.process_frame
	var msw3 := main.current_screen() as MinesweeperScreen
	_check(msw3 != null, "踩地雷每日挑戰畫面未建立")
	await _shot("minesweeper_daily.png")
	main.goto_home()
	await tree.process_frame
	print("[autotest] 踩地雷每日挑戰 OK")

	# ---- 2048 ----
	main.open_game2048({"mode": "normal"})
	await tree.process_frame
	var g48 := main.current_screen() as Game2048Screen
	_check(g48 != null, "2048 畫面未建立")
	var tiles := 0
	for v in g48.board.grid:
		if v != 0:
			tiles += 1
	_check(tiles == 2, "開局應有 2 個磚塊（%d）" % tiles)
	# 往四個方向各滑一次，至少會有一次有效移動
	for dir in [0, 1, 2, 3]:
		g48._move(dir)
	var tiles2 := 0
	for v in g48.board.grid:
		if v != 0:
			tiles2 += 1
	_check(tiles2 > 2, "滑動後未生成新磚")
	# 復原
	if not g48._undo_snapshot.is_empty():
		var before_undo: Array[int] = g48.board.grid.duplicate()
		g48._on_undo()
		_check(g48.board.grid != before_undo, "復原未改變盤面")
	await _shot("game2048.png")
	# 存檔續玩
	var saved_grid: Array[int] = g48.board.grid.duplicate()
	var saved_score := g48.score
	main.goto_home()
	await tree.process_frame
	main.open_game2048({"mode": "resume"})
	await tree.process_frame
	var g48b := main.current_screen() as Game2048Screen
	_check(g48b != null, "2048 續玩畫面未建立")
	_check(g48b.board.grid == saved_grid and g48b.score == saved_score, "2048 續玩還原失敗")
	# 成就：模擬最佳磚塊紀錄
	SaveManager.section("game2048_stats")["best_tile"] = 512
	Achievements.refresh()
	_check(Achievements.is_unlocked("t2048_512"), "2048 成就未解鎖")
	# 怎麼玩彈窗（g48 在上面續玩流程中已被釋放，改用還活著的 g48b）
	g48b._show_how_to_play()
	await tree.process_frame
	var g48_dlg: Array[Button] = []
	_collect_buttons(g48b, g48_dlg)
	var g48_has_ok := false
	for b in g48_dlg:
		if b.text == "確定":
			g48_has_ok = true
			b.pressed.emit()
	_check(g48_has_ok, "2048 怎麼玩彈窗未建立")
	print("[autotest] 2048 OK")

	# ---- 接龍 ----
	main.open_solitaire({"mode": "normal"})
	await tree.process_frame
	var sol := main.current_screen() as SolitaireScreen
	_check(sol != null, "接龍畫面未建立")
	_check(sol.board.stock.size() == 24, "接龍庫存應為 24 張")
	# 翻庫存牌
	sol._tap_stock()
	_check(sol.board.waste.size() == 1 and sol.board.stock.size() == 23, "翻牌失敗")
	# 復原
	sol._on_undo()
	_check(sol.board.waste.is_empty() and sol.board.stock.size() == 24, "接龍復原失敗")
	# 兩段式選取：點列頂牌 → 選取；點庫存 → 翻牌並取消選取
	sol._tap_stock()
	sol._on_target("column", 6, 6)
	_check(sol.board.selected_zone == "column" and sol.board.selected_pile == 6, "選取頂牌失敗")
	sol._on_target("stock", 0, 0)
	_check(sol.board.selected_zone == "", "翻牌未取消選取")
	# 廢牌選取與連點快速移動（不保證有去處，但選取必須被清除且不崩潰）
	sol._on_target("waste", 0, 0)
	_check(sol.board.selected_zone == "waste", "選取廢牌失敗")
	sol._on_target("waste", 0, 0)
	_check(sol.board.selected_zone == "", "連點後未清除選取")
	# 兩段式移動壓力測試：各列頂牌互點（規則層保證不會產生非法移動）
	for c in 7:
		var size_a: int = (sol.board.columns[c] as Array).size()
		if size_a > 0:
			sol._on_target("column", c, size_a - 1)
		var d := (c + 1) % 7
		var size_b: int = (sol.board.columns[d] as Array).size()
		if size_b > 0:
			sol._on_target("column", d, size_b - 1)
	# 牌數守恆
	var total := sol.board.stock.size() + sol.board.waste.size()
	for f in 4:
		total += (sol.board.foundations[f] as Array).size()
	for c in 7:
		total += (sol.board.columns[c] as Array).size()
	_check(total == 52, "牌數守恆（%d）" % total)
	# 提示：找到動作就直接選取牌；找不到也要有禮貌地告知（翻庫存牌或卡關），不能什麼都不做
	# 注意：牌局是隨機發的，這麼早期偶爾真的沒有牌桌內可搬動的牌，此時應該提示翻庫存牌
	sol.board.clear_selected()
	sol._on_hint()
	var sol_hint_dlg: Array[Button] = []
	_collect_buttons(sol, sol_hint_dlg)
	_check(sol.board.selected_zone != "" or not sol_hint_dlg.is_empty(),
			"接龍提示應該選取牌或顯示提示訊息")
	for b in sol_hint_dlg:
		if b.text == "確定":
			b.pressed.emit()
	sol.board.clear_selected()
	# 怎麼玩彈窗
	sol._show_how_to_play()
	await tree.process_frame
	var sol_dlg: Array[Button] = []
	_collect_buttons(sol, sol_dlg)
	var sol_has_ok := false
	for b in sol_dlg:
		if b.text == "確定":
			sol_has_ok = true
			b.pressed.emit()
	_check(sol_has_ok, "接龍怎麼玩彈窗未建立")
	await _shot("solitaire.png")
	# 存檔續玩
	var sol_stock := sol.board.stock.duplicate()
	var sol_moves := sol.moves
	main.goto_home()
	await tree.process_frame
	main.open_solitaire({"mode": "resume"})
	await tree.process_frame
	var sol2 := main.current_screen() as SolitaireScreen
	_check(sol2 != null, "接龍續玩畫面未建立")
	_check(sol2.board.stock == sol_stock and sol2.moves == sol_moves, "接龍續玩還原失敗")
	print("[autotest] 接龍 OK")

	# ---- 接龍：發三張模式 ----
	# 注意：sol 在上面的續玩流程中已被釋放，改用還活著的 sol2；
	# _apply_draw_count 只是重新發牌（不切換畫面）
	sol = sol2
	sol._apply_draw_count(3)
	await tree.process_frame
	_check(sol.draw_count == 3, "切換發三張模式未生效")
	_check(int(SaveManager.section("settings").get("solitaire_draw_count", 1)) == 3,
			"發三張設定未持久化")
	var stock_before := sol.board.stock.size()
	sol._tap_stock()
	_check(sol.board.waste.size() == 3 and sol.board.stock.size() == stock_before - 3,
			"發三張模式應一次翻 3 張")
	_check(sol.board.draw_count == 3, "牌桌繪製用的 draw_count 未同步")
	await _shot("solitaire_draw3.png")
	# 只有最外側那張可操作：選取廢牌應對應到 waste[-1]
	var top_card := sol.board.waste[-1]
	sol._on_target("waste", 0, 0)
	var waste_run := sol._selected_run()
	_check(waste_run.size() == 1 and int(waste_run[0]) == int(top_card), "發三張模式下選取的應是最外側那張")
	# 庫存只剩不足 3 張時，應只翻剩下的張數（不崩潰、不多翻）
	while sol.board.stock.size() > 2:
		sol.board.clear_selected()
		sol._tap_stock()
	sol.board.clear_selected()
	var remain := sol.board.stock.size()
	if remain > 0 and remain < 3:
		sol._tap_stock()
		_check(sol.board.stock.is_empty(), "庫存不足 3 張時應該翻完剩餘全部")
	# 續玩應記得發三張模式
	main.goto_home()
	await tree.process_frame
	main.open_solitaire({"mode": "resume"})
	await tree.process_frame
	var sol3 := main.current_screen() as SolitaireScreen
	_check(sol3 != null and sol3.draw_count == 3, "接龍續玩未記得發三張模式")
	# 切回發一張，確認模式能正常切換回去
	sol3._apply_draw_count(1)
	await tree.process_frame
	sol3 = main.current_screen() as SolitaireScreen
	_check(sol3.draw_count == 1, "切回發一張模式未生效")
	main.goto_home()
	await tree.process_frame
	print("[autotest] 接龍發三張模式 OK")

	# ---- 新接龍 ----
	main.open_freecell({"mode": "normal", "seed": 77})
	await tree.process_frame
	var fc := main.current_screen() as FreecellScreen
	_check(fc != null, "新接龍畫面未建立")
	var fc_total := 0
	for c in 8:
		fc_total += (fc.board.cascades[c] as Array).size()
	_check(fc_total == 52, "新接龍開局 52 張")
	# 選取疊頂牌 → 移入自由格
	var src := -1
	for c in 8:
		if not (fc.board.cascades[c] as Array).is_empty():
			src = c
			break
	var top_i: int = (fc.board.cascades[src] as Array).size() - 1
	fc._on_target("cascade", src, top_i)
	_check(fc.board.selected_zone == "cascade", "新接龍選取失敗")
	fc._on_target("free", 0, 0)
	_check(fc.board.free[0] >= 0, "移入自由格失敗")
	_check((fc.board.cascades[src] as Array).size() == top_i, "來源疊未減少")
	# 復原
	fc._on_undo()
	_check(fc.board.free[0] < 0, "新接龍復原失敗")
	# 收基礎堆（可能沒有 A 在疊頂，但不能崩潰）
	fc._auto_collect()
	await _shot("freecell.png")
	# 續玩
	var fc_moves := fc.moves
	main.goto_home()
	await tree.process_frame
	main.open_freecell({"mode": "resume"})
	await tree.process_frame
	var fc2 := main.current_screen() as FreecellScreen
	_check(fc2 != null and fc2.moves == fc_moves, "新接龍續玩還原失敗")
	# 提示：全明牌開局一定至少有一個暫存格或牌桌動作可行
	fc2.board.clear_selected()
	fc2._on_hint()
	_check(fc2.board.selected_zone != "", "新接龍提示應該找到可行動作")
	fc2.board.clear_selected()
	# 怎麼玩彈窗
	fc2._show_how_to_play()
	await tree.process_frame
	var fc2_dlg: Array[Button] = []
	_collect_buttons(fc2, fc2_dlg)
	var fc2_has_ok := false
	for b in fc2_dlg:
		if b.text == "確定":
			fc2_has_ok = true
			b.pressed.emit()
	_check(fc2_has_ok, "新接龍怎麼玩彈窗未建立")
	print("[autotest] 新接龍 OK")

	# ---- 新接龍迴歸測試：唯一合法目的地是空列時，快速自動移動也要能成功 ----
	# （舊版 bug：_smart_move_selected 的搜尋迴圈明確跳過空列，導致這種情況下
	# 連點兩下會直接失敗、玩家會誤以為卡死）
	main.open_freecell({"mode": "normal"})
	await tree.process_frame
	fc = main.current_screen() as FreecellScreen
	var layout: Array = []
	for c in 8:
		layout.append([] as Array[int])
	layout[0] = [5, 17] as Array[int]  # 黑桃6、紅心5：合法兩張連續段
	for c in range(2, 8):
		layout[c] = [12] as Array[int]  # 其餘各列放黑桃K擋著，確保不會湊巧可疊
	fc.board.cascades = layout
	fc.board.free = [10, 11, 20, -1] as Array[int]  # 3 個暫存格佔用、1 個空
	fc.board.foundations = [[], [], [], []]
	fc.undo_stack.clear()
	fc.board.clear_selected()
	fc._on_target("cascade", 0, 0)
	_check(fc.board.selected_zone == "cascade" and fc.board.selected_index == 0, "迴歸測試選取失敗")
	fc._smart_move_selected()
	_check((fc.board.cascades[1] as Array).size() == 2, "快速自動移動應把整段移入唯一的空列（迴歸修正）")
	_check((fc.board.cascades[0] as Array).is_empty(), "來源列應清空")
	print("[autotest] 新接龍空列迴歸測試 OK")

	# ---- 新接龍迴歸測試：搬移上限公式與失敗提示（重現 Benny 回報的 7 張牌情境）----
	main.open_freecell({"mode": "normal"})
	await tree.process_frame
	fc = main.current_screen() as FreecellScreen
	# K,Q,J,10,9,8,7 黑紅交替的合法 7 張連續段
	var run7: Array[int] = [12, 24, 10, 22, 8, 20, 6]
	var layout2: Array = []
	for c in 8:
		layout2.append([] as Array[int])
	layout2[0] = run7.duplicate()
	for c in range(2, 8):
		layout2[c] = [38] as Array[int]  # 梅花 Q，任意擋著避免湊巧可疊
	fc.board.cascades = layout2
	fc.board.foundations = [[], [], [], []]

	# 情境一：只有 1 個空暫存格、0 個額外空列 → 上限 = (1+1)*1 = 2，7 張應失敗且顯示提示
	fc.board.free = [1, 2, 3, -1] as Array[int]
	fc.undo_stack.clear()
	fc.board.clear_selected()
	fc._on_target("cascade", 0, 0)
	_check(fc.board.selected_index == 0, "7 張情境選取失敗")
	fc._on_target("cascade", 1, -1)
	var dialog_texts: Array[String] = []
	var dlg_buttons: Array[Button] = []
	_collect_buttons(fc, dlg_buttons)
	for b in dlg_buttons:
		dialog_texts.append(b.text)
	_check(fc.board.selected_zone == "cascade" and fc.board.selected_index == 0,
			"上限不足時應保留選取而非默默取消")
	_check((fc.board.cascades[1] as Array).is_empty(), "上限不足時不應該真的搬過去")
	# 關掉提示彈窗（點「確定」）
	for b in dlg_buttons:
		if b.text == "確定":
			b.pressed.emit()
			break
	await tree.process_frame

	# 情境二：4 個空暫存格都空、恰好 1 個空列（目的地本身）→ 上限 = (4+1)*1 = 5，
	# 縮減成 4 張（10,9,8,7）應成功
	fc.board.free = [-1, -1, -1, -1] as Array[int]
	fc.board.cascades[0] = run7.duplicate()
	fc.board.cascades[1] = []
	fc.board.clear_selected()
	fc._on_target("cascade", 0, 3)  # 從「10」開始的 4 張：10,9,8,7
	_check(fc.board.selected_index == 3, "4 張子段選取失敗")
	fc._on_target("cascade", 1, -1)
	_check((fc.board.cascades[1] as Array).size() == 4, "資源足夠時 4 張應能搬移成功")
	_check((fc.board.cascades[0] as Array).size() == 3, "來源應剩下 K,Q,J")

	# 情境三：資源充足（4 空暫存格 + 1 個額外空列）時，完整 7 張應能一次搬移成功
	fc.board.free = [-1, -1, -1, -1] as Array[int]
	fc.board.cascades[0] = run7.duplicate()
	fc.board.cascades[1] = []
	fc.board.cascades[2] = []  # 額外一個空列
	fc.board.clear_selected()
	fc._on_target("cascade", 0, 0)
	fc._on_target("cascade", 1, -1)
	_check((fc.board.cascades[1] as Array).size() == 7, "資源充足時完整 7 張應能一次搬移成功")
	print("[autotest] 新接龍搬移上限迴歸測試 OK")

	main.goto_home()
	await tree.process_frame

	# ---- 多局進行中存檔（v0.8：各遊戲可同時掛局）----
	var active_count := 0
	for g_name in ["sudoku", "gomoku", "reversi", "minesweeper", "game2048", "solitaire"]:
		if not SaveManager.get_in_progress(g_name).is_empty():
			active_count += 1
	_check(active_count >= 4, "多局進行中存檔數量不足（%d）" % active_count)
	print("[autotest] 多局存檔 OK（同時 %d 局）" % active_count)

	# ---- 設定頁 ----
	main.open_settings()
	await tree.process_frame
	_check(main.current_screen() is SettingsScreen, "設定畫面未建立")
	Sfx.set_enabled(false)
	_check(not Sfx.enabled(), "音效關閉未生效")
	Sfx.set_enabled(true)
	_check(Sfx.enabled(), "音效開啟未生效")
	await _shot("settings.png")
	print("[autotest] 設定頁 OK")

	# ---- 多語系（v0.8.1：語言確實切換生效，且選擇彈窗正確標示目前選項）----
	var st_screen := main.current_screen() as SettingsScreen
	st_screen._set_language("en")
	await tree.process_frame
	_check(TranslationServer.get_locale() == "en", "切換英文未生效")
	_check(tr("數獨") == "Sudoku", "英文翻譯未生效")

	st_screen = main.current_screen() as SettingsScreen
	st_screen._set_language("zh_TW")
	await tree.process_frame
	_check(TranslationServer.get_locale() == "zh_TW", "切換中文未生效")
	_check(tr("數獨") == "數獨", "中文應直接顯示原文（無 zh_TW 翻譯表，靠原文回退）")

	st_screen = main.current_screen() as SettingsScreen
	st_screen._pick_language()
	await tree.process_frame
	var dialog_buttons: Array[Button] = []
	_collect_buttons(st_screen, dialog_buttons)
	var checked_texts: Array[String] = []
	for b in dialog_buttons:
		if b.text.contains("✓"):
			checked_texts.append(b.text)
	_check(checked_texts.size() == 1 and checked_texts[0].begins_with("中文"),
			"語言選擇彈窗未正確標示目前選項（%s）" % str(checked_texts))

	st_screen._set_language("")
	await tree.process_frame
	main.goto_home()
	await tree.process_frame
	print("[autotest] 多語系 OK")

	print("[autotest] PASS")
	get_tree().quit(0)


func _collect_buttons(node: Node, out: Array[Button]) -> void:
	if node is Button:
		out.append(node)
	for child in node.get_children():
		_collect_buttons(child, out)


func _wait_for_reversi_ai(rv: ReversiScreen) -> void:
	var tries := 0
	while rv._ai_pending or rv._ai_thread != null:
		await get_tree().process_frame
		tries += 1
		if tries > 600:
			_check(false, "等待黑白棋 AI 逾時")
			return


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
