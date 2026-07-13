extends Node
## 每日挑戰（Autoload：Daily）
## 以日期作為亂數種子 → 全世界玩家同一天拿到同一題，完全離線、零伺服器成本。
## v0.3 起每天輪替不同遊戲：數獨看種子、棋類看「當日指定難度獲勝」。

# Time.get_date_dict_from_system().weekday：0 = 星期日
const ROTATION := [
	{"game": "reversi", "difficulty": ReversiLogic.Difficulty.NORMAL},          # 日
	{"game": "sudoku", "difficulty": SudokuLogic.Difficulty.EASY},              # 一
	{"game": "gomoku", "difficulty": GomokuLogic.Difficulty.NORMAL},            # 二
	{"game": "minesweeper", "difficulty": MinesweeperLogic.Difficulty.NORMAL},  # 三
	{"game": "freecell", "difficulty": 0},                                      # 四（新接龍幾乎必有解）
	{"game": "gomoku", "difficulty": GomokuLogic.Difficulty.HARD},              # 五
	{"game": "sudoku", "difficulty": SudokuLogic.Difficulty.EXPERT},            # 六（週末 Boss）
]


func today_id() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d.year, d.month, d.day]


func today_seed() -> int:
	var d := Time.get_date_dict_from_system()
	return d.year * 10000 + d.month * 100 + d.day


## 今日挑戰內容：{ "game": String, "difficulty": int, "seed": int }
func today_challenge() -> Dictionary:
	var rot: Dictionary = ROTATION[Time.get_date_dict_from_system().weekday]
	return {
		"game": String(rot["game"]),
		"difficulty": int(rot["difficulty"]),
		"seed": today_seed(),
	}


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
	Achievements.refresh()


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
