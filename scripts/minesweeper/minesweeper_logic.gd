class_name MinesweeperLogic
extends RefCounted
## 踩地雷核心邏輯：佈雷（首挖保證安全）、連鎖翻開、勝利判定。
## 不依賴任何 UI；盤面以一維陣列表示，索引 = 列 * 寬 + 行。

enum Difficulty { BEGINNER, NORMAL, HARD, EXPERT }

const DIFFICULTY_TEXT := {
	Difficulty.BEGINNER: "初級",
	Difficulty.NORMAL: "普通",
	Difficulty.HARD: "困難",
	Difficulty.EXPERT: "專家",
}

const DIFFICULTY_STARS := {
	Difficulty.BEGINNER: "★☆☆☆",
	Difficulty.NORMAL: "★★☆☆",
	Difficulty.HARD: "★★★☆",
	Difficulty.EXPERT: "★★★★",
}

## 盤面規格（直向手機以正方形為主）
const CONFIG := {
	Difficulty.BEGINNER: {"w": 9, "h": 9, "mines": 10},
	Difficulty.NORMAL: {"w": 12, "h": 12, "mines": 24},
	Difficulty.HARD: {"w": 14, "h": 14, "mines": 40},
	Difficulty.EXPERT: {"w": 16, "h": 16, "mines": 55},
}


static func neighbors(w: int, h: int, i: int) -> Array[int]:
	var out: Array[int] = []
	var x := i % w
	var y := i / w
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var cx := x + dx
			var cy := y + dy
			if cx >= 0 and cx < w and cy >= 0 and cy < h:
				out.append(cy * w + cx)
	return out


## 佈雷：safe（第一下挖的格子）與其周圍保證無雷（空間足夠時）。
## 回傳 { "mines": Array[bool], "counts": Array[int]（地雷格為 -1） }
static func generate(w: int, h: int, mine_count: int, rng: RandomNumberGenerator, safe: int) -> Dictionary:
	var cells := w * h
	var excluded := {safe: true}
	if cells - mine_count > 9:
		for n in neighbors(w, h, safe):
			excluded[n] = true
	var candidates: Array[int] = []
	for i in cells:
		if not excluded.has(i):
			candidates.append(i)
	for j in range(candidates.size() - 1, 0, -1):
		var k := rng.randi_range(0, j)
		var t := candidates[j]
		candidates[j] = candidates[k]
		candidates[k] = t
	var mines: Array[bool] = []
	mines.resize(cells)
	for m in mini(mine_count, candidates.size()):
		mines[candidates[m]] = true
	var counts: Array[int] = []
	counts.resize(cells)
	for i in cells:
		if mines[i]:
			counts[i] = -1
			continue
		var n := 0
		for j in neighbors(w, h, i):
			if mines[j]:
				n += 1
		counts[i] = n
	return {"mines": mines, "counts": counts}


## 由 start 連鎖翻開（start 不可為地雷）：0 格自動擴散。
## 直接修改 revealed，回傳本次新翻開的格子。
static func flood_reveal(w: int, h: int, mines: Array[bool], counts: Array[int],
		revealed: Array[bool], flagged: Array[bool], start: int) -> Array[int]:
	var opened: Array[int] = []
	var queue: Array[int] = [start]
	while not queue.is_empty():
		var i: int = queue.pop_back()
		if revealed[i] or flagged[i] or mines[i]:
			continue
		revealed[i] = true
		opened.append(i)
		if counts[i] == 0:
			for j in neighbors(w, h, i):
				if not revealed[j]:
					queue.append(j)
	return opened


## 勝利 = 所有非地雷格都已翻開
static func is_win(mines: Array[bool], revealed: Array[bool]) -> bool:
	for i in mines.size():
		if not mines[i] and not revealed[i]:
			return false
	return true


static func flag_count(flagged: Array[bool]) -> int:
	var n := 0
	for f in flagged:
		if f:
			n += 1
	return n
