class_name OverlayDialog
extends ColorRect
## 全平台共用的置中對話框（半透明遮罩 + 卡片 + 直排按鈕）。
## buttons 每項：{ "text": String, "action": Callable（可省略）, "secondary": bool（可省略） }


static func open(parent: Node, title: String, message: String, buttons: Array) -> OverlayDialog:
	var dlg := OverlayDialog.new()
	dlg.color = Color(0.08, 0.08, 0.12, 0.55)
	dlg.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg.mouse_filter = Control.MOUSE_FILTER_STOP

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	dlg.add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(480, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 28)
	panel.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 18)
	margin.add_child(col)

	var title_label := Label.new()
	title_label.text = title
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.add_theme_font_size_override("font_size", 38)
	col.add_child(title_label)

	if message != "":
		var msg_label := Label.new()
		msg_label.text = message
		msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		msg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		msg_label.add_theme_color_override("font_color", AppTheme.TEXT_MUTED)
		col.add_child(msg_label)

	for b in buttons:
		var btn := Button.new()
		btn.text = String(b.get("text", ""))
		if bool(b.get("secondary", false)):
			AppTheme.style_secondary(btn)
		var action: Variant = b.get("action")
		btn.pressed.connect(func() -> void:
			dlg.queue_free()
			if action is Callable and (action as Callable).is_valid():
				(action as Callable).call()
		)
		col.add_child(btn)

	parent.add_child(dlg)
	return dlg
