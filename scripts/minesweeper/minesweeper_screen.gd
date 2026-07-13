class_name MinesweeperScreen
extends Control
## 踩地雷遊戲畫面：首挖保證安全、連鎖翻開、插旗（模式切換或長按）、
## 數字和弦快開（旗數符合時點數字翻開周圍）、計時與自動存檔。
## config：
##   { "mode": "normal", "difficulty": int }             新局
##   { "mode": "daily", "difficulty": int, "seed": int } 每日挑戰（獲勝才算完成）
##   { "mode": "resume" }                                從 SaveManager 還原

var config: Dictionary = {}

var mode := "normal"
var difficulty: int = MinesweeperLogic.Difficulty.BEGINNER
var mine_count := 10
var started := false      # 第一下才佈雷
var finished := false
var flag_mode := false
var seconds := 0.0

var board: MinesweeperBoard
var _title_label: Label
var _mines_label: Label
var _timer_label: Label
var _last_timer_text := ""
var _mode_btn: Button


func _ready() -> void:
	mode = String(config.get("mode", "normal"))
	_build_ui()
	if mode == "resume":
		_restore(SaveManager.get_in_progress("minesweeper"))
	else:
		difficulty = int(config.get("difficulty", MinesweeperLogic.Difficulty.BEGINNER))
		_new_game()


func _process(delta: float) -> void:
	if finished or not started:
		return
	seconds += delta
	var text := SudokuScreen.format_time(int(seconds))
	if text != _last_timer_text:
		_last_timer_text = text
		_timer_label.text = text


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
	_mines_label = Label.new()
	_mines_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_mines_label)
	info.add_child(_spacer())
	_timer_label = Label.new()
	_timer_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_timer_label)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(aspect)
	board = MinesweeperBoard.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.cell_tapped.connect(_on_cell_tapped)
	board.cell_long_pressed.connect(_on_cell_long_pressed)
	aspect.add_child(board)

	var hint := Label.new()
	hint.text = "提示：長按格子可快速插旗"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	col.add_child(hint)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	col.add_child(tools)
	_mode_btn = Button.new()
	_mode_btn.toggle_mode = true
	_mode_btn.text = "模式：挖掘"
	_mode_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(_mode_btn)
	_mode_btn.toggled.connect(_on_mode_toggled)
	tools.add_child(_mode_btn)
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
	var cfg: Dictionary = MinesweeperLogic.CONFIG[difficulty]
	mine_count = int(cfg["mines"])
	board.setup(int(cfg["w"]), int(cfg["h"]))
	started = false
	finished = false
	seconds = 0.0
	_refresh()
	_save_state()


func _restore(state: Dictionary) -> void:
	if state.is_empty() or String(state.get("game", "")) != "minesweeper":
		difficulty = int(config.get("difficulty", MinesweeperLogic.Difficulty.BEGINNER))
		_new_game()
		return
	mode = String(state.get("mode", "normal"))
	difficulty = int(state.get("difficulty", 0))
	mine_count = int(state.get("mine_count", 10))
	board.setup(int(state.get("w", 9)), int(state.get("h", 9)))
	var cells := board.w * board.h
	var m := _to_bool_array(state.get("mines", []))
	var c := _to_int_array(state.get("counts", []))
	var rv := _to_bool_array(state.get("revealed", []))
	var fl := _to_bool_array(state.get("flagged", []))
	if m.size() == cells:
		board.mines = m
		board.counts = c
		board.revealed = rv
		board.flagged = fl
	started = bool(state.get("started", false))
	seconds = float(state.get("seconds", 0))
	finished = false
	_refresh()


# ---- 輸入 ----

func _on_mode_toggled(on: bool) -> void:
	flag_mode = on
	_mode_btn.text = "模式：插旗" if on else "模式：挖掘"


func _on_cell_tapped(i: int) -> void:
	if finished:
		return
	if board.revealed[i]:
		_chord(i)
	elif flag_mode:
		_toggle_flag(i)
	elif not board.flagged[i]:
		_dig(i)


func _on_cell_long_pressed(i: int) -> void:
	if finished or board.revealed[i]:
		return
	_toggle_flag(i)


func _toggle_flag(i: int) -> void:
	board.flagged[i] = not board.flagged[i]
	Sfx.play("tap")
	board.queue_redraw()
	_refresh()
	_save_state()


func _dig(i: int) -> void:
	if not started:
		var rng := RandomNumberGenerator.new()
		if config.has("seed"):
			rng.seed = int(config["seed"])
		else:
			rng.randomize()
		var gen := MinesweeperLogic.generate(board.w, board.h, mine_count, rng, i)
		board.mines = gen["mines"]
		board.counts = gen["counts"]
		started = true
	if board.mines[i]:
		_explode(i)
		return
	MinesweeperLogic.flood_reveal(board.w, board.h, board.mines, board.counts,
			board.revealed, board.flagged, i)
	Sfx.play("stone")
	board.queue_redraw()
	if MinesweeperLogic.is_win(board.mines, board.revealed):
		_win()
	else:
		_refresh()
		_save_state()


## 和弦快開：點已翻開的數字，若周圍旗數＝數字，翻開其餘未插旗格
func _chord(i: int) -> void:
	if board.counts[i] <= 0:
		return
	var flags := 0
	var targets: Array[int] = []
	for j in MinesweeperLogic.neighbors(board.w, board.h, i):
		if board.flagged[j]:
			flags += 1
		elif not board.revealed[j]:
			targets.append(j)
	if flags != board.counts[i] or targets.is_empty():
		return
	for j in targets:
		if finished:
			return
		_dig(j)


func _explode(i: int) -> void:
	finished = true
	board.exploded = i
	board.show_mines = true
	board.queue_redraw()
	Sfx.play("lose")
	SaveManager.record_result("minesweeper", difficulty, false)
	SaveManager.set_in_progress("minesweeper", {})
	_refresh()
	OverlayDialog.open(self, "踩到地雷！", "存活 %s・難度 %s" % [
		SudokuScreen.format_time(int(seconds)), MinesweeperLogic.DIFFICULTY_TEXT[difficulty]
	], [
		{"text": "再試一次", "action": _new_game},
		{"text": "回首頁", "action": _go_home, "secondary": true},
	])


func _win() -> void:
	finished = true
	board.show_mines = false
	Sfx.play("win")
	SaveManager.record_result("minesweeper", difficulty, true)
	SaveManager.set_in_progress("minesweeper", {})
	_refresh()
	var msg := "時間：%s・難度 %s" % [
		SudokuScreen.format_time(int(seconds)), MinesweeperLogic.DIFFICULTY_TEXT[difficulty]
	]
	var buttons: Array = []
	if mode == "daily":
		Daily.mark_completed()
		msg += "\n每日挑戰完成！連續 %d 天" % Daily.streak()
	else:
		buttons.append({"text": "再來一局", "action": _new_game})
	buttons.append({"text": "回首頁", "action": _go_home, "secondary": not buttons.is_empty()})
	OverlayDialog.open(self, "掃雷成功！", msg, buttons)


func _on_restart_pressed() -> void:
	OverlayDialog.open(self, "重新開始？", "目前的進度將被捨棄", [
		{"text": "重新開始", "action": _new_game},
		{"text": "取消", "secondary": true},
	])


func _on_back() -> void:
	if not finished:
		_save_state()
	Main.instance.goto_home()


func _go_home() -> void:
	Main.instance.goto_home()


# ---- 顯示與存檔 ----

func _refresh() -> void:
	var mode_text := "每日挑戰・踩地雷" if mode == "daily" else "踩地雷"
	_title_label.text = "%s・%s" % [mode_text, MinesweeperLogic.DIFFICULTY_TEXT[difficulty]]
	_mines_label.text = "地雷 %d" % maxi(0, mine_count - MinesweeperLogic.flag_count(board.flagged))
	_last_timer_text = SudokuScreen.format_time(int(seconds))
	_timer_label.text = _last_timer_text


func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress("minesweeper", {
		"game": "minesweeper",
		"mode": mode,
		"difficulty": difficulty,
		"date": Daily.today_id() if mode == "daily" else "",
		"w": board.w,
		"h": board.h,
		"mine_count": mine_count,
		"started": started,
		"seconds": int(seconds),
		"mines": board.mines.duplicate(),
		"counts": board.counts.duplicate(),
		"revealed": board.revealed.duplicate(),
		"flagged": board.flagged.duplicate(),
	})


static func _to_int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out


static func _to_bool_array(a: Variant) -> Array[bool]:
	var out: Array[bool] = []
	if a is Array:
		for v in a:
			out.append(bool(v))
	return out
