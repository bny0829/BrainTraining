class_name Game2048Board
extends Control
## 2048 棋盤：單一 Control 繪製 4×4 圓角磚塊，並偵測滑動手勢。
## 不持有遊戲規則，只負責顯示與手勢回報。

signal swiped(dir: int)

const SWIPE_MIN_PX := 40.0

var grid: Array[int] = []

var _press_pos := Vector2.ZERO
var _tracking := false
var _box_cache: Dictionary = {}


func _init() -> void:
	grid = Game2048Logic.new_grid()
	custom_minimum_size = Vector2(300, 300)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			_press_pos = event.position
			_tracking = true
		elif _tracking:
			_tracking = false
			var d: Vector2 = event.position - _press_pos
			if d.length() >= SWIPE_MIN_PX:
				if absf(d.x) > absf(d.y):
					swiped.emit(Game2048Logic.DIR_RIGHT if d.x > 0 else Game2048Logic.DIR_LEFT)
				else:
					swiped.emit(Game2048Logic.DIR_DOWN if d.y > 0 else Game2048Logic.DIR_UP)


func _board_rect() -> Rect2:
	var side := minf(size.x, size.y)
	return Rect2(Vector2((size.x - side) * 0.5, (size.y - side) * 0.5), Vector2(side, side))


func _draw() -> void:
	var r := _board_rect()
	var n := Game2048Logic.SIZE
	var gap := r.size.x * 0.025
	var s := (r.size.x - gap * (n + 1)) / n

	_box(AppTheme.T2048_BOARD, 12).draw(get_canvas_item(), r)

	var font := get_theme_default_font()
	for i in Game2048Logic.CELLS:
		var pos := r.position + Vector2(
			gap + (i % n) * (s + gap),
			gap + (i / n) * (s + gap)
		)
		var rect := Rect2(pos, Vector2(s, s))
		var v := grid[i]
		if v == 0:
			_box(AppTheme.T2048_SLOT, 8).draw(get_canvas_item(), rect)
			continue
		var tile_color: Color = AppTheme.T2048_TILES.get(v, AppTheme.T2048_SUPER)
		_box(tile_color, 8).draw(get_canvas_item(), rect)
		var text := str(v)
		var fs := int(s * clampf(0.5 - 0.08 * (text.length() - 2), 0.24, 0.5))
		var text_color: Color = AppTheme.T2048_TEXT_DARK if v <= 4 else Color.WHITE
		var y := rect.position.y + (rect.size.y - font.get_height(fs)) * 0.5 + font.get_ascent(fs)
		draw_string(font, Vector2(rect.position.x, y), text,
				HORIZONTAL_ALIGNMENT_CENTER, rect.size.x, fs, text_color)


func _box(c: Color, radius: int) -> StyleBoxFlat:
	var key := "%s_%d" % [c.to_html(), radius]
	if not _box_cache.has(key):
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(radius)
		_box_cache[key] = sb
	return _box_cache[key]
