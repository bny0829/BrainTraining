class_name ReversiScreen
extends Control
## 黑白棋遊戲畫面：玩家（黑）對 AI（白），含跳過回合處理、合法手提示、悔棋與續玩。
## AI 沿用五子棋的背景執行緒模式。
## config：
##   { "mode": "normal", "difficulty": int }  新對局
##   { "mode": "daily", "difficulty": int }   每日挑戰（獲勝才算完成）
##   { "mode": "resume" }                     從 SaveManager 還原

var config: Dictionary = {}

var mode := "normal"
var difficulty: int = ReversiLogic.Difficulty.BEGINNER
var turn: int = ReversiLogic.BLACK
var finished := false
var undo_stack: Array = []

var board: ReversiBoard
var _title_label: Label
var _info_label: Label
var _score_label: Label
var _undo_btn: Button

var _ai_thread: Thread = null
var _ai_pending := false


func _ready() -> void:
	mode = String(config.get("mode", "normal"))
	_build_ui()
	if mode == "resume":
		_restore(SaveManager.get_in_progress("reversi"))
	else:
		difficulty = int(config.get("difficulty", ReversiLogic.Difficulty.BEGINNER))
		_new_game()


func _exit_tree() -> void:
	if _ai_thread != null and _ai_thread.is_started():
		_ai_thread.wait_to_finish()
		_ai_thread = null


func _process(_delta: float) -> void:
	if _ai_pending and _ai_thread != null and not _ai_thread.is_alive():
		var mv := int(_ai_thread.wait_to_finish())
		_ai_thread = null
		_ai_pending = false
		if finished:
			return
		if mv >= 0:
			_apply_move(mv)
		else:
			# 理論上不會發生（輪到 AI 前已檢查有合法手），保險處理
			_after_move()


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
	var ghost := Button.new()
	ghost.text = "← 返回"
	ghost.modulate = Color(1, 1, 1, 0)
	ghost.disabled = true
	top.add_child(ghost)

	var info := HBoxContainer.new()
	col.add_child(info)
	_info_label = Label.new()
	_info_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_info_label)
	info.add_child(_spacer())
	_score_label = Label.new()
	_score_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_score_label)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(aspect)
	board = ReversiBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(_on_cell_pressed)
	aspect.add_child(board)

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
	var init := ReversiLogic.initial_board()
	for i in ReversiLogic.CELLS:
		board.stones[i] = init[i]
	board.last_move = -1
	turn = ReversiLogic.BLACK
	finished = false
	undo_stack.clear()
	_refresh()
	_save_state()


func _restore(state: Dictionary) -> void:
	var saved := _to_int_array(state.get("board", []))
	if state.is_empty() or String(state.get("game", "")) != "reversi" \
			or saved.size() != ReversiLogic.CELLS:
		difficulty = int(config.get("difficulty", ReversiLogic.Difficulty.BEGINNER))
		_new_game()
		return
	mode = String(state.get("mode", "normal"))
	difficulty = int(state.get("difficulty", 0))
	for i in ReversiLogic.CELLS:
		board.stones[i] = saved[i]
	board.last_move = int(state.get("last", -1))
	turn = int(state.get("turn", ReversiLogic.BLACK))
	finished = false
	_refresh()
	if turn == ReversiLogic.WHITE:
		_start_ai()


func _on_cell_pressed(i: int) -> void:
	if finished or _ai_pending or turn != ReversiLogic.BLACK:
		return
	var fl := ReversiLogic.flips_for(board.stones, ReversiLogic.BLACK, i)
	if fl.is_empty():
		return
	undo_stack.append({
		"board": board.stones.duplicate(),
		"last": board.last_move,
	})
	if undo_stack.size() > 60:
		undo_stack.pop_front()
	ReversiLogic.apply_move(board.stones, ReversiLogic.BLACK, i, fl)
	board.last_move = i
	Sfx.play("stone")
	_after_move()


func _apply_move(i: int) -> void:
	var fl := ReversiLogic.flips_for(board.stones, turn, i)
	ReversiLogic.apply_move(board.stones, turn, i, fl)
	board.last_move = i
	Sfx.play("stone")
	_after_move()


## 每步共用的收尾：判終局、換手或跳過
func _after_move() -> void:
	board.queue_redraw()
	var black_can := ReversiLogic.has_move(board.stones, ReversiLogic.BLACK)
	var white_can := ReversiLogic.has_move(board.stones, ReversiLogic.WHITE)
	if not black_can and not white_can:
		_finish()
		return
	var next := ReversiLogic.opponent(turn)
	var next_can := black_can if next == ReversiLogic.BLACK else white_can
	if next_can:
		turn = next
		_proceed()
	else:
		# next 無子可下：跳過，輪回原玩家
		var skipped := tr("你") if next == ReversiLogic.BLACK else "AI"
		var cont := "AI" if next == ReversiLogic.BLACK else tr("你")
		OverlayDialog.open(self, "跳過回合", tr("%s無子可下，由%s繼續") % [skipped, cont], [
			{"text": "確定", "action": _proceed},
		])


func _proceed() -> void:
	_refresh()
	_save_state()
	if turn == ReversiLogic.WHITE and not finished:
		_start_ai()


func _start_ai() -> void:
	_ai_pending = true
	_refresh()
	var snapshot: Array[int] = board.stones.duplicate()
	var diff := difficulty
	_ai_thread = Thread.new()
	_ai_thread.start(func() -> int:
		var rng := RandomNumberGenerator.new()
		rng.randomize()
		return ReversiLogic.choose_move(snapshot, ReversiLogic.WHITE, diff, rng)
	)


func _on_undo() -> void:
	if finished or _ai_pending or turn != ReversiLogic.BLACK or undo_stack.is_empty():
		return
	var snap: Dictionary = undo_stack.pop_back()
	var saved: Array = snap["board"]
	for i in ReversiLogic.CELLS:
		board.stones[i] = int(saved[i])
	board.last_move = int(snap["last"])
	turn = ReversiLogic.BLACK
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

func _finish() -> void:
	finished = true
	var c := ReversiLogic.count(board.stones)
	var player_won := c[0] > c[1]
	Sfx.play("win" if player_won else "lose")
	SaveManager.record_result("reversi", difficulty, player_won)
	SaveManager.set_in_progress("reversi", {})
	_refresh()
	var title: String
	if c[0] > c[1]:
		title = "你贏了！"
	elif c[0] < c[1]:
		title = "AI 獲勝"
	else:
		title = "平手"
	var msg := tr("黑 %d：%d 白·難度 %s") % [c[0], c[1], tr(ReversiLogic.DIFFICULTY_TEXT[difficulty])]
	var buttons: Array = []
	if mode == "daily" and player_won:
		Daily.mark_completed()
		msg += "\n" + tr("每日挑戰完成！連續 %d 天") % Daily.streak()
	else:
		buttons.append({"text": "再來一局", "action": _new_game})
	buttons.append({"text": "回首頁", "action": _go_home, "secondary": not buttons.is_empty()})
	OverlayDialog.open(self, title, msg, buttons)


func _go_home() -> void:
	Main.instance.goto_home()


# ---- 顯示與存檔 ----

func _refresh() -> void:
	var mode_text := tr("每日挑戰·黑白棋") if mode == "daily" else tr("黑白棋")
	_title_label.text = "%s·%s" % [mode_text, tr(ReversiLogic.DIFFICULTY_TEXT[difficulty])]
	var c := ReversiLogic.count(board.stones)
	_score_label.text = tr("黑 %d：%d 白") % [c[0], c[1]]
	if finished:
		_info_label.text = tr("對局結束")
	elif _ai_pending:
		_info_label.text = tr("AI 思考中…")
	else:
		_info_label.text = tr("你的回合（黑棋）")
	# 玩家回合才顯示合法手提示
	if not finished and not _ai_pending and turn == ReversiLogic.BLACK:
		board.hints = ReversiLogic.legal_moves(board.stones, ReversiLogic.BLACK)
	else:
		board.hints = []
	board.queue_redraw()
	_undo_btn.disabled = finished or _ai_pending or undo_stack.is_empty()


func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress("reversi", {
		"game": "reversi",
		"mode": mode,
		"difficulty": difficulty,
		"date": Daily.today_id() if mode == "daily" else "",
		"board": board.stones.duplicate(),
		"turn": turn,
		"last": board.last_move,
	})


static func _to_int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out
