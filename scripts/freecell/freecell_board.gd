class_name FreecellBoard
extends Control
## 新接龍牌桌：上排 4 個自由格 + 4 個基礎堆，下方 8 列牌疊（全明牌）。
## 繪製共用 CardDraw；點擊回報語意目標，規則判斷交給畫面層。

signal target_tapped(zone: String, pile: int, index: int)

const TABLE_BG := Color("#3f6f8f")

var cascades: Array = [[], [], [], [], [], [], [], []]
var free: Array[int] = [-1, -1, -1, -1]
var foundations: Array = [[], [], [], []]

var selected_zone := ""   # ""、"cascade"、"free"
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
	return size.x / (FreecellLogic.CASCADES + 0.7)


func _gap() -> float:
	return (size.x - _card_w() * FreecellLogic.CASCADES) / (FreecellLogic.CASCADES + 1)


func _card_h() -> float:
	return _card_w() * 1.4


func _slot_rect(col: int, row: int) -> Rect2:
	var w := _card_w()
	return Rect2(
		Vector2(_gap() + col * (w + _gap()), 8.0 + row * (_card_h() + 20.0)),
		Vector2(w, _card_h())
	)


func _cascade_card_rect(col: int, i: int) -> Rect2:
	var base := _slot_rect(col, 1)
	return Rect2(base.position + Vector2(0, i * _card_h() * 0.3), base.size)


func _gui_input(event: InputEvent) -> void:
	if not (event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var pos: Vector2 = event.position
	# 上排：自由格 0~3、基礎堆 4~7
	for k in 4:
		if _slot_rect(k, 0).has_point(pos):
			target_tapped.emit("free", k, 0)
			return
		if _slot_rect(4 + k, 0).has_point(pos):
			target_tapped.emit("foundation", k, 0)
			return
	# 牌疊：由頂往下找第一張包含點擊位置的牌
	for c in FreecellLogic.CASCADES:
		var col: Array = cascades[c]
		if col.is_empty():
			if _slot_rect(c, 1).has_point(pos):
				target_tapped.emit("cascade", c, -1)
				return
			continue
		for i in range(col.size() - 1, -1, -1):
			if _cascade_card_rect(c, i).has_point(pos):
				target_tapped.emit("cascade", c, i)
				return


# ---- 繪製 ----

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), TABLE_BG)

	# 自由格（暫存格）：空格用醒目樣式標示，提醒玩家可暫放任意一張牌
	for k in 4:
		var rect := _slot_rect(k, 0)
		if free[k] < 0:
			CardDraw.free_cell_slot(self, rect)
		else:
			CardDraw.card_face(self, rect, free[k])
			if selected_zone == "free" and selected_pile == k:
				CardDraw.selection(self, rect)
	# 基礎堆
	for k in 4:
		var rect := _slot_rect(4 + k, 0)
		var pile: Array = foundations[k]
		if pile.is_empty():
			CardDraw.slot(self, rect)
		else:
			CardDraw.card_face(self, rect, int(pile[-1]))
	# 牌疊
	for c in FreecellLogic.CASCADES:
		var col: Array = cascades[c]
		if col.is_empty():
			CardDraw.slot(self, _slot_rect(c, 1))
			continue
		for i in col.size():
			var rect := _cascade_card_rect(c, i)
			CardDraw.card_face(self, rect, int(col[i]))
			if selected_zone == "cascade" and selected_pile == c and i >= selected_index:
				CardDraw.selection(self, rect)
