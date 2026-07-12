extends SceneTree
## 2048 邏輯單元測試。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_game2048_logic.gd

const Logic := preload("res://scripts/game2048/game2048_logic.gd")

var failures := 0


func _initialize() -> void:
	_test_merge()
	_test_slide_directions()
	_test_no_move()
	_test_spawn()
	_test_can_move()

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


func _grid(rows: Array) -> Array[int]:
	var g: Array[int] = []
	for row in rows:
		for v in row:
			g.append(int(v))
	return g


func _test_merge() -> void:
	# [2,2,0,0] 左滑 → [4,0,0,0]，得 4 分
	var g := _grid([[2, 2, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var r := Logic.slide(g, Logic.DIR_LEFT)
	_check(bool(r["moved"]) and int(r["gained"]) == 4 and g[0] == 4 and g[1] == 0, "基本合併")

	# [2,2,2,2] 左滑 → [4,4,0,0]，不能連鎖合併成 8
	var g2 := _grid([[2, 2, 2, 2], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var r2 := Logic.slide(g2, Logic.DIR_LEFT)
	_check(g2[0] == 4 and g2[1] == 4 and g2[2] == 0 and int(r2["gained"]) == 8, "同列四個只合併成兩個")

	# [4,2,2,0] 左滑 → [4,4,0,0]（先滑再合，4 不與新 4 合併）
	var g3 := _grid([[4, 2, 2, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	Logic.slide(g3, Logic.DIR_LEFT)
	_check(g3[0] == 4 and g3[1] == 4 and g3[2] == 0, "一次滑動每磚最多合併一次")


func _test_slide_directions() -> void:
	# 同一盤面四個方向各自正確
	var base := _grid([[2, 0, 0, 2], [0, 0, 0, 0], [0, 0, 0, 0], [2, 0, 0, 0]])
	var left := base.duplicate()
	Logic.slide(left, Logic.DIR_LEFT)
	_check(left[0] == 4 and left[12] == 2, "左滑合併首列")
	var right := base.duplicate()
	Logic.slide(right, Logic.DIR_RIGHT)
	_check(right[3] == 4 and right[15] == 2, "右滑合併到最右")
	var up := base.duplicate()
	Logic.slide(up, Logic.DIR_UP)
	_check(up[0] == 4 and up[3] == 2, "上滑合併首行")
	var down := base.duplicate()
	Logic.slide(down, Logic.DIR_DOWN)
	_check(down[12] == 4 and down[15] == 2, "下滑合併到最底")


func _test_no_move() -> void:
	# 已靠左且無可合併 → moved = false
	var g := _grid([[2, 4, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0], [0, 0, 0, 0]])
	var r := Logic.slide(g, Logic.DIR_LEFT)
	_check(not bool(r["moved"]), "無效滑動不算移動")


func _test_spawn() -> void:
	var g := Logic.new_grid()
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var i := Logic.spawn(g, rng)
	_check(i >= 0 and (g[i] == 2 or g[i] == 4), "生成 2 或 4")
	# 填滿後不能再生成
	for k in Logic.CELLS:
		g[k] = 2
	_check(Logic.spawn(g, rng) == -1, "滿盤不生成")


func _test_can_move() -> void:
	# 棋盤格紋（無相鄰同值、無空格）→ 不能動
	var g := _grid([[2, 4, 2, 4], [4, 2, 4, 2], [2, 4, 2, 4], [4, 2, 4, 2]])
	_check(not Logic.can_move(g), "死局判定")
	g[5] = 4  # 造出相鄰同值
	_check(Logic.can_move(g), "可合併判定")
	_check(Logic.max_tile(g) == 4, "最大磚塊")
