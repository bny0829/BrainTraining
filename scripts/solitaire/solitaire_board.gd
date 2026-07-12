class_name SolitaireBoard
extends Control
## 接龍牌桌：單一 Control 繪製全部牌堆（庫存、廢牌、基礎堆、七列牌桌），
## 花色以向量圖形繪製（不依賴字型符號，任何裝置都一致）。
## 點擊回報語意目標（zone + 堆索引 + 牌索引），規則判斷交給畫面層。

signal target_tapped(zone: String, pile: int, index: int)

const CARD_RED := Color("#c94b48")
const CARD_BLACK := Color("#2b2b33")
const CARD_FACE := Color("#fdfdfa")
const CARD_BORDER := Color("#b9bdc9")
const CARD_BACK := Color("#4a63c8")
const CARD_BACK_INNER := Color("#3a4fa3")
const SLOT_OUTLINE := Color("#b5ab97")
const TABLE_BG := Color("#3f8f5f")

# 由 state 直接讀取（畫面層持有並修改）
var stock: Array[int] = []
var waste: Array[int] = []
var foundations: Array = [[], [], [], []]
var columns: Array = [[], [], [], [], [], [], []]
var face_up: Array[int] = [1, 1, 1, 1, 1, 1, 1]

# 選取狀態（兩段式移動：先選牌、再點目的地）
var selected_zone := ""   # "" = 無選取；"waste" 或 "column"
var selected_pile := -1
var selected_index := -1


func _init() -> void:
	custom_minimum_size = Vector2(300, 400)


func set_selected(zone: String, pile: int, index: int) -> void:
	selected_zone = zone
	selected_pile = pile
	selected_index = index
	queue_redraw()


func clear_selected() -> void:
	set_selected("", -1, -1)


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		queue_redraw()


# ---- 版面計算 ----

func _card_w() -> float:
	return size.x / (SolitaireLogic.COLUMNS + 0.6)


func _gap() -> float:
	return (size.x - _card_w() * SolitaireLogic.COLUMNS) / (SolitaireLogic.COLUMNS + 1)


func _card_h() -> float:
	return _card_w() * 1.4


func _slot_rect(col: int, row: int) -> Rect2:
	var w := _card_w()
	return Rect2(
		Vector2(_gap() + col * (w + _gap()), 8.0 + row * (_card_h() + 20.0)),
		Vector2(w, _card_h())
	)


## 牌桌第 col 列第 i 張牌的矩形
func _column_card_rect(col: int, i: int) -> Rect2:
	var base := _slot_rect(col, 1)
	var down_n: int = (columns[col] as Array).size() - face_up[col]
	var y := base.position.y
	for k in i:
		y += _card_h() * (0.16 if k < down_n else 0.3)
	return Rect2(Vector2(base.position.x, y), base.size)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	# 上排：庫存(0)、廢牌(1)、基礎堆(3~6)
	if _slot_rect(0, 0).has_point(pos):
		target_tapped.emit("stock", 0, 0)
		return
	if _slot_rect(1, 0).has_point(pos):
		target_tapped.emit("waste", 0, 0)
		return
	for f in 4:
		if _slot_rect(3 + f, 0).has_point(pos):
			target_tapped.emit("foundation", f, 0)
			return
	# 牌桌：由最上層（陣列尾端）往回找第一張包含點擊位置的牌
	for c in SolitaireLogic.COLUMNS:
		var col: Array = columns[c]
		if col.is_empty():
			if _slot_rect(c, 1).has_point(pos):
				target_tapped.emit("column", c, -1)
				return
			continue
		for i in range(col.size() - 1, -1, -1):
			if _column_card_rect(c, i).has_point(pos):
				target_tapped.emit("column", c, i)
				return


# ---- 繪製 ----

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TABLE_BG)

	# 庫存
	var stock_rect := _slot_rect(0, 0)
	if stock.is_empty():
		_draw_slot(stock_rect)
	else:
		_draw_card_back(stock_rect)
	# 廢牌（只畫最上面一張）
	var waste_rect := _slot_rect(1, 0)
	if waste.is_empty():
		_draw_slot(waste_rect)
	else:
		_draw_card_face(waste_rect, waste[-1])
		if selected_zone == "waste":
			_draw_selection(waste_rect)
	# 基礎堆
	for f in 4:
		var rect := _slot_rect(3 + f, 0)
		var pile: Array = foundations[f]
		if pile.is_empty():
			_draw_slot(rect)
		else:
			_draw_card_face(rect, int(pile[-1]))
	# 牌桌
	for c in SolitaireLogic.COLUMNS:
		var col: Array = columns[c]
		if col.is_empty():
			_draw_slot(_slot_rect(c, 1))
			continue
		var down_n: int = col.size() - face_up[c]
		for i in col.size():
			var rect := _column_card_rect(c, i)
			if i < down_n:
				_draw_card_back(rect)
			else:
				_draw_card_face(rect, int(col[i]))
				if selected_zone == "column" and selected_pile == c and i >= selected_index:
					_draw_selection(rect)


## 選取高亮：橘色外框
func _draw_selection(rect: Rect2) -> void:
	draw_rect(rect.grow(1.0), AppTheme.ACCENT, false, 3.0)


func _draw_slot(rect: Rect2) -> void:
	draw_rect(rect, Color(0, 0, 0, 0.12))
	draw_rect(rect, SLOT_OUTLINE, false, 2.0)


func _draw_card_back(rect: Rect2) -> void:
	draw_rect(rect, CARD_BACK)
	draw_rect(rect.grow(-4.0), CARD_BACK_INNER)
	draw_rect(rect, CARD_BORDER, false, 1.0)


func _draw_card_face(rect: Rect2, card: int) -> void:
	draw_rect(rect, CARD_FACE)
	draw_rect(rect, CARD_BORDER, false, 1.0)
	var color := CARD_RED if SolitaireLogic.is_red(card) else CARD_BLACK
	var font := get_theme_default_font()
	var fs := int(rect.size.x * 0.34)
	# 左上點數
	draw_string(font, rect.position + Vector2(rect.size.x * 0.08, rect.size.x * 0.36),
			SolitaireLogic.RANK_TEXT[SolitaireLogic.rank_of(card)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	# 右上小花色
	_draw_suit(rect.position + Vector2(rect.size.x * 0.82, rect.size.x * 0.24),
			rect.size.x * 0.14, SolitaireLogic.suit_of(card), color)
	# 中央大花色
	_draw_suit(rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.68),
			rect.size.x * 0.26, SolitaireLogic.suit_of(card), color)


## 向量花色：不依賴字型，所有裝置渲染一致
func _draw_suit(center: Vector2, s: float, suit: int, color: Color) -> void:
	match suit:
		SolitaireLogic.DIAMOND:
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s * 0.72, 0),
				center + Vector2(0, s), center + Vector2(-s * 0.72, 0),
			]), color)
		SolitaireLogic.HEART:
			draw_circle(center + Vector2(-s * 0.42, -s * 0.3), s * 0.48, color)
			draw_circle(center + Vector2(s * 0.42, -s * 0.3), s * 0.48, color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.86, -s * 0.1), center + Vector2(s * 0.86, -s * 0.1),
				center + Vector2(0, s),
			]), color)
		SolitaireLogic.SPADE:
			draw_circle(center + Vector2(-s * 0.4, s * 0.12), s * 0.44, color)
			draw_circle(center + Vector2(s * 0.4, s * 0.12), s * 0.44, color)
			draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.8, s * 0.05), center + Vector2(s * 0.8, s * 0.05),
				center + Vector2(0, -s),
			]), color)
			draw_rect(Rect2(center + Vector2(-s * 0.12, s * 0.2), Vector2(s * 0.24, s * 0.75)), color)
		_:
			draw_circle(center + Vector2(0, -s * 0.42), s * 0.42, color)
			draw_circle(center + Vector2(-s * 0.46, s * 0.1), s * 0.42, color)
			draw_circle(center + Vector2(s * 0.46, s * 0.1), s * 0.42, color)
			draw_rect(Rect2(center + Vector2(-s * 0.12, s * 0.15), Vector2(s * 0.24, s * 0.8)), color)
