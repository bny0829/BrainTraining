extends Node
## 產生 Google Play 商店截圖（乾淨版：不觸發成就通知、每次切換畫面後等轉場穩定）。
## 執行方式：
##   $env:BRAINCLUB_SHOT = "輸出資料夾"
##   Godot執行檔 --path 專案目錄 --resolution 720x1280
## Main 偵測到 BRAINCLUB_STORE_SHOTS=1 時載入本腳本，依序開啟每個畫面截圖、自動結束。
## 使用獨立存檔（不影響玩家真實進度），流程中只進行少量操作營造「正在玩」的畫面，
## 刻意不完成/獲勝任何一局，避免成就解鎖通知擋住畫面。

const SETTLE := 0.4  # 畫面切換淡入動畫 0.15 秒，多留一點餘裕再截圖


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var tree := get_tree()
	var main := Main.instance
	var dir := OS.get_environment("BRAINCLUB_SHOT")

	await _settle()
	await _shot(dir, "01_home.png")

	main.open_sudoku({"mode": "normal", "difficulty": SudokuLogic.Difficulty.EASY, "seed": 20260101})
	await tree.process_frame
	var sk := main.current_screen() as SudokuScreen
	# 只填一部分格子營造「正在玩」的畫面，刻意不填滿，避免觸發完成/成就
	var filled := 0
	for i in 81:
		if filled >= 15:
			break
		if not sk.board.given[i] and sk.board.values[i] == 0:
			sk._on_cell_pressed(i)
			sk._on_number(sk.solution[i])
			filled += 1
	await _settle()
	await _shot(dir, "02_sudoku.png")

	main.goto_home()
	await tree.process_frame
	main.open_gomoku({"mode": "normal", "difficulty": GomokuLogic.Difficulty.NORMAL})
	await tree.process_frame
	var go := main.current_screen() as GomokuScreen
	go._on_cell_pressed(GomokuLogic.idx(7, 7))
	await _wait_ai_gomoku(go)
	go._on_cell_pressed(GomokuLogic.idx(8, 8))
	await _wait_ai_gomoku(go)
	await _settle()
	await _shot(dir, "03_gomoku.png")

	main.goto_home()
	await tree.process_frame
	main.open_reversi({"mode": "normal", "difficulty": ReversiLogic.Difficulty.NORMAL})
	await tree.process_frame
	var rv := main.current_screen() as ReversiScreen
	if not rv.board.hints.is_empty():
		rv._on_cell_pressed(rv.board.hints[0])
		await _wait_ai_reversi(rv)
	await _settle()
	await _shot(dir, "04_reversi.png")

	main.goto_home()
	await tree.process_frame
	main.open_minesweeper({"mode": "normal", "difficulty": MinesweeperLogic.Difficulty.BEGINNER})
	await tree.process_frame
	var ms := main.current_screen() as MinesweeperScreen
	ms._on_cell_tapped(40)
	await _settle()
	await _shot(dir, "05_minesweeper.png")

	main.goto_home()
	await tree.process_frame
	main.open_game2048({"mode": "normal"})
	await tree.process_frame
	var g2 := main.current_screen() as Game2048Screen
	for dir_i in [Game2048Logic.DIR_LEFT, Game2048Logic.DIR_UP, Game2048Logic.DIR_RIGHT, Game2048Logic.DIR_DOWN]:
		g2._move(dir_i)
	await _settle()
	await _shot(dir, "06_game2048.png")

	main.goto_home()
	await tree.process_frame
	main.open_solitaire({"mode": "normal"})
	await tree.process_frame
	var sol := main.current_screen() as SolitaireScreen
	sol._tap_stock()
	sol._on_hint()
	await _settle()
	await _shot(dir, "07_solitaire.png")

	main.goto_home()
	await tree.process_frame
	main.open_freecell({"mode": "normal"})
	await tree.process_frame
	var fc := main.current_screen() as FreecellScreen
	fc._on_hint()
	await _settle()
	await _shot(dir, "08_freecell.png")

	main.goto_home()
	await tree.process_frame
	main.open_achievements()
	await tree.process_frame
	await _settle()
	await _shot(dir, "09_achievements.png")

	print("[store_shots] 完成")
	tree.quit(0)


func _settle() -> void:
	await get_tree().create_timer(SETTLE).timeout


func _wait_ai_gomoku(g: GomokuScreen) -> void:
	var tries := 0
	while g._ai_pending or g._ai_thread != null:
		await get_tree().process_frame
		tries += 1
		if tries > 600:
			return


func _wait_ai_reversi(r: ReversiScreen) -> void:
	var tries := 0
	while r._ai_pending or r._ai_thread != null:
		await get_tree().process_frame
		tries += 1
		if tries > 600:
			return


func _shot(dir: String, fname: String) -> void:
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png(dir.path_join(fname))
	print("[store_shots] 截圖：" + fname)
