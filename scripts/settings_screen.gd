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
