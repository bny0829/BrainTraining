class_name AchievementDefs
extends RefCounted
## 成就定義與判定：純函式、不依賴任何 autoload，可 headless 單元測試。
## 成就以宣告式條件定義：conds 內每項 = 存檔[section][key] >= min，全部達成才解鎖。


static func all_defs() -> Array:
	return [
		{"id": "sudoku_first", "name": "數獨啟蒙", "desc": "完成第一局數獨",
			"conds": [{"section": "sudoku_stats", "key": "won", "min": 1}]},
		{"id": "sudoku_10", "name": "數獨常客", "desc": "完成 10 局數獨",
			"conds": [{"section": "sudoku_stats", "key": "won", "min": 10}]},
		{"id": "sudoku_expert", "name": "數獨大師", "desc": "完成一局專家難度數獨",
			"conds": [{"section": "sudoku_stats", "key": "best_3", "min": 1}]},
		{"id": "gomoku_first", "name": "五子棋首勝", "desc": "第一次擊敗五子棋 AI",
			"conds": [{"section": "gomoku_stats", "key": "won", "min": 1}]},
		{"id": "gomoku_expert", "name": "棋逢對手", "desc": "擊敗專家級五子棋 AI",
			"conds": [{"section": "gomoku_stats", "key": "won_3", "min": 1}]},
		{"id": "reversi_first", "name": "翻轉入門", "desc": "第一次擊敗黑白棋 AI",
			"conds": [{"section": "reversi_stats", "key": "won", "min": 1}]},
		{"id": "reversi_expert", "name": "翻轉大師", "desc": "擊敗專家級黑白棋 AI",
			"conds": [{"section": "reversi_stats", "key": "won_3", "min": 1}]},
		{"id": "minesweeper_first", "name": "排雷新兵", "desc": "第一次掃雷成功",
			"conds": [{"section": "minesweeper_stats", "key": "won", "min": 1}]},
		{"id": "minesweeper_expert", "name": "拆彈專家", "desc": "完成專家難度掃雷",
			"conds": [{"section": "minesweeper_stats", "key": "won_3", "min": 1}]},
		{"id": "daily_3", "name": "三日不輟", "desc": "連續 3 天完成每日挑戰",
			"conds": [{"section": "daily", "key": "best_streak", "min": 3}]},
		{"id": "daily_7", "name": "七日成習", "desc": "連續 7 天完成每日挑戰",
			"conds": [{"section": "daily", "key": "best_streak", "min": 7}]},
		{"id": "all_games", "name": "全能玩家", "desc": "四款遊戲都取得成果",
			"conds": [
				{"section": "sudoku_stats", "key": "won", "min": 1},
				{"section": "gomoku_stats", "key": "won", "min": 1},
				{"section": "reversi_stats", "key": "won", "min": 1},
				{"section": "minesweeper_stats", "key": "won", "min": 1},
			]},
	]


## 給存檔資料，回傳目前達成的所有成就 id
static func evaluate_all(data: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for def in all_defs():
		var met := true
		for cond in def["conds"]:
			if _stat(data, String(cond["section"]), String(cond["key"])) < int(cond["min"]):
				met = false
				break
		if met:
			out.append(String(def["id"]))
	return out


static func _stat(data: Dictionary, section: String, key: String) -> int:
	var s: Variant = data.get(section)
	if s is Dictionary:
		return int(s.get(key, 0))
	return 0
