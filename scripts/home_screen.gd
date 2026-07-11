class_name HomeScreen
extends Control
## 平台首頁：每日挑戰、進行中的遊戲、遊戲清單與戰績。
## UI 以程式建構（v0.1 先求快速迭代，之後穩定再考慮抽成 .tscn）。


func _ready() -> void:
	_discard_stale_daily()
	_build_ui()


## 昨天沒玩完的每日挑戰已過期，直接捨棄
func _discard_stale_daily() -> void:
	var st := SaveManager.get_in_progress()
	if not st.is_empty() and String(st.get("mode", "")) == "daily" \
			and String(st.get("date", "")) != Daily.today_id():
		SaveManager.set_in_progress({})


func _build_ui() -> void:
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(scroll)

	var margin := MarginContainer.new()
	margin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	scroll.add_child(margin)

	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 22)
	margin.add_child(col)

	_build_header(col)
	_build_daily_card(col)
	_build_continue_card(col)
	_build_games(col)
	_build_stats(col)


func _build_header(col: VBoxContainer) -> void:
	var title := Label.new()
	title.text = "Brain Club"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", AppTheme.PRIMARY_DARK)
	col.add_child(title)

	var subtitle := Label.new()
	var streak := Daily.streak()
	subtitle.text = Daily.today_id() + ("　連續挑戰 %d 天" % streak if streak > 0 else "")
	subtitle.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	subtitle.add_theme_font_size_override("font_size", 24)
	col.add_child(subtitle)


func _build_daily_card(col: VBoxContainer) -> void:
	var inner := _card(col)
	var head := Label.new()
	head.text = "每日挑戰"
	head.add_theme_font_size_override("font_size", 34)
	inner.add_child(head)

	var d := Daily.today_difficulty()
	var desc := Label.new()
	desc.text = "%s　數獨・%s %s" % [
		Daily.today_id(), SudokuLogic.DIFFICULTY_TEXT[d], SudokuLogic.DIFFICULTY_STARS[d]
	]
	desc.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	inner.add_child(desc)

	if Daily.is_completed_today():
		var done := Label.new()
		done.text = "今日已完成"
		done.add_theme_color_override("font_color", AppTheme.SUCCESS)
		done.add_theme_font_size_override("font_size", 30)
		inner.add_child(done)
	else:
		var btn := Button.new()
		btn.text = "開始挑戰"
		btn.pressed.connect(func() -> void:
			Main.instance.open_sudoku({
				"mode": "daily",
				"difficulty": Daily.today_difficulty(),
				"seed": Daily.today_seed(),
			})
		)
		inner.add_child(btn)


func _build_continue_card(col: VBoxContainer) -> void:
	var st := SaveManager.get_in_progress()
	if st.is_empty() or String(st.get("game", "")) != "sudoku":
		return
	var inner := _card(col)
	var head := Label.new()
	head.text = "進行中的遊戲"
	head.add_theme_font_size_override("font_size", 34)
	inner.add_child(head)

	var mode_text := "每日挑戰" if String(st.get("mode", "")) == "daily" else "數獨"
	var desc := Label.new()
	desc.text = "%s・%s・%s" % [
		mode_text,
		SudokuLogic.DIFFICULTY_TEXT[int(st.get("difficulty", 0))],
		SudokuScreen.format_time(int(st.get("seconds", 0))),
	]
	desc.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	inner.add_child(desc)

	var btn := Button.new()
	btn.text = "繼續"
	btn.pressed.connect(func() -> void:
		Main.instance.open_sudoku({"mode": "resume"})
	)
	inner.add_child(btn)


func _build_games(col: VBoxContainer) -> void:
	var head := Label.new()
	head.text = "經典遊戲"
	head.add_theme_font_size_override("font_size", 34)
	col.add_child(head)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 16)
	col.add_child(grid)

	_game_card(grid, "數獨", "4 種難度・筆記・提示", true)
	_game_card(grid, "五子棋", "即將推出", false)
	_game_card(grid, "黑白棋", "即將推出", false)
	_game_card(grid, "踩地雷", "即將推出", false)


func _game_card(grid: GridContainer, game_name: String, desc_text: String, available: bool) -> void:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 10)
	margin.add_child(inner)

	var head := Label.new()
	head.text = game_name
	head.add_theme_font_size_override("font_size", 32)
	inner.add_child(head)

	var desc := Label.new()
	desc.text = desc_text
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	inner.add_child(desc)

	var btn := Button.new()
	if available:
		btn.text = "開始"
		btn.pressed.connect(_pick_sudoku_difficulty)
	else:
		btn.text = "敬請期待"
		btn.disabled = true
	inner.add_child(btn)


func _pick_sudoku_difficulty() -> void:
	var buttons: Array = []
	for d in SudokuLogic.Difficulty.values():
		buttons.append({
			"text": "%s %s" % [SudokuLogic.DIFFICULTY_TEXT[d], SudokuLogic.DIFFICULTY_STARS[d]],
			"action": _start_sudoku.bind(d),
		})
	buttons.append({"text": "取消", "secondary": true})
	OverlayDialog.open(self, "選擇難度", "", buttons)


func _start_sudoku(difficulty: int) -> void:
	Main.instance.open_sudoku({"mode": "normal", "difficulty": difficulty})


func _build_stats(col: VBoxContainer) -> void:
	var s := SaveManager.sudoku_stats()
	var played := int(s.get("played", 0))
	if played == 0:
		return
	var inner := _card(col)
	var head := Label.new()
	head.text = "數獨戰績"
	head.add_theme_font_size_override("font_size", 34)
	inner.add_child(head)

	var text := "完成 %d / %d 局" % [int(s.get("won", 0)), played]
	for d in SudokuLogic.Difficulty.values():
		var best := int(s.get("best_%d" % d, 0))
		if best > 0:
			text += "\n%s 最佳：%s" % [SudokuLogic.DIFFICULTY_TEXT[d], SudokuScreen.format_time(best)]
	var body := Label.new()
	body.text = text
	body.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	inner.add_child(body)


## 建立一張卡片並回傳其內容容器
func _card(col: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	col.add_child(panel)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	panel.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)
	return inner
