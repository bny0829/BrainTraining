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


const GAME_NAMES := {
	"sudoku": "數獨", "gomoku": "五子棋", "reversi": "黑白棋",
	"minesweeper": "踩地雷", "game2048": "2048",
}


func _difficulty_label(game: String, d: int) -> String:
	match game:
		"sudoku":
			return "%s %s" % [SudokuLogic.DIFFICULTY_TEXT[d], SudokuLogic.DIFFICULTY_STARS[d]]
		"gomoku":
			return "%s %s" % [GomokuLogic.DIFFICULTY_TEXT[d], GomokuLogic.DIFFICULTY_STARS[d]]
		"minesweeper":
			return "%s %s" % [MinesweeperLogic.DIFFICULTY_TEXT[d], MinesweeperLogic.DIFFICULTY_STARS[d]]
		_:
			return "%s %s" % [ReversiLogic.DIFFICULTY_TEXT[d], ReversiLogic.DIFFICULTY_STARS[d]]


func _build_header(col: VBoxContainer) -> void:
	var row := HBoxContainer.new()
	col.add_child(row)
	var title := Label.new()
	title.text = "Brain Club"
	title.add_theme_font_size_override("font_size", 52)
	title.add_theme_color_override("font_color", AppTheme.PRIMARY_DARK)
	row.add_child(title)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)
	var ach := Button.new()
	ach.text = "成就 %d/%d" % [Achievements.unlocked_count(), Achievements.total_count()]
	AppTheme.style_secondary(ach)
	ach.pressed.connect(func() -> void: Main.instance.open_achievements())
	row.add_child(ach)
	var settings := Button.new()
	settings.text = "設定"
	AppTheme.style_secondary(settings)
	settings.pressed.connect(func() -> void: Main.instance.open_settings())
	row.add_child(settings)

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

	var ch := Daily.today_challenge()
	var desc := Label.new()
	desc.text = "%s　%s・%s" % [
		Daily.today_id(),
		GAME_NAMES[String(ch["game"])],
		_difficulty_label(String(ch["game"]), int(ch["difficulty"])),
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
		btn.pressed.connect(_start_daily)
		inner.add_child(btn)


func _start_daily() -> void:
	var ch := Daily.today_challenge()
	var cfg := {"mode": "daily", "difficulty": int(ch["difficulty"])}
	match String(ch["game"]):
		"sudoku":
			cfg["seed"] = int(ch["seed"])
			Main.instance.open_sudoku(cfg)
		"gomoku":
			Main.instance.open_gomoku(cfg)
		"minesweeper":
			cfg["seed"] = int(ch["seed"])
			Main.instance.open_minesweeper(cfg)
		_:
			Main.instance.open_reversi(cfg)


func _build_continue_card(col: VBoxContainer) -> void:
	var st := SaveManager.get_in_progress()
	var game := String(st.get("game", ""))
	if not GAME_NAMES.has(game):
		return
	var inner := _card(col)
	var head := Label.new()
	head.text = "進行中的遊戲"
	head.add_theme_font_size_override("font_size", 34)
	inner.add_child(head)

	var mode_text: String = GAME_NAMES[game]
	if String(st.get("mode", "")) == "daily":
		mode_text = "每日挑戰・" + mode_text
	var detail: String
	match game:
		"sudoku", "minesweeper":
			detail = SudokuScreen.format_time(int(st.get("seconds", 0)))
		"gomoku":
			detail = "第 %d 手" % ((st.get("moves", []) as Array).size() + 1)
		"game2048":
			detail = "分數 %d" % int(st.get("score", 0))
		_:
			var c := ReversiLogic.count(ReversiScreen._to_int_array(st.get("board", [])))
			detail = "黑 %d：%d 白" % [c[0], c[1]]
	var desc := Label.new()
	if game == "game2048":
		# 2048 沒有難度分級
		desc.text = "%s・%s" % [mode_text, detail]
	else:
		desc.text = "%s・%s・%s" % [
			mode_text,
			_difficulty_label(game, int(st.get("difficulty", 0))).split(" ")[0],
			detail,
		]
	desc.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	inner.add_child(desc)

	var btn := Button.new()
	btn.text = "繼續"
	match game:
		"sudoku":
			btn.pressed.connect(func() -> void: Main.instance.open_sudoku({"mode": "resume"}))
		"gomoku":
			btn.pressed.connect(func() -> void: Main.instance.open_gomoku({"mode": "resume"}))
		"minesweeper":
			btn.pressed.connect(func() -> void: Main.instance.open_minesweeper({"mode": "resume"}))
		"game2048":
			btn.pressed.connect(func() -> void: Main.instance.open_game2048({"mode": "resume"}))
		_:
			btn.pressed.connect(func() -> void: Main.instance.open_reversi({"mode": "resume"}))
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

	_game_card(grid, "數獨", "4 種難度・筆記・提示", _pick_sudoku_difficulty)
	_game_card(grid, "五子棋", "AI 對戰・4 級難度", _pick_gomoku_difficulty)
	_game_card(grid, "黑白棋", "AI 對戰・合法手提示", _pick_reversi_difficulty)
	_game_card(grid, "踩地雷", "首挖安全・長按插旗", _pick_minesweeper_difficulty)
	_game_card(grid, "2048", "滑動合併・挑戰高分", _start_2048)
	_game_card(grid, "接龍", "即將推出", Callable())


func _game_card(grid: GridContainer, game_name: String, desc_text: String, on_start: Callable) -> void:
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
	if on_start.is_valid():
		btn.text = "開始"
		btn.pressed.connect(on_start)
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


func _pick_gomoku_difficulty() -> void:
	var buttons: Array = []
	for d in GomokuLogic.Difficulty.values():
		buttons.append({
			"text": "%s %s" % [GomokuLogic.DIFFICULTY_TEXT[d], GomokuLogic.DIFFICULTY_STARS[d]],
			"action": _start_gomoku.bind(d),
		})
	buttons.append({"text": "取消", "secondary": true})
	OverlayDialog.open(self, "選擇 AI 難度", "你執黑棋先手", buttons)


func _start_gomoku(difficulty: int) -> void:
	Main.instance.open_gomoku({"mode": "normal", "difficulty": difficulty})


func _pick_reversi_difficulty() -> void:
	var buttons: Array = []
	for d in ReversiLogic.Difficulty.values():
		buttons.append({
			"text": "%s %s" % [ReversiLogic.DIFFICULTY_TEXT[d], ReversiLogic.DIFFICULTY_STARS[d]],
			"action": _start_reversi.bind(d),
		})
	buttons.append({"text": "取消", "secondary": true})
	OverlayDialog.open(self, "選擇 AI 難度", "你執黑棋先手", buttons)


func _start_reversi(difficulty: int) -> void:
	Main.instance.open_reversi({"mode": "normal", "difficulty": difficulty})


func _pick_minesweeper_difficulty() -> void:
	var buttons: Array = []
	for d in MinesweeperLogic.Difficulty.values():
		var cfg: Dictionary = MinesweeperLogic.CONFIG[d]
		buttons.append({
			"text": "%s %s（%d×%d・%d 雷）" % [
				MinesweeperLogic.DIFFICULTY_TEXT[d], MinesweeperLogic.DIFFICULTY_STARS[d],
				int(cfg["w"]), int(cfg["h"]), int(cfg["mines"]),
			],
			"action": _start_minesweeper.bind(d),
		})
	buttons.append({"text": "取消", "secondary": true})
	OverlayDialog.open(self, "選擇難度", "", buttons)


func _start_minesweeper(difficulty: int) -> void:
	Main.instance.open_minesweeper({"mode": "normal", "difficulty": difficulty})


func _start_2048() -> void:
	Main.instance.open_game2048({"mode": "normal"})


func _build_stats(col: VBoxContainer) -> void:
	var s := SaveManager.sudoku_stats()
	var played := int(s.get("played", 0))
	if played > 0:
		var text := "完成 %d / %d 局" % [int(s.get("won", 0)), played]
		for d in SudokuLogic.Difficulty.values():
			var best := int(s.get("best_%d" % d, 0))
			if best > 0:
				text += "\n%s 最佳：%s" % [SudokuLogic.DIFFICULTY_TEXT[d], SudokuScreen.format_time(best)]
		_stats_card(col, "數獨戰績", text)

	var g := SaveManager.stats("gomoku")
	var g_played := int(g.get("played", 0))
	if g_played > 0:
		var text := "勝 %d / %d 局" % [int(g.get("won", 0)), g_played]
		for d in GomokuLogic.Difficulty.values():
			var wins := int(g.get("won_%d" % d, 0))
			if wins > 0:
				text += "\n%s 勝場：%d" % [GomokuLogic.DIFFICULTY_TEXT[d], wins]
		_stats_card(col, "五子棋戰績", text)

	var r := SaveManager.stats("reversi")
	var r_played := int(r.get("played", 0))
	if r_played > 0:
		var text := "勝 %d / %d 局" % [int(r.get("won", 0)), r_played]
		for d in ReversiLogic.Difficulty.values():
			var wins := int(r.get("won_%d" % d, 0))
			if wins > 0:
				text += "\n%s 勝場：%d" % [ReversiLogic.DIFFICULTY_TEXT[d], wins]
		_stats_card(col, "黑白棋戰績", text)

	var t := SaveManager.stats("game2048")
	if int(t.get("best_score", 0)) > 0:
		var text := "最高分：%d・最大磚塊：%d" % [int(t.get("best_score", 0)), int(t.get("best_tile", 0))]
		if int(t.get("played", 0)) > 0:
			text += "\n完整場數：%d" % int(t.get("played", 0))
		_stats_card(col, "2048 戰績", text)

	var ms := SaveManager.stats("minesweeper")
	var ms_played := int(ms.get("played", 0))
	if ms_played > 0:
		var text := "掃雷成功 %d / %d 局" % [int(ms.get("won", 0)), ms_played]
		for d in MinesweeperLogic.Difficulty.values():
			var wins := int(ms.get("won_%d" % d, 0))
			if wins > 0:
				text += "\n%s 成功：%d" % [MinesweeperLogic.DIFFICULTY_TEXT[d], wins]
		_stats_card(col, "踩地雷戰績", text)


func _stats_card(col: VBoxContainer, title: String, text: String) -> void:
	var inner := _card(col)
	var head := Label.new()
	head.text = title
	head.add_theme_font_size_override("font_size", 34)
	inner.add_child(head)
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
