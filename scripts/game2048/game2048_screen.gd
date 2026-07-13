class_name Game2048Screen
extends Control
## 2048 遊戲畫面：滑動（觸控）或方向鍵操作、分數與最佳紀錄、單步復原、
## 達成 2048 後可繼續挑戰、自動存檔續玩。
## config：
##   { "mode": "normal" }   新局
##   { "mode": "resume" }   從 SaveManager 還原

var config: Dictionary = {}

var score := 0
var reached_2048 := false
var finished := false
var _undo_snapshot: Dictionary = {}

var board: Game2048Board
var _score_label: Label
var _best_label: Label
var _undo_btn: Button


func _ready() -> void:
	_build_ui()
	if String(config.get("mode", "normal")) == "resume":
		_restore(SaveManager.get_in_progress("game2048"))
	else:
		_new_game()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_left"):
		_move(Game2048Logic.DIR_LEFT)
	elif event.is_action_pressed("ui_right"):
		_move(Game2048Logic.DIR_RIGHT)
	elif event.is_action_pressed("ui_up"):
		_move(Game2048Logic.DIR_UP)
	elif event.is_action_pressed("ui_down"):
		_move(Game2048Logic.DIR_DOWN)


# 整個畫面（棋盤以外的空白區域）也接受滑動手勢，
# 只要不是落在按鈕上的點擊都能操作，觸控範圍大幅加大
var _press_pos := Vector2.ZERO
var _tracking := false


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_tracking = true
		elif _tracking:
			_tracking = false
			var d: Vector2 = event.position - _press_pos
			if d.length() >= Game2048Board.SWIPE_MIN_PX:
				if absf(d.x) > absf(d.y):
					_move(Game2048Logic.DIR_RIGHT if d.x > 0 else Game2048Logic.DIR_LEFT)
				else:
					_move(Game2048Logic.DIR_DOWN if d.y > 0 else Game2048Logic.DIR_UP)


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
	var title := Label.new()
	title.text = "2048"
	title.add_theme_font_size_override("font_size", 34)
	top.add_child(title)
	top.add_child(_spacer())
	var ghost := Button.new()
	ghost.text = "← 返回"
	ghost.modulate = Color(1, 1, 1, 0)
	ghost.disabled = true
	top.add_child(ghost)

	var info := HBoxContainer.new()
	col.add_child(info)
	_score_label = Label.new()
	_score_label.add_theme_font_size_override("font_size", 30)
	info.add_child(_score_label)
	info.add_child(_spacer())
	_best_label = Label.new()
	_best_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_best_label)

	var aspect := AspectRatioContainer.new()
	aspect.ratio = 1.0
	aspect.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(aspect)
	board = Game2048Board.new()
	board.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.swiped.connect(_move)
	aspect.add_child(board)

	var hint := Label.new()
	hint.text = "滑動棋盤合併相同數字"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	col.add_child(hint)

	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 12)
	col.add_child(tools)
	_undo_btn = Button.new()
	_undo_btn.text = "復原"
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
	s.mouse_filter = Control.MOUSE_FILTER_IGNORE  # 讓滑動手勢穿透到畫面層
	return s


# ---- 遊戲流程 ----

func _new_game() -> void:
	board.grid = Game2048Logic.new_grid()
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	Game2048Logic.spawn(board.grid, rng)
	Game2048Logic.spawn(board.grid, rng)
	score = 0
	reached_2048 = false
	finished = false
	_undo_snapshot = {}
	_refresh()
	_save_state()


func _restore(state: Dictionary) -> void:
	var g := _to_int_array(state.get("grid", []))
	if state.is_empty() or String(state.get("game", "")) != "game2048" \
			or g.size() != Game2048Logic.CELLS:
		_new_game()
		return
	board.grid = g
	score = int(state.get("score", 0))
	reached_2048 = bool(state.get("reached", false))
	finished = false
	_refresh()


func _move(dir: int) -> void:
	if finished:
		return
	var before_grid: Array[int] = board.grid.duplicate()
	var before_score := score
	var result := Game2048Logic.slide(board.grid, dir)
	if not bool(result["moved"]):
		return
	_undo_snapshot = {"grid": before_grid, "score": before_score, "reached": reached_2048}
	score += int(result["gained"])
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	Game2048Logic.spawn(board.grid, rng)
	Sfx.play("stone")
	_update_records()
	board.queue_redraw()
	_refresh()
	_save_state()
	# 首次達成 2048
	if not reached_2048 and Game2048Logic.max_tile(board.grid) >= 2048:
		reached_2048 = true
		_save_state()
		Sfx.play("win")
		OverlayDialog.open(self, "達成 2048！",
				tr("分數：%d") % score + "\n" + tr("可以繼續挑戰更大的數字"), [
			{"text": "繼續挑戰"},
			{"text": "回首頁", "action": _go_home, "secondary": true},
		])
		return
	if not Game2048Logic.can_move(board.grid):
		_game_over()


func _game_over() -> void:
	finished = true
	Sfx.play("lose")
	var s := SaveManager.section("game2048_stats")
	s["played"] = int(s.get("played", 0)) + 1
	if reached_2048:
		s["won"] = int(s.get("won", 0)) + 1
	SaveManager.save()
	SaveManager.set_in_progress("game2048", {})
	Achievements.refresh()
	OverlayDialog.open(self, "無法再移動", tr("分數：%d·最大磚塊：%d") % [
		score, Game2048Logic.max_tile(board.grid)
	], [
		{"text": "再來一局", "action": _new_game},
		{"text": "回首頁", "action": _go_home, "secondary": true},
	])


## 更新最佳紀錄（分數與最大磚塊），成就依 best_tile 判定
func _update_records() -> void:
	var s := SaveManager.section("game2048_stats")
	var changed := false
	if score > int(s.get("best_score", 0)):
		s["best_score"] = score
		changed = true
	var tile := Game2048Logic.max_tile(board.grid)
	if tile > int(s.get("best_tile", 0)):
		s["best_tile"] = tile
		changed = true
	if changed:
		SaveManager.save()
		Achievements.refresh()


func _on_undo() -> void:
	if finished or _undo_snapshot.is_empty():
		return
	board.grid = _to_int_array(_undo_snapshot["grid"])
	score = int(_undo_snapshot["score"])
	reached_2048 = bool(_undo_snapshot["reached"])
	_undo_snapshot = {}
	board.queue_redraw()
	_refresh()
	_save_state()


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
	_score_label.text = tr("分數 %d") % score
	_best_label.text = tr("最佳 %d") % int(SaveManager.section("game2048_stats").get("best_score", 0))
	_undo_btn.disabled = finished or _undo_snapshot.is_empty()


func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress("game2048", {
		"game": "game2048",
		"mode": "normal",
		"difficulty": 0,
		"grid": board.grid.duplicate(),
		"score": score,
		"reached": reached_2048,
	})


static func _to_int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out
