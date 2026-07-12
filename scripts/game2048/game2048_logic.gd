class_name Game2048Logic
extends RefCounted
## 2048 核心邏輯：滑動合併、生成新磚、勝負判定。
## 盤面以 Array[int]（長度 16，0 = 空）表示，索引 = 列 * 4 + 行。
## 不依賴任何 UI，可 headless 測試。

const SIZE := 4
const CELLS := SIZE * SIZE

enum { DIR_LEFT, DIR_RIGHT, DIR_UP, DIR_DOWN }


static func new_grid() -> Array[int]:
	var g: Array[int] = []
	g.resize(CELLS)
	return g


## 滑動一步（就地修改 grid）。回傳 { "moved": bool, "gained": int }
static func slide(grid: Array[int], dir: int) -> Dictionary:
	var moved := false
	var gained := 0
	for idx in _line_indices(dir):
		var vals: Array[int] = []
		for i in idx:
			if grid[i] != 0:
				vals.append(grid[i])
		var merged := _merge_line(vals)
		var line: Array = merged["line"]
		gained += int(merged["gained"])
		for k in SIZE:
			var v: int = line[k] if k < line.size() else 0
			if grid[idx[k]] != v:
				moved = true
			grid[idx[k]] = v
	return {"moved": moved, "gained": gained}


## 一條線的合併：相鄰同值合併一次（[2,2,2,2] → [4,4]）
static func _merge_line(vals: Array[int]) -> Dictionary:
	var out: Array[int] = []
	var gained := 0
	var i := 0
	while i < vals.size():
		if i + 1 < vals.size() and vals[i] == vals[i + 1]:
			out.append(vals[i] * 2)
			gained += vals[i] * 2
			i += 2
		else:
			out.append(vals[i])
			i += 1
	return {"line": out, "gained": gained}


## 各方向的掃描順序：每條線由「滑動目的地」往來源排
static func _line_indices(dir: int) -> Array:
	var lines: Array = []
	for a in SIZE:
		var idx: Array[int] = []
		for b in SIZE:
			match dir:
				DIR_LEFT:
					idx.append(a * SIZE + b)
				DIR_RIGHT:
					idx.append(a * SIZE + (SIZE - 1 - b))
				DIR_UP:
					idx.append(b * SIZE + a)
				_:
					idx.append((SIZE - 1 - b) * SIZE + a)
		lines.append(idx)
	return lines


## 在隨機空格生成新磚（90% 出 2、10% 出 4）。回傳格子索引，-1 = 無空格
static func spawn(grid: Array[int], rng: RandomNumberGenerator) -> int:
	var empty: Array[int] = []
	for i in CELLS:
		if grid[i] == 0:
			empty.append(i)
	if empty.is_empty():
		return -1
	var i: int = empty[rng.randi_range(0, empty.size() - 1)]
	grid[i] = 4 if rng.randf() < 0.1 else 2
	return i


## 還有沒有可行的移動（有空格或相鄰同值）
static func can_move(grid: Array[int]) -> bool:
	for i in CELLS:
		if grid[i] == 0:
			return true
		if i % SIZE < SIZE - 1 and grid[i] == grid[i + 1]:
			return true
		if i < CELLS - SIZE and grid[i] == grid[i + SIZE]:
			return true
	return false


static func max_tile(grid: Array[int]) -> int:
	var best := 0
	for v in grid:
		best = maxi(best, v)
	return best
