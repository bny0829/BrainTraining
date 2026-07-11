class_name GomokuLogic
extends RefCounted
## 五子棋核心邏輯：勝負判定、候選手產生、局面評估與 AI（Negamax + Alpha-Beta）。
## 盤面以 Array[int]（長度 225，0 = 空、1 = 黑、2 = 白）表示，索引 = 列 * 15 + 行。
## 不依賴任何 UI；choose_move 可在背景執行緒呼叫。

const SIZE := 15
const CELLS := SIZE * SIZE
const EMPTY := 0
const BLACK := 1
const WHITE := 2

const WIN_SCORE := 100000000.0

enum Difficulty { BEGINNER, NORMAL, HARD, EXPERT }

const DIFFICULTY_TEXT := {
	Difficulty.BEGINNER: "初學",
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

## 各難度的搜尋深度與候選手寬度
const SEARCH_DEPTH := {
	Difficulty.NORMAL: 1,
	Difficulty.HARD: 2,
	Difficulty.EXPERT: 3,
}

const DIRS := [[1, 0], [0, 1], [1, 1], [1, -1]]


static func opponent(p: int) -> int:
	return BLACK + WHITE - p


static func idx(x: int, y: int) -> int:
	return y * SIZE + x


static func is_full(board: Array[int]) -> bool:
	for v in board:
		if v == EMPTY:
			return false
	return true


## 檢查通過 last（最後一手）的四個方向是否形成五連
static func check_win(board: Array[int], last: int) -> bool:
	if last < 0 or board[last] == EMPTY:
		return false
	var p := board[last]
	var x := last % SIZE
	var y := last / SIZE
	for dir in DIRS:
		var n := 1
		for s in [1, -1]:
			var dx: int = dir[0] * s
			var dy: int = dir[1] * s
			var cx := x + dx
			var cy := y + dy
			while cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and board[idx(cx, cy)] == p:
				n += 1
				cx += dx
				cy += dy
		if n >= 5:
			return true
	return false


## 候選手：距離任一棋子 2 格以內的空點（空盤時下中央）
static func candidates(board: Array[int]) -> Array[int]:
	var near: Dictionary = {}
	var any_stone := false
	for i in CELLS:
		if board[i] == EMPTY:
			continue
		any_stone = true
		var x := i % SIZE
		var y := i / SIZE
		for dy in range(-2, 3):
			for dx in range(-2, 3):
				var cx := x + dx
				var cy := y + dy
				if cx < 0 or cx >= SIZE or cy < 0 or cy >= SIZE:
					continue
				var j := idx(cx, cy)
				if board[j] == EMPTY:
					near[j] = true
	if not any_stone:
		return [idx(7, 7)]
	var out: Array[int] = []
	for k in near.keys():
		out.append(k)
	return out


## 在 i 落子 p 的即時價值（四個方向的連線型態分數總和）。
## 用於候選手排序與初學/普通難度的貪婪決策。
static func point_score(board: Array[int], i: int, p: int) -> float:
	var x := i % SIZE
	var y := i / SIZE
	var total := 0.0
	for dir in DIRS:
		var count := 1
		var open := 0
		for s in [1, -1]:
			var dx: int = dir[0] * s
			var dy: int = dir[1] * s
			var cx := x + dx
			var cy := y + dy
			while cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and board[idx(cx, cy)] == p:
				count += 1
				cx += dx
				cy += dy
			if cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and board[idx(cx, cy)] == EMPTY:
				open += 1
		total += _pattern_score(count, open)
	return total


## count = 落子後的連線長度、open = 兩端的開放數
static func _pattern_score(count: int, open: int) -> float:
	if count >= 5:
		return WIN_SCORE
	if open == 0:
		return 0.0
	match count:
		4:
			return 1000000.0 if open == 2 else 100000.0
		3:
			return 10000.0 if open == 2 else 500.0
		2:
			return 200.0 if open == 2 else 20.0
		_:
			return 10.0 if open == 2 else 2.0


## 全盤評估（player 視角）：掃描所有 5 連窗口。
## 只含單方棋子的窗口依棋子數計分；混雜窗口無價值。
static func evaluate(board: Array[int], player: int) -> float:
	var opp := opponent(player)
	var mine := 0.0
	var theirs := 0.0
	for dir in DIRS:
		var dx: int = dir[0]
		var dy: int = dir[1]
		for y in SIZE:
			for x in SIZE:
				var ex := x + dx * 4
				var ey := y + dy * 4
				if ex < 0 or ex >= SIZE or ey < 0 or ey >= SIZE:
					continue
				var a := 0
				var b := 0
				for k in 5:
					var v := board[idx(x + dx * k, y + dy * k)]
					if v == player:
						a += 1
					elif v == opp:
						b += 1
				if a > 0 and b > 0:
					continue
				if a > 0:
					mine += _window_score(a)
				elif b > 0:
					theirs += _window_score(b)
	# 輕微偏防守：對手的威脅看得比自己的機會重一點
	return mine - theirs * 1.1


static func _window_score(n: int) -> float:
	match n:
		1:
			return 1.0
		2:
			return 20.0
		3:
			return 400.0
		4:
			return 8000.0
		_:
			return WIN_SCORE


## AI 決策入口。board 會被暫時修改但保證還原。
static func choose_move(board: Array[int], player: int, difficulty: int, rng: RandomNumberGenerator) -> int:
	var cands := candidates(board)
	if cands.is_empty():
		return -1
	if cands.size() == 1:
		return cands[0]
	var opp := opponent(player)

	# 1) 有即勝點直接下
	for c in cands:
		board[c] = player
		var win := check_win(board, c)
		board[c] = EMPTY
		if win:
			return c

	# 2) 擋對手的即勝點（初學者三成機率漏看）
	var block := -1
	for c in cands:
		board[c] = opp
		var w := check_win(board, c)
		board[c] = EMPTY
		if w:
			block = c
			break
	if block >= 0 and (difficulty != Difficulty.BEGINNER or rng.randf() < 0.7):
		return block

	# 3) 候選手依「進攻 + 防守」熱度排序
	var scored: Array = []
	for c in cands:
		var s := point_score(board, c, player) + 0.9 * point_score(board, c, opp)
		scored.append([s, c])
	scored.sort_custom(func(a, b): return a[0] > b[0])

	if difficulty == Difficulty.BEGINNER:
		var top := mini(3, scored.size())
		return scored[rng.randi_range(0, top - 1)][1]

	var depth := int(SEARCH_DEPTH[difficulty])
	var width := 10 if difficulty == Difficulty.HARD else 8
	return _best_by_search(board, player, scored, depth, width)


static func _best_by_search(board: Array[int], player: int, scored: Array, depth: int, width: int) -> int:
	var best_c := int(scored[0][1])
	var alpha := -INF
	var n := mini(width, scored.size())
	for k in n:
		var c := int(scored[k][1])
		board[c] = player
		var v: float
		if check_win(board, c):
			v = WIN_SCORE
		else:
			v = -_search(board, opponent(player), depth - 1, -INF, -alpha)
		board[c] = EMPTY
		if v > alpha:
			alpha = v
			best_c = c
	return best_c


## Negamax + Alpha-Beta，回傳 player 視角的分數
static func _search(board: Array[int], player: int, depth: int, alpha: float, beta: float) -> float:
	if depth <= 0:
		return evaluate(board, player)
	var cands := candidates(board)
	if cands.is_empty():
		return 0.0
	var scored: Array = []
	var opp := opponent(player)
	for c in cands:
		var s := point_score(board, c, player) + 0.9 * point_score(board, c, opp)
		scored.append([s, c])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var best := -INF
	var n := mini(8, scored.size())
	for k in n:
		var c := int(scored[k][1])
		board[c] = player
		var v: float
		if check_win(board, c):
			# 加上 depth 讓越快的獲勝分數越高
			v = WIN_SCORE + depth
		else:
			v = -_search(board, opp, depth - 1, -beta, -alpha)
		board[c] = EMPTY
		if v > best:
			best = v
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best
