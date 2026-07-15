class_name FreecellScreen
extends Control
## 新接龍（FreeCell）遊戲畫面：兩段式移動（選牌→點目的地）、整段搬移上限、
## 自由格暫存、自動收基礎堆、完整復原、計時與存檔續玩。
## config：
##   { "mode": "normal" }                     新局
##   { "mode": "daily", "seed": int }         每日挑戰（同種子同牌局，獲勝才算完成）
##   { "mode": "resume" }                     還原

var config: Dictionary = {}

var mode := "normal"
var seconds := 0.0
var moves := 0
var finished := false
var counted := false
var undo_stack: Array = []

var board: FreecellBoard
var _moves_label: Label
var _timer_label: Label
var _last_timer_text := ""
var _undo_btn: Button


func _ready() -> void:
	mode = String(config.get("mode", "normal"))
	_build_ui()
	if mode == "resume":
		_restore(SaveManager.get_in_progress("freecell"))
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
	var title := Label.new()
	title.text = "每日挑戰·新接龍" if mode == "daily" else "新接龍"
	title.add_theme_font_size_override("font_size", 34)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	title.custom_minimum_size = Vector2(1, 0)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(title)
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

	board = FreecellBoard.new()
	board.size_flags_vertical = Control.SIZE_EXPAND_FILL
	board.target_tapped.connect(_on_target)
	col.add_child(board)

	var hint := Label.new()
	hint.text = "點牌選取 → 點目的地移動·左上為暫存格"
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
	var auto_btn := Button.new()
	auto_btn.text = "收基礎堆"
	auto_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(auto_btn)
	auto_btn.pressed.connect(_auto_collect)
	tools.add_child(auto_btn)
	var restart := Button.new()
	restart.text = "重新發牌"
	restart.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	AppTheme.style_secondary(restart)
	restart.pressed.connect(_on_restart_pressed)
	tools.add_child(restart)

	var tools2 := HBoxContainer.new()
	tools2.add_theme_constant_override("separation", 12)
	col.add_child(tools2)
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


## 提示：找一個目前合法的動作並直接選取那張牌，玩家自己決定搬去哪。
## 優先順序：能上基礎堆的牌 → 牌桌之間能搬動的段（含暫存格裡的牌）。
func _on_hint() -> void:
	if finished:
		return
	# 優先：暫存格或牌桌頂牌能直接上基礎堆
	for k in 4:
		if board.free[k] >= 0 and _foundation_for(board.free[k]) >= 0:
			board.set_selected("free", k, 0)
			board.queue_redraw()
			return
	for c in FreecellLogic.CASCADES:
		var cascade: Array = board.cascades[c]
		if not cascade.is_empty() and _foundation_for(int(cascade[-1])) >= 0:
			board.set_selected("cascade", c, cascade.size() - 1)
			board.queue_redraw()
			return
	# 其次：牌桌之間能搬動的合法連續段
	for c in FreecellLogic.CASCADES:
		var cascade: Array = board.cascades[c]
		for i in cascade.size():
			var run2: Array = cascade.slice(i)
			if not FreecellLogic.is_valid_run(run2):
				continue
			if _find_any_cascade_for(run2, c) >= 0:
				board.set_selected("cascade", c, i)
				board.queue_redraw()
				return
	# 暫存格裡的牌能搬到牌桌
	for k in 4:
		if board.free[k] >= 0 and _find_any_cascade_for([board.free[k]], -1) >= 0:
			board.set_selected("free", k, 0)
			board.queue_redraw()
			return
	# 最後：只要還有空暫存格，把最長一疊的頂牌暫放進去永遠合法
	# （開局常常沒有其他更好的動作，這一步仍然是正確且有用的提示，不能漏掉）
	if FreecellLogic.count_free_slots(board.free) > 0:
		var longest := -1
		var longest_len := 0
		for c in FreecellLogic.CASCADES:
			var len_c: int = (board.cascades[c] as Array).size()
			if len_c > longest_len:
				longest_len = len_c
				longest = c
		if longest >= 0:
			board.set_selected("cascade", longest, (board.cascades[longest] as Array).size() - 1)
			board.queue_redraw()
			return
	OverlayDialog.open(self, "提示", tr("目前沒有更多可行的移動了"), [{"text": "確定"}])


func _foundation_for(card: int) -> int:
	for f in 4:
		if SolitaireLogic.can_foundation(card, board.foundations[f]):
			return f
	return -1


func _find_any_cascade_for(run: Array, exclude: int) -> int:
	for c in FreecellLogic.CASCADES:
		if c == exclude:
			continue
		if _can_drop_on_cascade(run, c):
			return c
	return -1


func _show_how_to_play() -> void:
	OverlayDialog.open(self, "怎麼玩", tr("規則與接龍相同，但全部 52 張牌一開始就攤開。左上角 4 個暫存格可以暫時放置任意一張牌，是重要的策略資源（橘色格子）。整段連續的牌可以一次搬移，數量取決於目前空的暫存格與空列數量。"), [{"text": "確定"}])


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
	var deal := FreecellLogic.new_deal(rng)
	board.cascades = deal["cascades"]
	board.free = deal["free"]
	board.foundations = deal["foundations"]
	seconds = 0.0
	moves = 0
	finished = false
	counted = false
	undo_stack.clear()
	board.clear_selected()
	board.queue_redraw()
	_refresh()
	_save_state()


func _restore(state: Dictionary) -> void:
	if state.is_empty() or String(state.get("game", "")) != "freecell":
		_new_game()
		return
	mode = String(state.get("mode", "normal"))
	board.cascades = SolitaireScreen._to_nested(state.get("cascades", []), FreecellLogic.CASCADES)
	board.free = SolitaireScreen._to_int_array(state.get("free", []))
	board.foundations = SolitaireScreen._to_nested(state.get("foundations", []), 4)
	seconds = float(state.get("seconds", 0))
	moves = int(state.get("moves", 0))
	counted = bool(state.get("counted", false))
	finished = false
	board.clear_selected()
	board.queue_redraw()
	_refresh()


# ---- 點擊處理（兩段式）----

func _on_target(zone: String, pile: int, index: int) -> void:
	if finished:
		return
	match zone:
		"free":
			_handle_free_tap(pile)
		"foundation":
			_handle_foundation_tap(pile)
		"cascade":
			_handle_cascade_tap(pile, index)


func _handle_free_tap(k: int) -> void:
	var run := _selected_run()
	# 有選取且是單張 → 移入空的自由格
	if run.size() == 1 and board.free[k] < 0:
		_push_undo()
		_remove_selected_run()
		board.free[k] = int(run[0])
		board.clear_selected()
		_after_move()
		return
	# 沒有選取（或無效）→ 選取該自由格的牌
	if board.free[k] >= 0:
		board.set_selected("free", k, 0)
	else:
		board.clear_selected()


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


func _handle_cascade_tap(col: int, index: int) -> void:
	var cascade: Array = board.cascades[col]
	if board.selected_zone != "":
		# 點同一張第二次：快速自動移動（單張優先基礎堆）
		if board.selected_zone == "cascade" and board.selected_pile == col \
				and board.selected_index == index:
			_smart_move_selected()
			return
		var run := _selected_run()
		var from_this := board.selected_zone == "cascade" and board.selected_pile == col
		if not run.is_empty() and not from_this:
			if _can_drop_on_cascade(run, col):
				_push_undo()
				_remove_selected_run()
				(board.cascades[col] as Array).append_array(run)
				board.clear_selected()
				_after_move()
				return
			# 目的地是空列且失敗，唯一原因就是張數超過目前可搬上限——
			# 明確告知原因並保留選取，讓玩家能立刻試別的目的地，
			# 不要什麼都不說就默默取消選取（之前這樣玩家會誤以為卡死）
			if cascade.is_empty():
				var cap := _supermove_cap(true)
				var msg := tr("這段有 %d 張牌，目前最多只能搬 %d 張") % [run.size(), cap] \
						+ "\n" + tr("空暫存格與空列愈多，能搬的張數愈多")
				OverlayDialog.open(self, "無法搬移", msg, [
					{"text": "確定"},
				])
				return
	# 改選這一疊的牌（該段必須是合法連續段）
	if index < 0 or cascade.is_empty():
		board.clear_selected()
		return
	var run2: Array = cascade.slice(index)
	if FreecellLogic.is_valid_run(run2):
		board.set_selected("cascade", col, index)
	else:
		board.clear_selected()


func _selected_run() -> Array:
	if board.selected_zone == "free":
		if board.selected_pile >= 0 and board.free[board.selected_pile] >= 0:
			return [board.free[board.selected_pile]]
		return []
	if board.selected_zone == "cascade":
		var cascade: Array = board.cascades[board.selected_pile]
		if board.selected_index < 0 or board.selected_index >= cascade.size():
			return []
		return cascade.slice(board.selected_index)
	return []


func _remove_selected_run() -> void:
	if board.selected_zone == "free":
		board.free[board.selected_pile] = -1
	elif board.selected_zone == "cascade":
		var col := board.selected_pile
		board.cascades[col] = (board.cascades[col] as Array).slice(0, board.selected_index)


## 目前整段搬移上限（(空暫存格+1) × 2^空列數；搬到空列時該列本身不計入）
func _supermove_cap(to_empty: bool) -> int:
	return FreecellLogic.max_run_size(
		FreecellLogic.count_free_slots(board.free),
		FreecellLogic.count_empty_cascades(board.cascades),
		to_empty
	)


## 目的地檢查：疊牌規則 + 整段搬移上限
func _can_drop_on_cascade(run: Array, col: int) -> bool:
	var cascade: Array = board.cascades[col]
	var to_empty := cascade.is_empty()
	var cap := _supermove_cap(to_empty)
	if run.size() > cap:
		return false
	if to_empty:
		return true
	return SolitaireLogic.can_stack(int(run[0]), int(cascade[-1]))


func _smart_move_selected() -> void:
	var run := _selected_run()
	if run.is_empty():
		board.clear_selected()
		return
	if run.size() == 1:
		for f in 4:
			if SolitaireLogic.can_foundation(int(run[0]), board.foundations[f]):
				_push_undo()
				_remove_selected_run()
				(board.foundations[f] as Array).append(int(run[0]))
				board.clear_selected()
				_after_move()
				return
	var exclude := board.selected_pile if board.selected_zone == "cascade" else -1
	# 修正：先找非空列（優先疊牌），空列本來就被排除在下方單獨檢查，
	# 之前的版本連空列都跳過，導致「唯一合法去處是空列」時快速移動會失效
	for c in FreecellLogic.CASCADES:
		if c == exclude:
			continue
		if not (board.cascades[c] as Array).is_empty() and _can_drop_on_cascade(run, c):
			_push_undo()
			_remove_selected_run()
			(board.cascades[c] as Array).append_array(run)
			board.clear_selected()
			_after_move()
			return
	for c in FreecellLogic.CASCADES:
		if c == exclude:
			continue
		if (board.cascades[c] as Array).is_empty() and _can_drop_on_cascade(run, c):
			_push_undo()
			_remove_selected_run()
			(board.cascades[c] as Array).append_array(run)
			board.clear_selected()
			_after_move()
			return
	# 單張牌沒有牌桌可去時，最後試試放入空的暫存格
	if run.size() == 1:
		for k in 4:
			if board.free[k] < 0:
				_push_undo()
				_remove_selected_run()
				board.free[k] = int(run[0])
				board.clear_selected()
				_after_move()
				return
	board.clear_selected()


func _after_move() -> void:
	moves += 1
	if not counted:
		counted = true
		var s := SaveManager.section("freecell_stats")
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
		"cascades": board.cascades.duplicate(true),
		"free": board.free.duplicate(),
		"foundations": board.foundations.duplicate(true),
	})
	if undo_stack.size() > 200:
		undo_stack.pop_front()


func _on_undo() -> void:
	if finished or undo_stack.is_empty():
		return
	var snap: Dictionary = undo_stack.pop_back()
	board.cascades = snap["cascades"]
	board.free = SolitaireScreen._to_int_array(snap["free"])
	board.foundations = snap["foundations"]
	moves += 1
	board.clear_selected()
	board.queue_redraw()
	_refresh()
	_save_state()


## 反覆把可上基礎堆的牌（疊頂與自由格）全部收上去
func _auto_collect() -> void:
	if finished:
		return
	board.clear_selected()
	_push_undo()
	var guard := 0
	var progress := true
	var did_any := false
	while progress and guard < 300:
		progress = false
		guard += 1
		for c in FreecellLogic.CASCADES:
			var cascade: Array = board.cascades[c]
			if cascade.is_empty():
				continue
			for f in 4:
				if SolitaireLogic.can_foundation(int(cascade[-1]), board.foundations[f]):
					(board.foundations[f] as Array).append(cascade.pop_back())
					moves += 1
					progress = true
					did_any = true
					break
		for k in 4:
			if board.free[k] < 0:
				continue
			for f in 4:
				if SolitaireLogic.can_foundation(board.free[k], board.foundations[f]):
					(board.foundations[f] as Array).append(board.free[k])
					board.free[k] = -1
					moves += 1
					progress = true
					did_any = true
					break
	if not did_any:
		undo_stack.pop_back()  # 沒動作就不留快照
	board.queue_redraw()
	_refresh()
	if SolitaireLogic.is_won(board.foundations):
		_win()
	else:
		_save_state()


# ---- 勝負 ----

func _win() -> void:
	finished = true
	Sfx.play("win")
	SaveManager.record_result("freecell", 0, true)
	var s := SaveManager.section("freecell_stats")
	var best := int(s.get("best_time", 0))
	if best == 0 or int(seconds) < best:
		s["best_time"] = int(seconds)
	SaveManager.save()
	SaveManager.set_in_progress("freecell", {})
	_refresh()
	var msg := tr("時間：%s·共 %d 步") % [SudokuScreen.format_time(int(seconds)), moves]
	var buttons: Array = []
	if mode == "daily":
		Daily.mark_completed()
		msg += "\n" + tr("每日挑戰完成！連續 %d 天") % Daily.streak()
	else:
		buttons.append({"text": "再來一局", "action": _new_game})
	buttons.append({"text": "回首頁", "action": _go_home, "secondary": not buttons.is_empty()})
	OverlayDialog.open(self, "恭喜完成！", msg, buttons)


func _on_restart_pressed() -> void:
	OverlayDialog.open(self, "重新發牌？", "目前的牌局將被捨棄", [
		{"text": "重新發牌", "action": _new_game},
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
	_moves_label.text = tr("步數 %d") % moves
	_last_timer_text = SudokuScreen.format_time(int(seconds))
	_timer_label.text = _last_timer_text
	_undo_btn.disabled = finished or undo_stack.is_empty()


func _save_state() -> void:
	if finished:
		return
	SaveManager.set_in_progress("freecell", {
		"game": "freecell",
		"mode": mode,
		"difficulty": 0,
		"date": Daily.today_id() if mode == "daily" else "",
		"cascades": board.cascades.duplicate(true),
		"free": board.free.duplicate(),
		"foundations": board.foundations.duplicate(true),
		"seconds": int(seconds),
		"moves": moves,
		"counted": counted,
	})