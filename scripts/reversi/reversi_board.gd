class_name ReversiBoard
extends Control
## 黑白棋棋盤：單一 Control 繪製 8×8 綠底格子、棋子、合法手提示點與最後一手標記。
## 不持有遊戲規則，只負責顯示與點擊回報。

signal cell_pressed(index: int)

var stones: Array[int] = []      # 64，0 = 空、1 = 黑、2 = 白
var hints: Array[int] = []       # 目前玩家的合法手（顯示提示點）
var last_move := -1


func _init() -> void:
	stones.resize(ReversiLogic.CELLS)
	custom_minimum_size = Vector2(300, 300)


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
	var s := r.size.x / ReversiLogic.SIZE
	var cx := clampi(int((pos.x - r.position.x) / s), 0, ReversiLogic.SIZE - 1)
	var cy := clampi(int((pos.y - r.position.y) / s), 0, ReversiLogic.SIZE - 1)
	return cy * ReversiLogic.SIZE + cx


func _center_of(i: int) -> Vector2:
	var r := _board_rect()
	var s := r.size.x / ReversiLogic.SIZE
	return r.position + Vector2((i % ReversiLogic.SIZE + 0.5) * s, (i / ReversiLogic.SIZE + 0.5) * s)


func _draw() -> void:
	var r := _board_rect()
	var n := ReversiLogic.SIZE
	var s := r.size.x / n
	draw_rect(r, AppTheme.REVERSI_BOARD)

	# 格線（線寬隨格子縮放並開抗鋸齒，避免縮放時消失）
	var lw := maxf(2.0, s * 0.03)
	for k in n + 1:
		var x := r.position.x + k * s
		draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y), AppTheme.REVERSI_LINE, lw, true)
		var y := r.position.y + k * s
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y), AppTheme.REVERSI_LINE, lw, true)

	# 棋子與提示
	var radius := s * 0.4
	for i in ReversiLogic.CELLS:
		var c := _center_of(i)
		if stones[i] == ReversiLogic.BLACK:
			draw_circle(c, radius, AppTheme.STONE_BLACK)
		elif stones[i] == ReversiLogic.WHITE:
			draw_circle(c, radius, AppTheme.STONE_WHITE)
			draw_arc(c, radius, 0.0, TAU, 40, AppTheme.STONE_WHITE_EDGE, 1.5, true)
		elif hints.has(i):
			draw_circle(c, s * 0.12, AppTheme.REVERSI_HINT)

	# 最後一手標記
	if last_move >= 0 and stones[last_move] != ReversiLogic.EMPTY:
		draw_circle(_center_of(last_move), s * 0.1, AppTheme.ACCENT)
