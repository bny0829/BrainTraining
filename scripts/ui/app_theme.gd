class_name AppTheme
extends RefCounted
## 全 App 共用的色票與 Theme 產生器。
## 平台原則：所有遊戲共用同一套 UI 風格，只從這裡取顏色與樣式。

# ---- 基本色票 ----
const BG := Color("#f4f1e9")            # 溫暖紙張色背景
const CARD := Color("#ffffff")
const PRIMARY := Color("#4a63c8")
const PRIMARY_DARK := Color("#3a4fa3")
const ACCENT := Color("#f0a643")
const TEXT := Color("#2b2b33")
const TEXT_MUTED := Color("#84848e")
const ERROR := Color("#d65454")
const SUCCESS := Color("#3f9e6e")
const DISABLED := Color("#c9c9cf")

# ---- 五子棋色票 ----
const GOMOKU_BOARD := Color("#e6c793")
const GOMOKU_LINE := Color("#8a6b45")
const STONE_BLACK := Color("#26262c")
const STONE_WHITE := Color("#fbfbf9")
const STONE_WHITE_EDGE := Color("#b5b5bf")

# ---- 2048 色票 ----
const T2048_BOARD := Color("#cbc2b0")
const T2048_SLOT := Color("#ded5c5")
const T2048_TEXT_DARK := Color("#776e65")
const T2048_SUPER := Color("#3c3a32")
const T2048_TILES := {
	2: Color("#eee4da"), 4: Color("#ede0c8"), 8: Color("#f2b179"),
	16: Color("#f59563"), 32: Color("#f67c5f"), 64: Color("#f65e3b"),
	128: Color("#edcf72"), 256: Color("#edcc61"), 512: Color("#edc850"),
	1024: Color("#edc53f"), 2048: Color("#edc22e"),
}

# ---- 踩地雷色票 ----
const MINE_COVERED := Color("#a9b6d3")
const MINE_COVERED_EDGE := Color("#8d9cc0")
const MINE_REVEALED := Color("#efece2")
const MINE_LINE := Color("#c6cbdb")
const MINE_FLAG := Color("#d65454")
const MINE_BOMB := Color("#2b2b33")
const MINE_EXPLODED := Color("#f2b1b1")
## 數字 1~8 的顏色（索引 0 不使用）
const MINE_NUMBERS := [
	Color.WHITE,
	Color("#1976d2"), Color("#388e3c"), Color("#d32f2f"), Color("#7b1fa2"),
	Color("#b26500"), Color("#0097a7"), Color("#455a64"), Color("#616161"),
]

# ---- 黑白棋色票 ----
const REVERSI_BOARD := Color("#3f8f5f")
const REVERSI_LINE := Color("#2e6b47")
const REVERSI_HINT := Color(1.0, 1.0, 1.0, 0.35)

# ---- 棋盤色票 ----
const CELL_BG := Color("#ffffff")
const CELL_SELECTED := Color("#c9d4f6")
const CELL_PEER := Color("#ebeffa")
const CELL_SAME := Color("#d8e0f8")
const CELL_ERROR_BG := Color("#f8dcdc")
const GRID_LINE := Color("#bfc4d2")
const GRID_LINE_BOLD := Color("#5a5f70")
const DIGIT_GIVEN := Color("#2b2b33")
const DIGIT_USER := Color("#4a63c8")
const DIGIT_ERROR := Color("#d65454")
const NOTE := Color("#9a9aa6")


## 建立整個 App 的預設 Theme（在 Main 套用一次即可）
static func build() -> Theme:
	var t := Theme.new()
	t.default_font_size = 26

	# 主要按鈕：實心圓角
	t.set_stylebox("normal", "Button", _btn_box(PRIMARY))
	t.set_stylebox("hover", "Button", _btn_box(PRIMARY.lightened(0.08)))
	t.set_stylebox("pressed", "Button", _btn_box(PRIMARY_DARK))
	t.set_stylebox("disabled", "Button", _btn_box(DISABLED))
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", Color.WHITE)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", Color("#f4f4f6"))
	t.set_font_size("font_size", "Button", 30)

	t.set_color("font_color", "Label", TEXT)
	t.set_font_size("font_size", "Label", 26)

	t.set_stylebox("panel", "PanelContainer", card_style())
	return t


## 卡片底板（白色圓角 + 淡陰影）
static func card_style() -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = CARD
	sb.set_corner_radius_all(18)
	sb.shadow_color = Color(0, 0, 0, 0.06)
	sb.shadow_size = 8
	return sb


## 次要按鈕：白底、主色外框
static func style_secondary(btn: Button) -> void:
	var normal := _flat_box(CARD)
	normal.set_border_width_all(2)
	normal.border_color = PRIMARY
	var hover := _flat_box(Color("#f3f5fc"))
	hover.set_border_width_all(2)
	hover.border_color = PRIMARY
	var pressed := _flat_box(Color("#e3e9fb"))
	pressed.set_border_width_all(2)
	pressed.border_color = PRIMARY_DARK
	btn.add_theme_stylebox_override("normal", normal)
	btn.add_theme_stylebox_override("hover", hover)
	btn.add_theme_stylebox_override("pressed", pressed)
	btn.add_theme_stylebox_override("disabled", _flat_box(Color("#efece4")))
	btn.add_theme_color_override("font_color", PRIMARY)
	btn.add_theme_color_override("font_hover_color", PRIMARY)
	btn.add_theme_color_override("font_pressed_color", PRIMARY_DARK)
	btn.add_theme_color_override("font_disabled_color", DISABLED)


## 數字鍵：白底大字
static func style_number(btn: Button) -> void:
	btn.add_theme_stylebox_override("normal", _flat_box(CARD))
	btn.add_theme_stylebox_override("hover", _flat_box(Color("#eef1fb")))
	btn.add_theme_stylebox_override("pressed", _flat_box(Color("#dde4f9")))
	btn.add_theme_stylebox_override("disabled", _flat_box(Color("#efece4")))
	btn.add_theme_color_override("font_color", TEXT)
	btn.add_theme_color_override("font_hover_color", TEXT)
	btn.add_theme_color_override("font_pressed_color", PRIMARY_DARK)
	btn.add_theme_color_override("font_disabled_color", DISABLED)
	btn.add_theme_font_size_override("font_size", 44)


static func _btn_box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(14)
	sb.content_margin_left = 24.0
	sb.content_margin_right = 24.0
	sb.content_margin_top = 14.0
	sb.content_margin_bottom = 14.0
	return sb


static func _flat_box(c: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = c
	sb.set_corner_radius_all(12)
	sb.content_margin_left = 12.0
	sb.content_margin_right = 12.0
	sb.content_margin_top = 12.0
	sb.content_margin_bottom = 12.0
	return sb
