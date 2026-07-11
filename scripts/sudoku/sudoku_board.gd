class_name SudokuBoard
extends Control
## 數獨棋盤：單一 Control 直接繪製全部 81 格（含選取、同數字、錯誤高亮與筆記），
## 並以點擊位置換算格子索引。不持有遊戲規則，只負責顯示與點擊回報。

signal cell_pressed(index: int)

var values: Array[int] = []   # 目前盤面（0 = 空）
var given: Array[bool] = []   # 題目原有的提示格
var errors: Array[bool] = []  # 填錯的格子
var notes: Array[int] = []    # 筆記位元遮罩（bit 0 = 數字 1）
var selected := -1


func _init() -> void:
	values.resize(81)
	given.resize(81)
	errors.resize(81)
	notes.resize(81)
	custom_minimum_size = Vector2(300, 300)


func set_selected(i: int) -> void:
	selected = i
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var i := _cell_at(event.position)
		if i >= 0:
			cell_pressed.emit(i)


func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2(Vector2((size.x - side) * 0.5, (size.y - side) * 0.5), Vector2(side, side))


func _cell_at(pos: Vector2) -> int:
	var r := _board_rect()
	if not r.has_point(pos):
		return -1
	var s := r.size.x / 9.0
	var cx := clampi(int((pos.x - r.position.x) / s), 0, 8)
	var cy := clampi(int((pos.y - r.position.y) / s), 0, 8)
	return cy * 9 + cx


func _draw() -> void:
	var r := _board_rect()
	var s := r.size.x / 9.0
	draw_rect(r, AppTheme.CELL_BG)

	var sel_val := values[selected] if selected >= 0 else 0
	for i in 81:
		var rect := Rect2(r.position + Vector2((i % 9) * s, (i / 9) * s), Vector2(s, s))
		# 底色
		var bg := AppTheme.CELL_BG
		if i == selected:
			bg = AppTheme.CELL_SELECTED
		elif errors[i]:
			bg = AppTheme.CELL_ERROR_BG
		elif sel_val != 0 and values[i] == sel_val:
			bg = AppTheme.CELL_SAME
		elif selected >= 0 and _is_peer(i, selected):
			bg = AppTheme.CELL_PEER
		if bg != AppTheme.CELL_BG:
			draw_rect(rect, bg)
		# 內容
		if values[i] != 0:
			var color := AppTheme.DIGIT_GIVEN
			if errors[i]:
				color = AppTheme.DIGIT_ERROR
			elif not given[i]:
				color = AppTheme.DIGIT_USER
			_draw_centered(str(values[i]), rect, s * 0.55, color)
		elif notes[i] != 0:
			for d in range(1, 10):
				if (notes[i] & (1 << (d - 1))) != 0:
					var sub := Rect2(
						rect.position + Vector2(((d - 1) % 3) * s / 3.0, ((d - 1) / 3) * s / 3.0),
						Vector2(s / 3.0, s / 3.0)
					)
					_draw_centered(str(d), sub, s * 0.24, AppTheme.NOTE)

	# 格線（3 的倍數為粗線）
	for k in 10:
		var bold := k % 3 == 0
		var w := 3.0 if bold else 1.0
		var color := AppTheme.GRID_LINE_BOLD if bold else AppTheme.GRID_LINE
		var x := r.position.x + k * s
		draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y), color, w)
		var y := r.position.y + k * s
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y), color, w)


func _is_peer(i: int, j: int) -> bool:
	return i / 9 == j / 9 or i % 9 == j % 9 or SudokuLogic.box_of(i) == SudokuLogic.box_of(j)


func _draw_centered(text: String, rect: Rect2, font_size: float, color: Color) -> void:
	var font := get_theme_default_font()
	var fs := int(font_size)
	var y := rect.position.y + (rect.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
	draw_string(font, Vector2(rect.position.x, y), text, HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, color)
