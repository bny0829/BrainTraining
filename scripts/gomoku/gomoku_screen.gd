class_name GomokuScreen
extends Control
## 五子棋遊戲畫面：玩家（黑）對 AI（白），AI 在背景執行緒思考避免卡住 UI。
## config：
##   { "mode": "normal", "difficulty": int }  新對局
##   { "mode": "resume" }                     從 SaveManager 還原

var config: Dictionary = {}

var difficulty: int = GomokuLogic.Difficulty.BEGINNER
var moves: Array[int] = []  # 依序的落子（偶數手 = 黑 = 玩家）
var finished := false

var board: GomokuBoard
var _title_label: Label
var _info_label: Label
var _undo_btn: Button

var _ai_thread: Thread = null
var _ai_pending := false


func _ready() -> void:
	_build_ui()
	if String(config.get("mode", "normal")) == "resume":
		_restore(SaveManager.get_in_progress())
	else:
		difficulty = int(config.get("difficulty", GomokuLogic.Difficulty.BEGINNER))
		_new_game()


func _exit_tree() -> void:
	# 離開畫面時必須等 AI 執行緒結束，否則會洩漏
	if _ai_thread != null and _ai_thread.is_started():
		_ai_thread.wait_to_finish()
		_ai_thread = null


func _process(_delta: float) -> void:
	if _ai_pending and _ai_thread != null and not _ai_thread.is_alive():
		var mv := int(_ai_thread.wait_to_finish())
		_ai_thread = null
		_ai_pending = false
		if not finished and mv >= 0:
			_apply_move(mv)


# ---- UI 建構 ----

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 16)
	margin.add_child(col)

	# 頂列：返回 / 標題
	var top := HBoxContainer.new()
	col.add_child(top)
	var back := Button.new()
	back.text = "← 返回"
	AppTheme.style_secondary(back)
	back.pressed.connect(_on_back)
	top.add_child(back)
	top.add_child(_spacer())
	_title_label = Label.new()
	_title_label.add_theme_font_size_override("font_size", 34)
	top.add_child(_title_label)
	top.add_child(_spacer())
	# 佔位讓標題置中（與返回鈕等寬的透明按鈕）
	var ghost := Button.new()
	ghost.text = "← 返回"
	ghost.modulate = Color(1, 1, 1, 0)
	ghost.disabled = true
	top.add_child(ghost)

	# 資訊列：回合狀態 / 手數
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	col.add_child(_info_label)

	# 棋盤
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(aspect)
	board = GomokuBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(_on_cell_pressed)
	aspect.add_child(board)

	# 工具列
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	col.add_child(tools)
	_undo_btn = Button.new()
	_undo_btn.text = "悔棋"
	_undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(_undo_btn)
	_undo_btn.pressed.connect(_on_undo)
	tools.add_child(_undo_btn)
	var restart := Button.new()
	restart.text = "重新開始"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(restart)
	restart.pressed.connect(_on_restart_pressed)
	tools.add_child(restart)


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


# ---- 遊戲流程 ----

func _new_game() -> void:
	moves.clear()
	for i in GomokuLogic.CELLS:
		board.stones[i] = GomokuLogic.EMPTY
	board.last_move = -1
	finished = false
	_refresh()
	_save_state()


func _restore(state: Dictionary) -> void:
	if state.is_empty() or String(state.get("game", "")) != "gomoku":
		difficulty = int(config.get("difficulty", GomokuLogic.Difficulty.BEGINNER))
		_new_game()
		return
	difficulty = int(state.get("difficulty", 0))
	moves.clear()
	for i in GomokuLogic.CELLS:
		board.stones[i] = GomokuLogic.EMPTY
	for v in state.get("moves", []):
		var c := int(v)
		board.stones[c] = _player_of_ply(moves.size())
		moves.append(c)
	board.last_move = moves[-1] if not moves.is_empty() else -1
	finished = false
	_refresh()
	# 存檔停在 AI 回合（理論上不會發生，保險處理）
	if not _is_player_turn():
		_start_ai()


## 第 n 手（0 起算）的顏色：偶數 = 黑（玩家）
func _player_of_ply(n: int) -> int:
	return GomokuLogic.BLACK if n % 2 == 0 else GomokuLogic.WHITE


func _is_player_turn() -> bool:
	return moves.size() % 2 == 0


func _on_cell_pressed(i: int) -> void:
	if finished or _ai_pending or not _is_player_turn():
		return
	if board.stones[i] != GomokuLogic.EMPTY:
		return
	_apply_move(i)
	if not finished:
		_start_ai()


func _apply_move(i: int) -> void:
	var p := _player_of_ply(moves.size())
	board.stones[i] = p
	moves.append(i)
	board.last_move = i
	board.queue_redraw()
	if GomokuLogic.check_win(board.stones, i):
		_finish(p == GomokuLogic.BLACK)
		return
	if GomokuLogic.is_full(board.stones):
		_finish_draw()
		return
	_refresh()
	_save_state()


func _start_ai() -> void:
	_ai_pending = true
	_refresh()
	var snapshot: Array[int] = board.stones.duplicate()
	var diff := difficulty
	_ai_thread = Thread.new()
	_ai_thread.start(func() -> int:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		return GomokuLogic.choose_move(snapshot, GomokuLogic.WHITE, diff, rng)
	)


## 悔棋：收回 AI 與玩家各一手
func _on_undo() -> void:
	if finished or _ai_pending or moves.size() < 2:
		return
	for k in 2:
		var c: int = moves.pop_back()
		board.stones[c] = GomokuLogic.EMPTY
	board.last_move = moves[-1] if not moves.is_empty() else -1
	board.queue_redraw()
	_refresh()
	_save_state()


func _on_restart_pressed() -> void:
	if _ai_pending:
		return
	OverlayDialog.open(self, "重新開始？", "目前的棋局將被捨棄", [
		{"text": "重新開始", "action": _new_game},
		{"text": "取消", "secondary": true},
	])


func _on_back() -> void:
	if not finished:
		_save_state()
	Main.instance.goto_home()


# ---- 勝負 ----

func _finish(player_won: bool) -> void:
	finished = true
	SaveManager.record_result("gomoku", difficulty, player_won)
	SaveManager.set_in_progress({})
	_refresh()
	var title := "你贏了！" if player_won else "AI 獲勝"
	var msg := "難度：%s・共 %d 手" % [GomokuLogic.DIFFICULTY_TEXT[difficulty], moves.size()]
	OverlayDialog.open(self, title, msg, [
		{"text": "再來一局", "action": _new_game},
		{"text": "回首頁", "action": _go_home, "secondary": true},
	])


func _finish_draw() -> void:
	finished = true
	SaveManager.record_result("gomoku", difficulty, false)
	SaveManager.set_in_progress({})
	_refresh()
	OverlayDialog.open(self, "平手", "棋盤已下滿", [
		{"text": "再來一局", "action": _new_game},
		{"text": "回首頁", "action": _go_home, "secondary": true},
	])


func _go_home() -> void:
	Main.instance.goto_home()


# ---- 顯示與存檔 ----

func _refresh() -> void:
	board.queue_redraw()
	_title_label.text = "五子棋・%s" % GomokuLogic.DIFFICULTY_TEXT[difficulty]
	if finished:
		_info_label.text = "對局結束・共 %d 手" % moves.size()
	elif _ai_pending:
		_info_label.text = "AI 思考中…"
	else:
		_info_label.text = "你的回合（黑棋）・第 %d 手" % (moves.size() + 1)
	_undo_btn.disabled = finished or _ai_pending or moves.size() < 2


func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress({
		"game": "gomoku",
		"mode": "normal",
		"difficulty": difficulty,
		"moves": moves.duplicate(),
	})
