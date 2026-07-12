class_name MinesweeperBoard
extends Control
## 踩地雷棋盤：單一 Control 繪製全部格子（未開/旗標/數字/地雷），
## 支援點擊與長按（長按 = 插旗，手機常用操作）。不持有遊戲規則。

signal cell_tapped(index: int)
signal cell_long_pressed(index: int)

const LONG_PRESS_SEC := 0.4

var w := 9
var h := 9
var mines: Array[bool] = []
var counts: Array[int] = []
var revealed: Array[bool] = []
var flagged: Array[bool] = []
var exploded := -1        # 踩到的那顆雷
var show_mines := false   # 結束時全部攤開

var _press_index := -1
var _press_timer: SceneTreeTimer = null
var _long_fired := false


func _init() -> void:
	custom_minimum_size = Vector2(300, 300)


func setup(width: int, height: int) -> void:
	w = width
	h = height
	var cells := w * h
	mines.resize(cells)
	mines.fill(false)
	counts.resize(cells)
	counts.fill(0)
	revealed.resize(cells)
	revealed.fill(false)
	flagged.resize(cells)
	flagged.fill(false)
	exploded = -1
	show_mines = false
	queue_redraw()


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_index = _cell_at(event.position)
			_long_fired = false
			if _press_index >= 0:
				_press_timer = get_tree().create_timer(LONG_PRESS_SEC)
				_press_timer.timeout.connect(_on_long_press.bind(_press_index, _press_timer))
		else:
			var i := _cell_at(event.position)
			_press_timer = null
			if not _long_fired and i >= 0 and i == _press_index:
				cell_tapped.emit(i)
			_press_index = -1


func _on_long_press(index: int, timer: SceneTreeTimer) -> void:
	# 只有仍按著同一格、且計時器沒被放開取消時才算長按
	if timer == _press_timer and _press_index == index:
		_long_fired = true
		cell_long_pressed.emit(index)


func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2(Vector2((size.x - side) * 0.5, (size.y - side) * 0.5), Vector2(side, side))


func _cell_at(pos: Vector2) -> int:
	var r := _board_rect()
	if not r.has_point(pos):
		return -1
	var s := r.size.x / w
	var cx := clampi(int((pos.x - r.position.x) / s), 0, w - 1)
	var cy := clampi(int((pos.y - r.position.y) / s), 0, h - 1)
	return cy * w + cx


func _draw() -> void:
	var r := _board_rect()
	var s := r.size.x / w
	draw_rect(r, AppTheme.MINE_REVEALED)

	var font := get_theme_default_font()
	var fs := int(s * 0.55)
	for i in w * h:
		var rect := Rect2(r.position + Vector2((i % w) * s, (i / w) * s), Vector2(s, s))
		var is_mine_visible: bool = show_mines and mines[i]
		if revealed[i] or is_mine_visible:
			# 已翻開（或攤牌的地雷）
			if i == exploded:
				draw_rect(rect, AppTheme.MINE_EXPLODED)
			if is_mine_visible:
				draw_circle(rect.get_center(), s * 0.28, AppTheme.MINE_BOMB)
			elif counts[i] > 0:
				var color: Color = AppTheme.MINE_NUMBERS[counts[i]]
				var y := rect.position.y + (rect.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
				draw_string(font, Vector2(rect.position.x, y), str(counts[i]),
						HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, color)
		else:
			# 未翻開：立體感磚塊
			draw_rect(rect.grow(-1.0), AppTheme.MINE_COVERED)
			draw_rect(Rect2(rect.position + Vector2(1, 1), Vector2(rect.size.x - 2, 3)), AppTheme.MINE_COVERED.lightened(0.18))
			draw_rect(Rect2(rect.position + Vector2(1, rect.size.y - 4), Vector2(rect.size.x - 2, 3)), AppTheme.MINE_COVERED_EDGE)
			if flagged[i]:
				_draw_flag(rect, s)

	# 格線
	var lw := maxf(1.5, s * 0.03)
	for k in w + 1:
		var x := r.position.x + k * s
		draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y), AppTheme.MINE_LINE, lw, true)
	for k in h + 1:
		var y := r.position.y + k * s
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y), AppTheme.MINE_LINE, lw, true)


func _draw_flag(rect: Rect2, s: float) -> void:
	var base := rect.position + Vector2(s * 0.32, s * 0.22)
	# 旗桿
	draw_line(base, base + Vector2(0, s * 0.55), AppTheme.MINE_BOMB, maxf(2.0, s * 0.06), true)
	# 旗面（三角形）
	var pts := PackedVector2Array([
		base,
		base + Vector2(s * 0.4, s * 0.14),
		base + Vector2(0, s * 0.28),
	])
	draw_colored_polygon(pts, AppTheme.MINE_FLAG)
