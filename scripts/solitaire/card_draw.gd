class_name CardDraw
extends RefCounted
## 撲克牌繪製共用模組：牌面、牌背、空位、選取框與向量花色。
## 接龍（Klondike）與新接龍（FreeCell）共用，之後的牌類遊戲也從這裡取用。

const CARD_RED := Color("#c94b48")
const CARD_BLACK := Color("#2b2b33")
const CARD_FACE := Color("#fdfdfa")
const CARD_BORDER := Color("#b9bdc9")
const CARD_BACK := Color("#4a63c8")
const CARD_BACK_INNER := Color("#3a4fa3")
const SLOT_OUTLINE := Color("#b5ab97")


static func slot(ci: Control, rect: Rect2) -> void:
	ci.draw_rect(rect, Color(0, 0, 0, 0.12))
	ci.draw_rect(rect, SLOT_OUTLINE, false, 2.0)


## 暫存格（FreeCell）專用空格樣式：用醒目的主題色標示，
## 提醒玩家這是可以暫時停放任意一張牌的地方（新手常常沒發現而誤以為卡死）
static func free_cell_slot(ci: Control, rect: Rect2) -> void:
	ci.draw_rect(rect, AppTheme.ACCENT.lightened(0.7))
	ci.draw_rect(rect, AppTheme.ACCENT, false, 3.0)
	var s := minf(rect.size.x, rect.size.y) * 0.16
	var c := rect.get_center()
	# 加號圖示：暗示「可暫放一張牌」
	ci.draw_rect(Rect2(c.x - s * 0.5, c.y - s * 0.12, s, s * 0.24), AppTheme.ACCENT)
	ci.draw_rect(Rect2(c.x - s * 0.12, c.y - s * 0.5, s * 0.24, s), AppTheme.ACCENT)


static func card_back(ci: Control, rect: Rect2) -> void:
	ci.draw_rect(rect, CARD_BACK)
	ci.draw_rect(rect.grow(-4.0), CARD_BACK_INNER)
	ci.draw_rect(rect, CARD_BORDER, false, 1.0)


static func selection(ci: Control, rect: Rect2) -> void:
	ci.draw_rect(rect.grow(1.0), AppTheme.ACCENT, false, 3.0)


static func card_face(ci: Control, rect: Rect2, card: int) -> void:
	ci.draw_rect(rect, CARD_FACE)
	ci.draw_rect(rect, CARD_BORDER, false, 1.0)
	var color := CARD_RED if SolitaireLogic.is_red(card) else CARD_BLACK
	var font := ci.get_theme_default_font()
	var fs := int(rect.size.x * 0.34)
	# 左上點數
	ci.draw_string(font, rect.position + Vector2(rect.size.x * 0.08, rect.size.x * 0.36),
			SolitaireLogic.RANK_TEXT[SolitaireLogic.rank_of(card)],
			HORIZONTAL_ALIGNMENT_LEFT, -1, fs, color)
	# 右上小花色
	suit(ci, rect.position + Vector2(rect.size.x * 0.82, rect.size.x * 0.24),
			rect.size.x * 0.14, SolitaireLogic.suit_of(card), color)
	# 中央大花色
	suit(ci, rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.68),
			rect.size.x * 0.26, SolitaireLogic.suit_of(card), color)


## 向量花色：不依賴字型，所有裝置渲染一致
static func suit(ci: Control, center: Vector2, s: float, suit_id: int, color: Color) -> void:
	match suit_id:
		SolitaireLogic.DIAMOND:
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(0, -s), center + Vector2(s * 0.72, 0),
				center + Vector2(0, s), center + Vector2(-s * 0.72, 0),
			]), color)
		SolitaireLogic.HEART:
			ci.draw_circle(center + Vector2(-s * 0.42, -s * 0.3), s * 0.48, color)
			ci.draw_circle(center + Vector2(s * 0.42, -s * 0.3), s * 0.48, color)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.86, -s * 0.1), center + Vector2(s * 0.86, -s * 0.1),
				center + Vector2(0, s),
			]), color)
		SolitaireLogic.SPADE:
			ci.draw_circle(center + Vector2(-s * 0.4, s * 0.12), s * 0.44, color)
			ci.draw_circle(center + Vector2(s * 0.4, s * 0.12), s * 0.44, color)
			ci.draw_colored_polygon(PackedVector2Array([
				center + Vector2(-s * 0.8, s * 0.05), center + Vector2(s * 0.8, s * 0.05),
				center + Vector2(0, -s),
			]), color)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.12, s * 0.2), Vector2(s * 0.24, s * 0.75)), color)
		_:
			ci.draw_circle(center + Vector2(0, -s * 0.42), s * 0.42, color)
			ci.draw_circle(center + Vector2(-s * 0.46, s * 0.1), s * 0.42, color)
			ci.draw_circle(center + Vector2(s * 0.46, s * 0.1), s * 0.42, color)
			ci.draw_rect(Rect2(center + Vector2(-s * 0.12, s * 0.15), Vector2(s * 0.24, s * 0.8)), color)
