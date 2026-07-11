class_name SudokuScreen
extends Control
## 數獨遊戲畫面：計時、錯誤上限、筆記、提示、復原、勝負判定與自動存檔。
## config：
##   { "mode": "normal", "difficulty": int }            一般模式（可另給 "seed"）
##   { "mode": "daily", "difficulty": int, "seed": int } 每日挑戰
##   { "mode": "resume" }                                從 SaveManager 還原

const MAX_MISTAKES := 3

var config: Dictionary = {}

var mode := "normal"
var difficulty: int = SudokuLogic.Difficulty.EASY
var solution: Array[int] = []
var mistakes := 0
var seconds := 0.0
var hints_used := 0
var finished := false
var notes_mode := false
var undo_stack: Array = []

var board: SudokuBoard
var _title_label: Label
var _mistakes_label: Label
var _timer_label: Label
var _last_timer_text := ""
var _num_buttons: Array[Button] = []


func _ready() -> void:
	mode = String(config.get("mode", "normal"))
	_build_ui()
	if mode == "resume":
		_restore(SaveManager.get_in_progress())
	else:
		difficulty = int(config.get("difficulty", SudokuLogic.Difficulty.EASY))
		_new_game()


func _process(delta: float) -> void:
	if finished:
		return
	seconds += delta
	var text := format_time(int(seconds))
	if text != _last_timer_text:
		_last_timer_text = text
		_timer_label.text = text


static func format_time(s: int) -> String:
	return "%02d:%02d" % [s / 60, s % 60]


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

	# 頂列：返回 / 標題 / 提示
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
	var hint := Button.new()
	hint.text = "提示"
	AppTheme.style_secondary(hint)
	hint.pressed.connect(_on_hint)
	top.add_child(hint)

	# 資訊列：錯誤數 / 計時
	var info := HBoxContainer.new()
	col.add_child(info)
	_mistakes_label = Label.new()
	_mistakes_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_mistakes_label)
	info.add_child(_spacer())
	_timer_label = Label.new()
	_timer_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_timer_label)

	# 棋盤（維持正方形）
	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(aspect)
	board = SudokuBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_pressed.connect(_on_cell_pressed)
	aspect.add_child(board)

	# 工具列
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	col.add_child(tools)
	var undo_btn := Button.new()
	undo_btn.text = "復原"
	undo_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(undo_btn)
	undo_btn.pressed.connect(_on_undo)
	tools.add_child(undo_btn)
	var erase_btn := Button.new()
	erase_btn.text = "擦除"
	erase_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(erase_btn)
	erase_btn.pressed.connect(_on_erase)
	tools.add_child(erase_btn)
	var notes_btn := Button.new()
	notes_btn.text = "筆記"
	notes_btn.toggle_mode = true
	notes_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(notes_btn)
	notes_btn.toggled.connect(_on_notes_toggled)
	tools.add_child(notes_btn)

	# 數字鍵
	var pad := HBoxContainer.new()
	pad.add_theme_constant_override("separation", 8)
	col.add_child(pad)
	for d in range(1, 10):
		var b := Button.new()
		b.text = str(d)
		b.custom_minimum_size = Vector2(0, 88)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		AppTheme.style_number(b)
		b.pressed.connect(_on_number.bind(d))
		pad.add_child(b)
		_num_buttons.append(b)


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


# ---- 遊戲流程 ----

func _new_game() -> void:
	var rng := RandomNumberGenerator.new()
	if config.has("seed"):
		rng.seed = int(config["seed"])
	else:
		rng.randomize()
	var gen := SudokuLogic.generate(difficulty, rng)
	solution = gen.solution
	var puzzle: Array = gen.puzzle
	for i in 81:
		board.values[i] = int(puzzle[i])
		board.given[i] = int(puzzle[i]) != 0
		board.errors[i] = false
		board.notes[i] = 0
	board.selected = -1
	mistakes = 0
	seconds = 0.0
	hints_used = 0
	finished = false
	notes_mode = false
	undo_stack.clear()
	_refresh_all()
	_save_state()


## 重新開始同一題（清掉玩家輸入）
func _restart_same() -> void:
	for i in 81:
		if not board.given[i]:
			board.values[i] = 0
		board.errors[i] = false
		board.notes[i] = 0
	board.selected = -1
	mistakes = 0
	seconds = 0.0
	hints_used = 0
	finished = false
	undo_stack.clear()
	_refresh_all()
	_save_state()


func _restore(state: Dictionary) -> void:
	var vals := _to_int_array(state.get("values", []))
	if state.is_empty() or String(state.get("game", "")) != "sudoku" or vals.size() != 81:
		# 存檔壞掉就開新局
		difficulty = int(config.get("difficulty", SudokuLogic.Difficulty.EASY))
		_new_game()
		return
	mode = String(state.get("mode", "normal"))
	difficulty = int(state.get("difficulty", 0))
	solution = _to_int_array(state.get("solution", []))
	var giv: Array = state.get("given", [])
	var errs: Array = state.get("errors", [])
	var nts := _to_int_array(state.get("notes", []))
	for i in 81:
		board.values[i] = vals[i]
		board.given[i] = bool(giv[i])
		board.errors[i] = bool(errs[i])
		board.notes[i] = nts[i]
	mistakes = int(state.get("mistakes", 0))
	seconds = float(state.get("seconds", 0))
	hints_used = int(state.get("hints", 0))
	_refresh_all()


# ---- 輸入處理 ----

func _on_cell_pressed(i: int) -> void:
	if finished:
		return
	board.set_selected(i)


func _on_number(d: int) -> void:
	if finished or board.selected < 0:
		return
	var i := board.selected
	if _is_locked(i):
		return
	if notes_mode:
		if board.values[i] != 0:
			return
		_push_undo(i)
		board.notes[i] ^= 1 << (d - 1)
	else:
		if board.values[i] == d:
			return
		_push_undo(i)
		board.values[i] = d
		board.notes[i] = 0
		if d == solution[i]:
			board.errors[i] = false
			_clear_peer_notes(i, d)
			_check_win()
		else:
			board.errors[i] = true
			mistakes += 1
			_update_info()
			if mistakes >= MAX_MISTAKES:
				_game_over()
	board.queue_redraw()
	_update_numberpad()
	_save_state()


func _on_erase() -> void:
	if finished or board.selected < 0:
		return
	var i := board.selected
	if _is_locked(i):
		return
	if board.values[i] == 0 and board.notes[i] == 0:
		return
	_push_undo(i)
	board.values[i] = 0
	board.notes[i] = 0
	board.errors[i] = false
	board.queue_redraw()
	_update_numberpad()
	_save_state()


func _on_hint() -> void:
	if finished:
		return
	var target := board.selected
	if target < 0 or _is_locked(target):
		target = -1
		for i in 81:
			if not _is_locked(i):
				target = i
				break
	if target < 0:
		return
	_push_undo(target)
	board.values[target] = solution[target]
	board.errors[target] = false
	board.notes[target] = 0
	hints_used += 1
	board.set_selected(target)
	_clear_peer_notes(target, solution[target])
	board.queue_redraw()
	_update_numberpad()
	_check_win()
	_save_state()


func _on_undo() -> void:
	if finished or undo_stack.is_empty():
		return
	var op: Dictionary = undo_stack.pop_back()
	var i := int(op["i"])
	board.values[i] = int(op["v"])
	board.notes[i] = int(op["n"])
	board.errors[i] = bool(op["e"])
	board.queue_redraw()
	_update_numberpad()
	_save_state()


func _on_notes_toggled(on: bool) -> void:
	notes_mode = on


func _on_back() -> void:
	if not finished:
		_save_state()
	Main.instance.goto_home()


# ---- 規則輔助 ----

## 已鎖定 = 題目提示格，或已填入正確答案的格子
func _is_locked(i: int) -> bool:
	return board.given[i] or (board.values[i] != 0 and not board.errors[i])


func _push_undo(i: int) -> void:
	undo_stack.append({
		"i": i, "v": board.values[i], "n": board.notes[i], "e": board.errors[i],
	})
	if undo_stack.size() > 200:
		undo_stack.pop_front()


## 正確填入 d 後，清掉同列/行/宮筆記中的 d
func _clear_peer_notes(i: int, d: int) -> void:
	var bit := 1 << (d - 1)
	for j in 81:
		if j != i and board.notes[j] & bit != 0 and _same_unit(i, j):
			board.notes[j] &= ~bit


func _same_unit(i: int, j: int) -> bool:
	return i / 9 == j / 9 or i % 9 == j % 9 or SudokuLogic.box_of(i) == SudokuLogic.box_of(j)


# ---- 勝負 ----

func _check_win() -> void:
	for i in 81:
		if board.values[i] != solution[i] or board.errors[i]:
			return
	finished = true
	SaveManager.record_sudoku_result(difficulty, int(seconds), true)
	SaveManager.set_in_progress({})
	var lines := "難度：%s\n時間：%s" % [
		SudokuLogic.DIFFICULTY_TEXT[difficulty], format_time(int(seconds))
	]
	if hints_used > 0:
		lines += "\n提示：%d 次" % hints_used
	var buttons: Array = []
	if mode == "daily":
		Daily.mark_completed()
		lines += "\n連續完成：%d 天" % Daily.streak()
	else:
		buttons.append({"text": "再來一局", "action": _play_again})
	buttons.append({"text": "回首頁", "action": _go_home, "secondary": mode != "daily"})
	OverlayDialog.open(self, "完成！", lines, buttons)


func _game_over() -> void:
	finished = true
	SaveManager.record_sudoku_result(difficulty, int(seconds), false)
	SaveManager.set_in_progress({})
	OverlayDialog.open(self, "挑戰失敗", "錯誤已達 %d 次" % MAX_MISTAKES, [
		{"text": "重新開始", "action": _restart_same},
		{"text": "回首頁", "action": _go_home, "secondary": true},
	])


func _play_again() -> void:
	Main.instance.open_sudoku({"mode": "normal", "difficulty": difficulty})


func _go_home() -> void:
	Main.instance.goto_home()


# ---- 顯示更新 ----

func _refresh_all() -> void:
	var mode_text := "每日挑戰" if mode == "daily" else "數獨"
	_title_label.text = "%s・%s" % [mode_text, SudokuLogic.DIFFICULTY_TEXT[difficulty]]
	_update_info()
	_update_numberpad()
	_last_timer_text = format_time(int(seconds))
	_timer_label.text = _last_timer_text
	board.queue_redraw()


func _update_info() -> void:
	_mistakes_label.text = "錯誤 %d / %d" % [mistakes, MAX_MISTAKES]
	if mistakes > 0:
		_mistakes_label.add_theme_color_override("font_color", AppTheme.ERROR)


## 某數字已正確放滿 9 個時，停用該數字鍵
func _update_numberpad() -> void:
	for d in range(1, 10):
		var n := 0
		for i in 81:
			if board.values[i] == d and not board.errors[i]:
				n += 1
		_num_buttons[d - 1].disabled = n >= 9


# ---- 存檔 ----

func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress({
		"game": "sudoku",
		"mode": mode,
		"difficulty": difficulty,
		"date": Daily.today_id() if mode == "daily" else "",
		"values": board.values.duplicate(),
		"given": board.given.duplicate(),
		"errors": board.errors.duplicate(),
		"notes": board.notes.duplicate(),
		"solution": solution.duplicate(),
		"mistakes": mistakes,
		"seconds": int(seconds),
		"hints": hints_used,
	})


## JSON 讀回來的數字都是 float，統一轉回 int
static func _to_int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out
