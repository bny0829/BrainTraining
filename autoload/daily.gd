extends Node
## 每日挑戰（Autoload：Daily）
## 以日期作為亂數種子 → 全世界玩家同一天拿到同一題，完全離線、零伺服器成本。
## 未來所有遊戲的每日挑戰都走這套種子與連續天數（streak）機制。

# Time.get_date_dict_from_system().weekday：0 = 星期日
const WEEKDAY_DIFFICULTY := [
	SudokuLogic.Difficulty.MEDIUM,  # 日
	SudokuLogic.Difficulty.EASY,    # 一
	SudokuLogic.Difficulty.MEDIUM,  # 二
	SudokuLogic.Difficulty.MEDIUM,  # 三
	SudokuLogic.Difficulty.HARD,    # 四
	SudokuLogic.Difficulty.HARD,    # 五
	SudokuLogic.Difficulty.EXPERT,  # 六
]


func today_id() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func today_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day


func today_difficulty() -> int:
	return WEEKDAY_DIFFICULTY[Time.get_date_dict_from_system().weekday]


func is_completed_today() -> bool:
	return String(SaveManager.section("daily").get("last_completed", "")) == today_id()


func mark_completed() -> void:
	var d := SaveManager.section("daily")
	if String(d.get("last_completed", "")) == today_id():
		return
	if String(d.get("last_completed", "")) == _yesterday_id():
		d["streak"] = int(d.get("streak", 0)) + 1
	else:
		d["streak"] = 1
	d["best_streak"] = maxi(int(d.get("best_streak", 0)), int(d["streak"]))
	d["last_completed"] = today_id()
	SaveManager.save()


## 目前有效的連續天數（昨天或今天有完成才算延續）
func streak() -> int:
	var d := SaveManager.section("daily")
	var last := String(d.get("last_completed", ""))
	if last == today_id() or last == _yesterday_id():
		return int(d.get("streak", 0))
	return 0


func _yesterday_id() -> String:
	var now := Time.get_datetime_dict_from_system()
	var unix := Time.get_unix_time_from_datetime_dict(now) - 86400
	var y := Time.get_datetime_dict_from_unix_time(unix)
	return "%04d-%02d-%02d" % [y.year, y.month, y.day]
