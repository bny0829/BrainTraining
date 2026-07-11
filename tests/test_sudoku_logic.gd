extends SceneTree
## 數獨邏輯單元測試（不需要視窗）。執行方式：
##   Godot執行檔 --headless --path 專案目錄 --script res://tests/test_sudoku_logic.gd

const Logic := preload("res://scripts/sudoku/sudoku_logic.gd")


func _initialize() -> void:
	var failures := 0
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260712

	for diff in [0, 1, 2, 3]:
		var t0 := Time.get_ticks_msec()
		var gen := Logic.generate(diff, rng)
		var ms := Time.get_ticks_msec() - t0
		var solver := Logic.Solver.new()
		var unique := solver.count(gen.puzzle, 2) == 1
		var valid: bool = Logic.is_valid_solution(gen.solution)
		var subset := true
		for i in 81:
			if gen.puzzle[i] != 0 and gen.puzzle[i] != gen.solution[i]:
				subset = false
				break
		var rating: int = Logic.rate(gen.puzzle)
		print("難度 %d：提示數 %d、唯一解 %s、解答合法 %s、題目為解答子集 %s、評估難度 %d、耗時 %d ms" % [
			diff, gen.clues, unique, valid, subset, rating, ms
		])
		if not unique or not valid or not subset:
			failures += 1

	# 每日挑戰依賴：同一種子必須產生同一題
	var a := Logic.generate(1, _seeded(42))
	var b := Logic.generate(1, _seeded(42))
	if a.puzzle == b.puzzle and a.solution == b.solution:
		print("同種子產生相同題目：OK")
	else:
		print("同種子產生不同題目：FAIL")
		failures += 1

	if failures == 0:
		print("[test] PASS")
		quit(0)
	else:
		print("[test] FAIL（%d 項）" % failures)
		quit(1)


func _seeded(s: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = s
	return rng
