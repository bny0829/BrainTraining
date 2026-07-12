extends Node
## 成就系統（Autoload：Achievements）
## 定義與判定在 AchievementDefs（純函式、可測試）；這裡負責解鎖紀錄與通知 UI。
## 解鎖紀錄存在存檔的 "achievements" section（id → 解鎖日期）。
## 戰績寫入（SaveManager.record_*）與每日完成（Daily.mark_completed）後會呼叫 refresh()。

signal unlocked(def: Dictionary)

var _toast_layer: CanvasLayer
var _toast_count := 0


func _ready() -> void:
	_toast_layer = CanvasLayer.new()
	_toast_layer.layer = 10
	add_child(_toast_layer)


## 重新判定所有成就，新解鎖的存檔並彈出通知
func refresh() -> void:
	var store := SaveManager.section("achievements")
	var changed := false
	var met := AchievementDefs.evaluate_all(SaveManager.data)
	for def in AchievementDefs.all_defs():
		var id := String(def["id"])
		if store.has(id) or not met.has(id):
			continue
		store[id] = Daily.today_id()
		changed = true
		_show_toast(def)
		unlocked.emit(def)
	if changed:
		SaveManager.save()


func is_unlocked(id: String) -> bool:
	return SaveManager.section("achievements").has(id)


func unlock_date(id: String) -> String:
	return String(SaveManager.section("achievements").get(id, ""))


func unlocked_count() -> int:
	return SaveManager.section("achievements").size()


func total_count() -> int:
	return AchievementDefs.all_defs().size()


## 頂部滑入的解鎖通知
func _show_toast(def: Dictionary) -> void:
	var panel := PanelContainer.new()
	panel.theme = AppTheme.build()
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.position.y = 40.0 + _toast_count * 120.0
	_toast_layer.add_child(panel)
	_toast_count += 1

	var margin := MarginContainer.new()
	for m in ["margin_left", "margin_right", "margin_top", "margin_bottom"]:
		margin.add_theme_constant_override(m, 20)
	panel.add_child(margin)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	margin.add_child(col)
	var head := Label.new()
	head.text = "成就解鎖！"
	head.add_theme_font_size_override("font_size", 22)
	head.add_theme_color_override("font_color", AppTheme.ACCENT)
	col.add_child(head)
	var name_label := Label.new()
	name_label.text = "%s — %s" % [String(def["name"]), String(def["desc"])]
	name_label.add_theme_font_size_override("font_size", 26)
	col.add_child(name_label)

	panel.modulate = Color(1, 1, 1, 0)
	var tween := panel.create_tween()
	tween.tween_property(panel, "modulate:a", 1.0, 0.25)
	tween.tween_interval(2.5)
	tween.tween_property(panel, "modulate:a", 0.0, 0.4)
	tween.tween_callback(func() -> void:
		panel.queue_free()
		_toast_count = maxi(0, _toast_count - 1)
	)
