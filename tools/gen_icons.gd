extends SceneTree
## 產生 Android 啟動圖示（從 icon.svg）。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tools/gen_icons.gd
## 產出：assets/android/ 下的 4 個 PNG，對應匯出設定的 launcher icons。


func _initialize() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/android")
	var svg := FileAccess.get_file_as_string("res://icon.svg")

	# 主圖示 192×192（舊裝置用）
	var main_icon := Image.new()
	main_icon.load_svg_from_string(svg, 1.5)  # 128 × 1.5 = 192
	main_icon.save_png("res://assets/android/icon_main_192.png")

	# 自適應前景 432×432：圖示置中縮小（系統會裁成圓形，安全區約中央 66%）
	var fg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	var small := Image.new()
	small.load_svg_from_string(svg, 1.875)  # 128 × 1.875 = 240
	fg.blend_rect(small, Rect2i(0, 0, 240, 240), Vector2i((432 - 240) / 2, (432 - 240) / 2))
	fg.save_png("res://assets/android/icon_adaptive_fg_432.png")

	# 自適應背景 432×432：主色純色
	var bg := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	bg.fill(Color("#4a63c8"))
	bg.save_png("res://assets/android/icon_adaptive_bg_432.png")

	# 單色版 432×432（Android 13+ 主題圖示）：白色格線圖形
	var mono_svg := """<svg xmlns="http://www.w3.org/2000/svg" width="128" height="128" viewBox="0 0 128 128">
<g stroke="#FFFFFF" stroke-width="8" stroke-linecap="round">
<line x1="52" y1="28" x2="52" y2="100"/><line x1="76" y1="28" x2="76" y2="100"/>
<line x1="28" y1="52" x2="100" y2="52"/><line x1="28" y1="76" x2="100" y2="76"/>
</g><rect x="56" y="56" width="16" height="16" rx="3" fill="#FFFFFF"/></svg>"""
	var mono := Image.create(432, 432, false, Image.FORMAT_RGBA8)
	var glyph := Image.new()
	glyph.load_svg_from_string(mono_svg, 1.875)  # 240
	mono.blend_rect(glyph, Rect2i(0, 0, 240, 240), Vector2i((432 - 240) / 2, (432 - 240) / 2))
	mono.save_png("res://assets/android/icon_adaptive_mono_432.png")

	# Google Play 商店圖示 512×512（不透明、無圓角遮罩由 Play 處理）
	DirAccess.make_dir_recursive_absolute("res://store_assets")
	var store := Image.new()
	store.load_svg_from_string(svg, 4.0)  # 128 × 4 = 512
	store.save_png("res://store_assets/icon_512.png")

	print("[gen_icons] 完成：assets/android/ 4 個 PNG + store_assets/icon_512.png")
	quit(0)
