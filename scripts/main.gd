class_name Main
extends Control
## 主畫面：負責套用全域主題與畫面切換（首頁 ⇄ 各遊戲）。
## 所有畫面切換都透過 Main.instance，未來新增遊戲時在這裡加一個 open_xxx() 即可。

static var instance: Main

var _current: Control = null


func _enter_tree() -> void:
	instance = self


func _ready() -> void:
	theme = AppTheme.build()
	var bg := ColorRect.new()
	bg.color = AppTheme.BG
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	goto_home()
	# 自動化測試掛勾：BRAINCLUB_AUTOTEST=1 時載入測試腳本
	if OS.get_environment("BRAINCLUB_AUTOTEST") == "1":
		var script: GDScript = load("res://tests/autotest.gd")
		add_child(script.new())


func current_screen() -> Control:
	return _current


func goto_home() -> void:
	_switch(HomeScreen.new())


func open_sudoku(config: Dictionary) -> void:
	var screen := SudokuScreen.new()
	screen.config = config
	_switch(screen)


func _switch(screen: Control) -> void:
	if _current != null:
		_current.queue_free()
	_current = screen
	screen.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(screen)
