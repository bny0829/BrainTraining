class_name SolitaireScreen
extends Control
## 接龍遊戲畫面：點擊自動移動（點牌自動找基礎堆→牌桌的最佳去處）、
## 翻庫存牌（翻完自動回收重來，可選一次翻一張或三張）、完整復原、殘局自動收尾、計時與存檔續玩。
## config：{ "mode": "normal" } 新局；{ "mode": "resume" } 還原。

var config: Dictionary = {}

var seconds := 0.0
var moves := 0
var finished := false
var counted := false  # 本局是否已計入場次（第一步時計）
var undo_stack: Array = []
## 一次翻牌張數（1 或 3）。只有最外側（最後翻出）那張可操作，
## 移走後才能碰到下一張——這點完全沿用既有規則，waste 一律只有 waste[-1] 可互動，
## 不需要另外處理「哪幾張是暫時看不到的」。
var draw_count := 1
var _draw_btn: Button

var board: SolitaireBoard
var _moves_label: Label
var _timer_label: Label
var _last_timer_text := ""
var _undo_btn: Button
var _auto_btn: Button


func _ready() -> void:
	_build_ui()
	if String(config.get("mode", "normal")) == "resume":
		_restore(SaveManager.get_in_progress("solitaire"))
	else:
		_new_game()


func _process(delta: float) -> void:
	if finished or moves == 0:
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
	col.add_theme_constant_override("separation", 14)
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
	title.text = "接龍"
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
	_moves_label = Label.new()
	_moves_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_moves_label)
	info.add_child(_spacer())
	_timer_label = Label.new()
	_timer_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	info.add_child(_timer_label)

	board = SolitaireBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.target_tapped.connect(_on_target)
	col.add_child(board)

	var hint := Label.new()
	hint.text = "點牌選取 → 點目的地移動·連點兩下自動移動"
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
	_auto_btn = Button.new()
	_auto_btn.text = "自動收尾"
	_auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_auto_btn.visible = false
	_auto_btn.pressed.connect(_auto_finish)
	tools.add_child(_auto_btn)
	var restart := Button.new()
	restart.text = "重新發牌"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(restart)
	restart.pressed.connect(_on_restart_pressed)
	tools.add_child(restart)

	var tools2 := HBoxContainer.new()
	tools2.add_theme_constant_override("separation", 12)
	col.add_child(tools2)
	_draw_btn = Button.new()
	_draw_btn.clip_text = true
	_draw_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(_draw_btn)
	_draw_btn.pressed.connect(_on_toggle_draw_count)
	tools2.add_child(_draw_btn)
	var hint_btn := Button.new()
	hint_btn.text = "提示"
	hint_btn.clip_text = true
	hint_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(hint_btn)
	hint_btn.pressed.connect(_on_hint)
	tools2.add_child(hint_btn)
	var how_btn := Button.new()
	how_btn.text = "說明"
	how_btn.clip_text = true
	how_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(how_btn)
	how_btn.pressed.connect(_show_how_to_play)
	tools2.add_child(how_btn)


## 提示：找一個目前合法的動作並直接選取那張牌（不強制去哪，玩家自己點目的地）。
## 優先順序：能上基礎堆的牌 → 牌桌之間能搬動的段 → 廢牌能搬到牌桌。
## 都找不到才提醒翻庫存牌或告知目前卡關。
func _on_hint() -> void:
	if finished:
		return
	if not board.waste.is_empty() and _find_foundation(int(board.waste[-1])) >= 0:
		board.set_selected("waste", 0, board.waste.size() - 1)
		board.queue_redraw()
		return
	for c in SolitaireLogic.COLUMNS:
		var column: Array = board.columns[c]
		if not column.is_empty() and _find_foundation(int(column[-1])) >= 0:
			board.set_selected("column", c, column.size() - 1)
			board.queue_redraw()
			return
	for c in SolitaireLogic.COLUMNS:
		var column: Array = board.columns[c]
		var down_n: int = column.size() - board.face_up[c]
		for i in range(down_n, column.size()):
			if _find_column_for(int(column[i]), c) >= 0:
				board.set_selected("column", c, i)
				board.queue_redraw()
				return
	if not board.waste.is_empty() and _find_column_for(int(board.waste[-1]), -1) >= 0:
		board.set_selected("waste", 0, board.waste.size() - 1)
		board.queue_redraw()
		return
	if not board.stock.is_empty() or not board.waste.is_empty():
		OverlayDialog.open(self, "提示", tr("目前沒有牌可以移動，試著翻開庫存牌看看"), [{"text": "確定"}])
	else:
		OverlayDialog.open(self, "提示", tr("目前沒有更多可行的移動了"), [{"text": "確定"}])


func _show_how_to_play() -> void:
	OverlayDialog.open(self, "怎麼玩", tr("把全部 52 張牌依花色從 A 到 K 收上右上角 4 個基礎堆即獲勝。牌桌上的牌可依「點數遞減、紅黑交替」的規則互相疊放，空列只能放 K。點牌選取、再點目的地移動，連點兩下自動移動。左上角可翻開庫存牌。"), [{"text": "確定"}])


func _spacer() -> Control:
	var s := Control.new()
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s


# ---- 遊戲流程 ----

func _new_game() -> void:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var deal := SolitaireLogic.new_deal(rng)
	board.stock = deal["stock"]
	board.waste = deal["waste"]
	board.foundations = deal["foundations"]
	board.columns = deal["columns"]
	board.face_up = deal["face_up"]
	seconds = 0.0
	moves = 0
	finished = false
	counted = false
	undo_stack.clear()
	draw_count = int(SaveManager.section("settings").get("solitaire_draw_count", 1))
	board.draw_count = draw_count
	board.clear_selected()
	board.queue_redraw()
	_refresh()
	_save_state()


func _restore(state: Dictionary) -> void:
	if state.is_empty() or String(state.get("game", "")) != "solitaire":
		_new_game()
		return
	board.stock = _to_int_array(state.get("stock", []))
	board.waste = _to_int_array(state.get("waste", []))
	board.foundations = _to_nested(state.get("foundations", []), 4)
	board.columns = _to_nested(state.get("columns", []), 7)
	board.face_up = _to_int_array(state.get("face_up", []))
	seconds = float(state.get("seconds", 0))
	moves = int(state.get("moves", 0))
	counted = bool(state.get("counted", false))
	draw_count = int(state.get("draw_count", 1))
	board.draw_count = draw_count
	finished = false
	board.clear_selected()
	board.queue_redraw()
	_refresh()


# ---- 點擊處理（兩段式：先選牌、再點目的地；點同一張第二次 = 快速自動移動）----

func _on_target(zone: String, pile: int, index: int) -> void:
	if finished:
		return
	match zone:
		"stock":
			board.clear_selected()
			_tap_stock()
		"waste":
			_handle_waste_tap()
		"foundation":
			_handle_foundation_tap(pile)
		"column":
			_handle_column_tap(pile, index)


func _tap_stock() -> void:
	if board.stock.is_empty() and board.waste.is_empty():
		return
	_push_undo()
	if board.stock.is_empty():
		# 廢牌翻回庫存（無限次重發）
		var w := board.waste.duplicate()
		w.reverse()
		board.stock = w
		board.waste.clear()
	else:
		var n := mini(draw_count, board.stock.size())
		for i in n:
			board.waste.append(board.stock.pop_back())
	_after_move()


func _handle_waste_tap() -> void:
	if board.waste.is_empty():
		board.clear_selected()
		return
	if board.selected_zone == "waste":
		_smart_move_selected()  # 點第二次：快速自動移動
	else:
		board.set_selected("waste", 0, board.waste.size() - 1)


## 點基礎堆：把選取中的單張牌移上去（合法才移）
func _handle_foundation_tap(f: int) -> void:
	var run := _selected_run()
	if run.size() != 1:
		return
	if SolitaireLogic.can_foundation(int(run[0]), board.foundations[f]):
		_push_undo()
		_remove_selected_run()
		(board.foundations[f] as Array).append(int(run[0]))
		board.clear_selected()
		_after_move()


func _handle_column_tap(col: int, index: int) -> void:
	var column: Array = board.columns[col]
	if board.selected_zone != "":
		# 點同一張第二次：快速自動移動
		if board.selected_zone == "column" and board.selected_pile == col \
				and board.selected_index == index:
			_smart_move_selected()
			return
		# 嘗試把選取的牌移到這一列
		var run := _selected_run()
		var from_this := board.selected_zone == "column" and board.selected_pile == col
		if not run.is_empty() and not from_this and _can_drop_on_column(int(run[0]), col):
			_push_undo()
			_remove_selected_run()
			(board.columns[col] as Array).append_array(run)
			board.face_up[col] += run.size()
			board.clear_selected()
			_after_move()
			return
	# 不是合法目的地：改選這一列的牌（或取消選取）
	if index < 0 or column.is_empty():
		board.clear_selected()
		return
	var down_n := column.size() - board.face_up[col]
	if index < down_n:
		board.clear_selected()  # 蓋著的牌不能選
		return
	board.set_selected("column", col, index)


## 目前選取的整段牌（無選取回傳空陣列）
func _selected_run() -> Array:
	if board.selected_zone == "waste":
		return [] if board.waste.is_empty() else [board.waste[-1]]
	if board.selected_zone == "column":
		var column: Array = board.columns[board.selected_pile]
		if board.selected_index < 0 or board.selected_index >= column.size():
			return []
		return column.slice(board.selected_index)
	return []


## 從來源堆移除目前選取的牌（呼叫前先 _push_undo）
func _remove_selected_run() -> void:
	if board.selected_zone == "waste":
		board.waste.pop_back()
	elif board.selected_zone == "column":
		var col := board.selected_pile
		var n: int = (board.columns[col] as Array).size() - board.selected_index
		board.columns[col] = (board.columns[col] as Array).slice(0, board.selected_index)
		_shrink_face_up(col, n)


## 快速自動移動：單張優先基礎堆，其次找可疊的牌桌列
func _smart_move_selected() -> void:
	var run := _selected_run()
	if run.is_empty():
		board.clear_selected()
		return
	if run.size() == 1:
		var f := _find_foundation(int(run[0]))
		if f >= 0:
			_push_undo()
			_remove_selected_run()
			(board.foundations[f] as Array).append(int(run[0]))
			board.clear_selected()
			_after_move()
			return
	var exclude := board.selected_pile if board.selected_zone == "column" else -1
	var c := _find_column_for(int(run[0]), exclude)
	if c >= 0:
		_push_undo()
		_remove_selected_run()
		(board.columns[c] as Array).append_array(run)
		board.face_up[c] += run.size()
		board.clear_selected()
		_after_move()
		return
	board.clear_selected()


func _can_drop_on_column(head: int, col: int) -> bool:
	var column: Array = board.columns[col]
	if column.is_empty():
		return SolitaireLogic.rank_of(head) == 12
	return SolitaireLogic.can_stack(head, int(column[-1]))


## 從某列移走 n 張面朝上的牌後，維護 face_up 並自動翻開新頂牌
func _shrink_face_up(col: int, n: int) -> void:
	board.face_up[col] -= n
	var column: Array = board.columns[col]
	if column.is_empty():
		board.face_up[col] = 0
	elif board.face_up[col] <= 0:
		board.face_up[col] = 1  # 翻開新露出的牌


func _find_foundation(card: int) -> int:
	for f in 4:
		if SolitaireLogic.can_foundation(card, board.foundations[f]):
			return f
	return -1


func _find_column_for(head: int, exclude: int) -> int:
	for c in SolitaireLogic.COLUMNS:
		if c == exclude:
			continue
		var column: Array = board.columns[c]
		if column.is_empty():
			if SolitaireLogic.rank_of(head) == 12:
				return c
		elif SolitaireLogic.can_stack(head, int(column[-1])):
			return c
	return -1


func _after_move() -> void:
	moves += 1
	if not counted:
		counted = true
		var s := SaveManager.section("solitaire_stats")
		s["played"] = int(s.get("played", 0)) + 1
		SaveManager.save()
	Sfx.play("stone")
	board.queue_redraw()
	_refresh()
	if SolitaireLogic.is_won(board.foundations):
		_win()
		return
	_save_state()


func _push_undo() -> void:
	undo_stack.append({
		"stock": board.stock.duplicate(),
		"waste": board.waste.duplicate(),
		"foundations": board.foundations.duplicate(true),
		"columns": board.columns.duplicate(true),
		"face_up": board.face_up.duplicate(),
	})
	if undo_stack.size() > 200:
		undo_stack.pop_front()


func _on_undo() -> void:
	if finished or undo_stack.is_empty():
		return
	var snap: Dictionary = undo_stack.pop_back()
	board.stock = _to_int_array(snap["stock"])
	board.waste = _to_int_array(snap["waste"])
	board.foundations = snap["foundations"]
	board.columns = snap["columns"]
	board.face_up = _to_int_array(snap["face_up"])
	moves += 1  # 復原也算一步，避免刷步數
	board.clear_selected()
	board.queue_redraw()
	_refresh()
	_save_state()


## 殘局自動收尾：庫存與廢牌皆空、全部翻開時，反覆把頂牌送上基礎堆
func _auto_finish() -> void:
	if finished or not _can_auto_finish():
		return
	board.clear_selected()
	_push_undo()
	var guard := 0
	var progress := true
	while progress and guard < 300:
		progress = false
		guard += 1
		for c in SolitaireLogic.COLUMNS:
			var column: Array = board.columns[c]
			if column.is_empty():
				continue
			var f := _find_foundation(int(column[-1]))
			if f >= 0:
				(board.foundations[f] as Array).append(column.pop_back())
				_shrink_face_up(c, 1)
				moves += 1
				progress = true
	board.queue_redraw()
	_refresh()
	if SolitaireLogic.is_won(board.foundations):
		_win()
	else:
		_save_state()


func _can_auto_finish() -> bool:
	if not board.stock.is_empty() or not board.waste.is_empty():
		return false
	for c in SolitaireLogic.COLUMNS:
		var column: Array = board.columns[c]
		if not column.is_empty() and board.face_up[c] < column.size():
			return false
	return true


# ---- 勝負 ----

func _win() -> void:
	finished = true
	Sfx.play("win")
	SaveManager.record_result("solitaire", 0, true)
	var s := SaveManager.section("solitaire_stats")
	var best := int(s.get("best_time", 0))
	if best == 0 or int(seconds) < best:
		s["best_time"] = int(seconds)
	SaveManager.save()
	SaveManager.set_in_progress("solitaire", {})
	_refresh()
	OverlayDialog.open(self, "恭喜完成！", tr("時間：%s·共 %d 步") % [
		SudokuScreen.format_time(int(seconds)), moves
	], [
		{"text": "再來一局", "action": _new_game},
		{"text": "回首頁", "action": _go_home, "secondary": true},
	])


func _on_restart_pressed() -> void:
	OverlayDialog.open(self, "重新發牌？", "目前的牌局將被捨棄", [
		{"text": "重新發牌", "action": _new_game},
		{"text": "取消", "secondary": true},
	])


## 切換一次翻一張／三張：因為會影響庫存翻牌的行為，必須重新發牌才能生效
func _on_toggle_draw_count() -> void:
	var next := 3 if draw_count == 1 else 1
	OverlayDialog.open(self, "重新發牌？", tr("切換為%s後將重新開始這一局") % _draw_mode_text(next), [
		{"text": "確定切換", "action": _apply_draw_count.bind(next)},
		{"text": "取消", "secondary": true},
	])


func _apply_draw_count(next: int) -> void:
	SaveManager.section("settings")["solitaire_draw_count"] = next
	SaveManager.save()
	_new_game()


func _draw_mode_text(n: int) -> String:
	return tr("一次翻一張") if n == 1 else tr("一次翻三張")


func _on_back() -> void:
	if not finished:
		_save_state()
	Main.instance.goto_home()


func _go_home() -> void:
	Main.instance.goto_home()


# ---- 顯示與存檔 ----

func _refresh() -> void:
	_moves_label.text = tr("步數 %d") % moves
	_last_timer_text = SudokuScreen.format_time(int(seconds))
	_timer_label.text = _last_timer_text
	_undo_btn.disabled = finished or undo_stack.is_empty()
	_auto_btn.visible = not finished and _can_auto_finish() \
			and not SolitaireLogic.is_won(board.foundations)
	_draw_btn.text = _draw_mode_text(draw_count)


func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress("solitaire", {
		"game": "solitaire",
		"mode": "normal",
		"difficulty": 0,
		"stock": board.stock.duplicate(),
		"waste": board.waste.duplicate(),
		"foundations": board.foundations.duplicate(true),
		"columns": board.columns.duplicate(true),
		"face_up": board.face_up.duplicate(),
		"seconds": int(seconds),
		"moves": moves,
		"counted": counted,
		"draw_count": draw_count,
	})


static func _to_int_array(a: Variant) -> Array[int]:
	var out: Array[int] = []
	if a is Array:
		for v in a:
			out.append(int(v))
	return out


## JSON 讀回的巢狀陣列轉成 Array[Array[int]]（不足的補空堆）
static func _to_nested(a: Variant, n: int) -> Array:
	var out: Array = []
	if a is Array:
		for sub in a:
			out.append(_to_int_array(sub))
	while out.size() < n:
		out.append([] as Array[int])
	return out
