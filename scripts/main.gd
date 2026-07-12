class_name Main
extends Control
## 主畫面：負責套用全域主題與畫面切換（首頁 ⇄ 各遊戲）。
## 所有畫面切換都透過 Main.instance，未來新增遊戲時在這裡加一個 open_xxx() 即可。

static var instance: Main

var _current: Control = null
var _screen_root: MarginContainer


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	theme = AppTheme.build()
	var bg := ColorRect.new()
	bg.color = AppTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	# 所有畫面放在安全區域容器內，避開手機的挖孔鏡頭與系統列
	_screen_root = MarginContainer.new()
	_screen_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_screen_root)
	get_viewport().size_changed.connect(_apply_safe_area)
	_apply_safe_area()
	# 全域按鈕音效：之後進場景樹的每顆按鈕都自動掛上
	get_tree().node_added.connect(_on_node_added)
	goto_home()
	# 自動化測試掛勾：BRAINCLUB_AUTOTEST=1 時載入測試腳本
	if OS.get_environment("BRAINCLUB_AUTOTEST") == "1":
		var script: GDScript = load("res://tests/autotest.gd")
		add_child(script.new())


## 依裝置回報的安全顯示區域（挖孔、瀏海、系統手勢列）設定畫面內縮。
## 桌面視窗的安全區域 = 整個視窗，內縮為 0，不影響開發時的畫面。
func _apply_safe_area() -> void:
	var safe := DisplayServer.get_display_safe_area()
	var win := DisplayServer.window_get_size()
	if win.x <= 0 or win.y <= 0:
		return
	# 安全區域是實體像素，要換算成畫布（canvas_items 縮放後）座標
	var canvas := get_viewport_rect().size
	var sx := canvas.x / float(win.x)
	var sy := canvas.y / float(win.y)
	var top := maxf(0.0, safe.position.y * sy)
	var left := maxf(0.0, safe.position.x * sx)
	var right := maxf(0.0, (win.x - safe.position.x - safe.size.x) * sx)
	var bottom := maxf(0.0, (win.y - safe.position.y - safe.size.y) * sy)
	# 開發用：BRAINCLUB_FAKE_SAFE_TOP 可在桌面模擬挖孔高度驗證版面
	var fake := OS.get_environment("BRAINCLUB_FAKE_SAFE_TOP")
	if fake != "":
		top = float(fake)
	_screen_root.add_theme_constant_override("margin_top", int(top))
	_screen_root.add_theme_constant_override("margin_left", int(left))
	_screen_root.add_theme_constant_override("margin_right", int(right))
	_screen_root.add_theme_constant_override("margin_bottom", int(bottom))


func current_screen() -> Control:
	return _current


func goto_home() -> void:
	_switch(HomeScreen.new())


func open_sudoku(config: Dictionary) -> void:
	var screen := SudokuScreen.new()
	screen.config = config
	_switch(screen)


func open_gomoku(config: Dictionary) -> void:
	var screen := GomokuScreen.new()
	screen.config = config
	_switch(screen)


func open_reversi(config: Dictionary) -> void:
	var screen := ReversiScreen.new()
	screen.config = config
	_switch(screen)


func open_minesweeper(config: Dictionary) -> void:
	var screen := MinesweeperScreen.new()
	screen.config = config
	_switch(screen)


func open_achievements() -> void:
	_switch(AchievementScreen.new())


func open_settings() -> void:
	_switch(SettingsScreen.new())


func _on_node_added(node: Node) -> void:
	if node is Button:
		(node as Button).pressed.connect(func() -> void: Sfx.play("tap"))


func _switch(screen: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = screen
	_screen_root.add_child(screen)
	# 淡入轉場
	screen.modulate.a = 0.0
	screen.create_tween().tween_property(screen, "modulate:a", 1.0, 0.15)
