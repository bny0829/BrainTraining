class_name AchievementScreen
extends Control
## 成就清單畫面：顯示全部成就與解鎖狀態。


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
	title.text = "成就（%d / %d）" % [Achievements.unlocked_count(), Achievements.total_count()]
	title.add_theme_font_size_override("font_size", 34)
	top.add_child(title)
	var spacer2 := Control.new()
	spacer2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(spacer2)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_theme_constant_override("separation", 14)
	scroll.add_child(list)

	for def in AchievementDefs.all_defs():
		_achievement_card(list, def)


func _achievement_card(list: VBoxContainer, def: Dictionary) -> void:
	var id := String(def["id"])
	var done := Achievements.is_unlocked(id)

	var panel := PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_PASS  # 讓捲動手勢穿透卡片
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	panel.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	var name_label := Label.new()
	name_label.text = String(def["name"])
	name_label.add_theme_font_size_override("font_size", 30)
	name_label.add_theme_color_override("font_color", AppTheme.PRIMARY_DARK if done else AppTheme.TEXT_MUTED)
	inner.add_child(name_label)

	var desc := Label.new()
	desc.text = String(def["desc"])
	desc.add_theme_font_size_override("font_size", 22)
	desc.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
	inner.add_child(desc)

	var status := Label.new()
	status.add_theme_font_size_override("font_size", 22)
	if done:
		status.text = "已解鎖・" + Achievements.unlock_date(id)
		status.add_theme_color_override("font_color", AppTheme.SUCCESS)
	else:
		status.text = "未解鎖"
		status.add_theme_color_override("font_color", AppTheme.DISABLED)
	inner.add_child(status)
