class_name SettingsScreen
extends Control
## 設定畫面：音效開關、重置進度、版本資訊。


func _ready() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var top := HBoxContainer.new()
	col.add_child(top)
	var back := Button.new()
	back.text = "← 返回"
	AppTheme.style_secondary(back)
	back.pressed.connect(func() -> void: Main.instance.goto_home())
	top.add_child(back)
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer)
	var title := Label.new()
	title.text = "設定"
	title.add_theme_font_size_override("font_size", 34)
	top.add_child(title)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)

	# 音效開關
	var sound_card := _card(col)
	var row := HBoxContainer.new()
	sound_card.add_child(row)
	var sound_label := Label.new()
	sound_label.text = "音效"
	sound_label.add_theme_font_size_override("font_size", 30)
	row.add_child(sound_label)
	var rspacer := Control.new()
	rspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(rspacer)
	var toggle := Button.new()
	toggle.toggle_mode = true
	toggle.button_pressed = Sfx.enabled()
	toggle.text = "開啟" if Sfx.enabled() else "關閉"
	toggle.custom_minimum_size = Vector2(160, 0)
	toggle.toggled.connect(func(on: bool) -> void:
		Sfx.set_enabled(on)
		toggle.text = "開啟" if on else "關閉"
		Sfx.play("tap")
	)
	row.add_child(toggle)

	# 語言
	var lang_card := _card(col)
	var lang_row := HBoxContainer.new()
	lang_card.add_child(lang_row)
	var lang_label := Label.new()
	lang_label.text = "語言"
	lang_label.add_theme_font_size_override("font_size", 30)
	lang_row.add_child(lang_label)
	var lspacer := Control.new()
	lspacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	lang_row.add_child(lspacer)
	var lang_btn := Button.new()
	lang_btn.custom_minimum_size = Vector2(220, 0)
	lang_btn.text = _language_text(String(SaveManager.section("settings").get("language", "")))
	lang_btn.pressed.connect(_pick_language)
	lang_row.add_child(lang_btn)

	# 資料
	var data_card := _card(col)
	var reset := Button.new()
	reset.text = "重置所有進度"
	AppTheme.style_secondary(reset)
	reset.add_theme_color_override("font_color", AppTheme.ERROR)
	reset.add_theme_color_override("font_hover_color", AppTheme.ERROR)
	reset.pressed.connect(_confirm_reset)
	data_card.add_child(reset)
	var hint := Label.new()
	hint.text = "戰績、成就與連續天數將全部清除，無法復原"
	hint.add_theme_font_size_override("font_size", 20)
	hint.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	data_card.add_child(hint)

	# 版本
	var about := _card(col)
	var version := Label.new()
	version.text = "Brain Club v%s" % String(ProjectSettings.get_setting("application/config/version", "dev"))
	version.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	about.add_child(version)


const LANGUAGES := ["", "zh_TW", "en"]


func _language_text(code: String) -> String:
	match code:
		"zh_TW":
			return "中文"
		"en":
			return "English"
		_:
			return tr("跟隨系統")


## 用清單彈窗讓玩家直接選定語言（而非隱藏式循環）：
## 「跟隨系統」在裝置系統語言剛好是英文時，跟「English」顯示結果完全一樣，
## 之前用循環按鈕會讓玩家以為切換沒有反應；改成明確列出目前選取的項目就不會混淆。
func _pick_language() -> void:
	var current := String(SaveManager.section("settings").get("language", ""))
	var buttons: Array = []
	for code in LANGUAGES:
		var label := _language_text(code)
		if code == current:
			label += "  ✓"
		buttons.append({"text": label, "action": _set_language.bind(code)})
	buttons.append({"text": "取消", "secondary": true})
	OverlayDialog.open(self, "選擇語言", "", buttons)


func _set_language(code: String) -> void:
	SaveManager.section("settings")["language"] = code
	SaveManager.save()
	Main.apply_locale()
	# 重建畫面讓新語言立即生效
	Main.instance.open_settings()


func _confirm_reset() -> void:
	OverlayDialog.open(self, "重置所有進度？", "戰績、成就與連續天數將全部清除，無法復原", [
		{"text": "確認重置", "action": _do_reset},
		{"text": "取消", "secondary": true},
	])


func _do_reset() -> void:
	SaveManager.data = {}
	SaveManager.save()
	Main.instance.goto_home()


func _card(col: VBoxContainer) -> VBoxContainer:
	var panel := PanelContainer.new()
	col.add_child(panel)
	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 24)
	panel.add_child(margin)
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 12)
	margin.add_child(inner)
	return inner
