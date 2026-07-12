extends SceneTree
## 成就判定單元測試（純函式，不需要 autoload）。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_achievements.gd

const Achv := preload("res://scripts/achievement_defs.gd")

var failures := 0


func _initialize() -> void:
	# 空存檔：不解鎖任何成就
	var none := Achv.evaluate_all({})
	_check(none.is_empty(), "空存檔無成就（%s）" % str(none))

	# 完成一局數獨
	var a := Achv.evaluate_all({"sudoku_stats": {"won": 1}})
	_check(a.has("sudoku_first") and a.size() == 1, "數獨首勝只解鎖 sudoku_first")

	# 專家數獨（best_3 有值）+ 10 勝
	var b := Achv.evaluate_all({"sudoku_stats": {"won": 10, "best_3": 245}})
	_check(b.has("sudoku_10") and b.has("sudoku_expert"), "數獨 10 勝與專家成就")

	# 連續 7 天：daily_3 與 daily_7 同時達成
	var c := Achv.evaluate_all({"daily": {"best_streak": 7}})
	_check(c.has("daily_3") and c.has("daily_7"), "連續天數成就")

	# 四款遊戲都有成果 → all_games；只有三款則不解鎖
	var d := Achv.evaluate_all({
		"sudoku_stats": {"won": 1},
		"gomoku_stats": {"won": 1, "won_3": 1},
		"reversi_stats": {"won": 1},
		"minesweeper_stats": {"won": 1, "won_3": 1},
	})
	_check(d.has("all_games") and d.has("gomoku_expert") and d.has("minesweeper_expert"), "全能玩家與專家成就")
	var d3 := Achv.evaluate_all({
		"sudoku_stats": {"won": 1},
		"gomoku_stats": {"won": 1},
		"reversi_stats": {"won": 1},
	})
	_check(not d3.has("all_games"), "缺一款遊戲不解鎖全能玩家")

	# 定義完整性：id 不重複、欄位齊全
	var ids := {}
	var defs_ok := true
	for def in Achv.all_defs():
		if not (def.has("id") and def.has("name") and def.has("desc") and def.has("conds")):
			defs_ok = false
		if ids.has(def["id"]):
			defs_ok = false
		ids[def["id"]] = true
	_check(defs_ok, "成就定義完整且 id 不重複（共 %d 個）" % ids.size())

	if failures == 0:
		print("[test] PASS")
		quit(0)
	else:
		print("[test] FAIL（%d 項）" % failures)
		quit(1)


func _check(cond: bool, msg: String) -> void:
	if cond:
		print("OK：" + msg)
	else:
		print("FAIL：" + msg)
		failures += 1
