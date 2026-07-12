extends Node
## 產生 Google Play 主題圖（Feature Graphic，1024×500）。執行方式：
##   $env:BRAINCLUB_BANNER = "輸出.png 的絕對路徑"
##   Godot執行檔 --path 專案目錄 --resolution 1024x500
## Main 偵測到環境變數後載入本腳本，畫好版面、截圖、自動結束。


func _ready() -> void:
	_run.call_deferred()


func _run() -> void:
	var root := Main.instance
	var cover := ColorRect.new()
	cover.color = AppTheme.PRIMARY_DARK
	cover.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(cover)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	cover.add_child(center)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 90)
	center.add_child(row)

	# 圖示以高解析度重新算圖，避免用 128px 素材放大變模糊
	var svg := FileAccess.get_file_as_string("res://icon.svg")
	var img := Image.new()
	img.load_svg_from_string(svg, 5.0)
	var icon := TextureRect.new()
	icon.texture = ImageTexture.create_from_image(img)
	icon.custom_minimum_size = Vector2(600, 600)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 36)
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_child(col)

	var title := Label.new()
	title.text = "Brain Club"
	title.add_theme_font_size_override("font_size", 210)
	title.add_theme_color_override("font_color", Color.WHITE)
	col.add_child(title)

	var sub := Label.new()
	sub.text = "數獨・五子棋・黑白棋・踩地雷・2048・接龍"
	sub.add_theme_font_size_override("font_size", 72)
	sub.add_theme_color_override("font_color", Color("#dfe6ff"))
	col.add_child(sub)

	var sub2 := Label.new()
	sub2.text = "每日挑戰　完全離線　無廣告"
	sub2.add_theme_font_size_override("font_size", 70)
	sub2.add_theme_color_override("font_color", AppTheme.ACCENT)
	col.add_child(sub2)

	await get_tree().process_frame
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var shot := root.get_viewport().get_texture().get_image()
	shot.save_png(OS.get_environment("BRAINCLUB_BANNER"))
	print("[banner] 已輸出 %d×%d" % [shot.get_width(), shot.get_height()])
	get_tree().quit(0)
