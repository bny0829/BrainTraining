class_name SudokuLogic
extends RefCounted
## 數獨核心邏輯：盤面產生、解題、唯一解驗證與難度評估。
## 盤面一律以 Array[int]（長度 81，0 = 空格）表示，索引 = 列 * 9 + 行。
## 此模組不依賴任何 UI 或存檔，未來其他平台（伺服器批次產題）可直接重用。

enum Difficulty { EASY, MEDIUM, HARD, EXPERT }

const DIFFICULTY_TEXT := {
	Difficulty.EASY: "簡單",
	Difficulty.MEDIUM: "普通",
	Difficulty.HARD: "困難",
	Difficulty.EXPERT: "專家",
}

const DIFFICULTY_STARS := {
	Difficulty.EASY: "★☆☆☆",
	Difficulty.MEDIUM: "★★☆☆",
	Difficulty.HARD: "★★★☆",
	Difficulty.EXPERT: "★★★★",
}

## 各難度的目標提示數（保留的已知格數）
const CLUE_TARGET := {
	Difficulty.EASY: 42,
	Difficulty.MEDIUM: 34,
	Difficulty.HARD: 29,
	Difficulty.EXPERT: 26,
}

## 1~9 全部候選數字的位元遮罩
const ALL_MASK := 0x1FF


## 產生一題保證唯一解的數獨。
## 回傳 { "puzzle": Array[int], "solution": Array[int], "difficulty": int, "clues": int }
## 相同 rng 種子必定產生相同題目（每日挑戰依賴此性質）。
static func generate(difficulty: int, rng: RandomNumberGenerator) -> Dictionary:
	var solver := Solver.new()
	var solution := solver.solve_random(rng)
	var puzzle: Array[int] = solution.duplicate()
	var target := int(CLUE_TARGET[difficulty])
	var clues := 81

	# 第一輪：中心對稱成對移除，讓盤面視覺較平衡
	for idx in shuffled_range(rng):
		if clues <= target:
			break
		var pair := 80 - idx
		var spots := [idx] if pair == idx else [idx, pair]
		var removed: Array = []
		for p in spots:
			if puzzle[p] != 0:
				removed.append([p, puzzle[p]])
				puzzle[p] = 0
		if removed.is_empty():
			continue
		if solver.count(puzzle, 2) == 1:
			clues -= removed.size()
		else:
			for item in removed:
				puzzle[item[0]] = item[1]

	# 第二輪：單格移除，盡量逼近目標提示數（高難度時對稱移除常會卡住）
	if clues > target:
		for idx in shuffled_range(rng):
			if clues <= target:
				break
			if puzzle[idx] == 0:
				continue
			var v := puzzle[idx]
			puzzle[idx] = 0
			if solver.count(puzzle, 2) == 1:
				clues -= 1
			else:
				puzzle[idx] = v

	return {
		"puzzle": puzzle,
		"solution": solution,
		"difficulty": difficulty,
		"clues": clues,
	}


## 難度評估器：模擬「只用人類基本技巧」解題，依所需技巧回推難度。
## 這是 AI 難度分析的第一版，未來可加入更多技巧（區塊摒除、數對…）讓分級更細。
static func rate(puzzle: Array) -> int:
	var cells: Array[int] = []
	for v in puzzle:
		cells.append(int(v))
	var clues := 0
	for v in cells:
		if v != 0:
			clues += 1
	var used_hidden := false
	var solver := Solver.new()

	while true:
		if not solver.reset(cells):
			return Difficulty.EXPERT
		var empty := 0
		var progressed := false
		# 唯一候選數（Naked Single）：因為題目保證唯一解，強制推論可以一次套用
		for i in 81:
			if cells[i] != 0:
				continue
			empty += 1
			var m := solver.candidates(i)
			if popcount(m) == 1:
				cells[i] = lowest_digit(m)
				progressed = true
		if empty == 0:
			break
		if progressed:
			continue
		# 隱性唯一數（Hidden Single）
		if _apply_hidden_singles(cells, solver) > 0:
			used_hidden = true
			continue
		# 基本技巧卡住：需要進階技巧或試誤
		return Difficulty.EXPERT if clues < 28 else Difficulty.HARD

	if used_hidden or clues < 36:
		return Difficulty.MEDIUM
	return Difficulty.EASY


## 檢查盤面是否為完整且合法的數獨解
static func is_valid_solution(grid: Array) -> bool:
	for v in grid:
		if int(v) == 0:
			return false
	var solver := Solver.new()
	return solver.reset(grid)


static func box_of(i: int) -> int:
	return (i / 27) * 3 + ((i % 9) / 3)


static func popcount(m: int) -> int:
	var n := 0
	while m != 0:
		m &= m - 1
		n += 1
	return n


static func lowest_digit(mask: int) -> int:
	for d in range(1, 10):
		if (mask & (1 << (d - 1))) != 0:
			return d
	return 0


## 回傳 0~80 的隨機排列（使用指定 rng，確保可重現）
static func shuffled_range(rng: RandomNumberGenerator) -> Array[int]:
	var arr: Array[int] = []
	for i in 81:
		arr.append(i)
	for j in range(80, 0, -1):
		var k := rng.randi_range(0, j)
		var t := arr[j]
		arr[j] = arr[k]
		arr[k] = t
	return arr


## 27 個單元（9 列、9 行、9 宮）的索引清單
static func unit_indices() -> Array:
	var units: Array = []
	for r in 9:
		var row: Array[int] = []
		for c in 9:
			row.append(r * 9 + c)
		units.append(row)
	for c in 9:
		var col: Array[int] = []
		for r in 9:
			col.append(r * 9 + c)
		units.append(col)
	for b in 9:
		var box: Array[int] = []
		var base := (b / 3) * 27 + (b % 3) * 3
		for dr in 3:
			for dc in 3:
				box.append(base + dr * 9 + dc)
		units.append(box)
	return units


static func _apply_hidden_singles(cells: Array[int], solver: Solver) -> int:
	var placed := 0
	for unit in unit_indices():
		for d in range(1, 10):
			var bit := 1 << (d - 1)
			var spot := -1
			var n := 0
			var already := false
			for i in unit:
				if cells[i] == d:
					already = true
					break
				if cells[i] == 0 and (solver.candidates(i) & bit) != 0:
					n += 1
					spot = i
			if not already and n == 1 and cells[spot] == 0:
				cells[spot] = d
				placed += 1
	return placed


## 位元遮罩回溯解題器。
## count()：計算解的數量（提早停在 limit，用來驗證唯一解）。
## solve_random()：從空盤隨機填出一個完整合法盤面（產生器用）。
class Solver:
	var cells: Array[int] = []
	var rows: Array[int] = []
	var cols: Array[int] = []
	var boxes: Array[int] = []

	var _count := 0
	var _limit := 1
	var _rng: RandomNumberGenerator = null
	var _capture := false
	var _found: Array[int] = []

	## 載入盤面並重建遮罩；有衝突（同列/行/宮重複）時回傳 false
	func reset(grid: Array) -> bool:
		cells.clear()
		for v in grid:
			cells.append(int(v))
		if cells.size() != 81:
			return false
		rows.resize(9)
		rows.fill(0)
		cols.resize(9)
		cols.fill(0)
		boxes.resize(9)
		boxes.fill(0)
		for i in 81:
			var v := cells[i]
			if v == 0:
				continue
			var bit := 1 << (v - 1)
			var r := i / 9
			var c := i % 9
			var b := SudokuLogic.box_of(i)
			if (rows[r] & bit) != 0 or (cols[c] & bit) != 0 or (boxes[b] & bit) != 0:
				return false
			rows[r] |= bit
			cols[c] |= bit
			boxes[b] |= bit
		return true

	## 第 i 格目前可填數字的位元遮罩
	func candidates(i: int) -> int:
		return SudokuLogic.ALL_MASK & ~(rows[i / 9] | cols[i % 9] | boxes[SudokuLogic.box_of(i)])

	## 計算解的數量，最多數到 limit 即停止
	func count(grid: Array, limit: int) -> int:
		if not reset(grid):
			return 0
		_count = 0
		_limit = limit
		_capture = false
		_rng = null
		_search()
		return _count

	## 從空盤隨機產生一個完整解
	func solve_random(rng: RandomNumberGenerator) -> Array[int]:
		var empty: Array[int] = []
		empty.resize(81)
		reset(empty)
		_count = 0
		_limit = 1
		_capture = true
		_rng = rng
		_search()
		return _found

	func _search() -> void:
		if _count >= _limit:
			return
		# MRV：挑候選數最少的空格，大幅減少分支
		var best := -1
		var best_mask := 0
		var best_n := 10
		for i in 81:
			if cells[i] != 0:
				continue
			var m := candidates(i)
			var n := SudokuLogic.popcount(m)
			if n == 0:
				return
			if n < best_n:
				best_n = n
				best = i
				best_mask = m
				if n == 1:
					break
		if best == -1:
			_count += 1
			if _capture:
				_found = cells.duplicate()
			return
		var digits := _digits_of(best_mask)
		if _rng != null:
			for j in range(digits.size() - 1, 0, -1):
				var k := _rng.randi_range(0, j)
				var t := digits[j]
				digits[j] = digits[k]
				digits[k] = t
		var r := best / 9
		var c := best % 9
		var b := SudokuLogic.box_of(best)
		for d in digits:
			var bit := 1 << (d - 1)
			cells[best] = d
			rows[r] |= bit
			cols[c] |= bit
			boxes[b] |= bit
			_search()
			cells[best] = 0
			rows[r] &= ~bit
			cols[c] &= ~bit
			boxes[b] &= ~bit
			if _count >= _limit:
				return

	func _digits_of(mask: int) -> Array[int]:
		var out: Array[int] = []
		for d in range(1, 10):
			if (mask & (1 << (d - 1))) != 0:
				out.append(d)
		return out
