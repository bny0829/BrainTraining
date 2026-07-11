class_name GomokuBoard
extends Control
## 五子棋棋盤：單一 Control 繪製 15 路棋盤、棋子與最後一手標記。
## 不持有遊戲規則，只負責顯示與點擊回報（回報最近的交叉點索引）。

signal cell_pressed(index: int)

var stones: Array[int] = []  # 225，0 = 空、1 = 黑、2 = 白
var last_move := -1


func _init() -> void:
	stones.resize(GomokuLogic.CELLS)
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
	var s := r.size.x / GomokuLogic.SIZE
	var cx := clampi(int((pos.x - r.position.x) / s), 0, GomokuLogic.SIZE - 1)
	var cy := clampi(int((pos.y - r.position.y) / s), 0, GomokuLogic.SIZE - 1)
	return cy * GomokuLogic.SIZE + cx


## 交叉點中心座標
func _center_of(i: int) -> Vector2:
	var r := _board_rect()
	var s := r.size.x / GomokuLogic.SIZE
	return r.position + Vector2((i % GomokuLogic.SIZE + 0.5) * s, (i / GomokuLogic.SIZE + 0.5) * s)


func _draw() -> void:
	var r := _board_rect()
	var n := GomokuLogic.SIZE
	var s := r.size.x / n
	draw_rect(r, AppTheme.GOMOKU_BOARD)

	# 15 路格線：延伸到棋盤邊緣，讓每個可落子點（含最外圈）都是完整十字，
	# 玩家一眼就能看出全部交叉點都能下。
	# 線寬必須隨格子大小縮放並開抗鋸齒：視窗縮小時固定 1px 的線會因不足
	# 一個實體像素而不規則消失（畫面上只剩幾條線）。
	var margin := s * 0.5
	var lw := maxf(2.0, s * 0.045)
	for k in n:
		var x := r.position.x + margin + k * s
		draw_line(Vector2(x, r.position.y), Vector2(x, r.position.y + r.size.y), AppTheme.GOMOKU_LINE, lw, true)
		var y := r.position.y + margin + k * s
		draw_line(Vector2(r.position.x, y), Vector2(r.position.x + r.size.x, y), AppTheme.GOMOKU_LINE, lw, true)

	# 星位
	for p in [[3, 3], [3, 11], [11, 3], [11, 11], [7, 7]]:
		draw_circle(_center_of(GomokuLogic.idx(p[0], p[1])), s * 0.09, AppTheme.GOMOKU_LINE)

	# 棋子
	var radius := s * 0.42
	for i in GomokuLogic.CELLS:
		if stones[i] == GomokuLogic.EMPTY:
			continue
		var c := _center_of(i)
		if stones[i] == GomokuLogic.BLACK:
			draw_circle(c, radius, AppTheme.STONE_BLACK)
		else:
			draw_circle(c, radius, AppTheme.STONE_WHITE)
			draw_arc(c, radius, 0.0, TAU, 40, AppTheme.STONE_WHITE_EDGE, 1.5, true)

	# 最後一手標記
	if last_move >= 0 and stones[last_move] != GomokuLogic.EMPTY:
		draw_circle(_center_of(last_move), s * 0.12, AppTheme.ACCENT)
