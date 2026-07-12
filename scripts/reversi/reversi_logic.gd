class_name ReversiLogic
extends RefCounted
## 黑白棋核心邏輯：合法手、翻棋、終局計數與 AI。
## 重用五子棋的搜尋框架（Negamax + Alpha-Beta），換成黑白棋的走子規則與評估函數
## （位置權重 + 行動力，終盤改看子數）。
## 盤面以 Array[int]（長度 64，0 = 空、1 = 黑、2 = 白）表示，索引 = 列 * 8 + 行。

const SIZE := 8
const CELLS := SIZE * SIZE
const EMPTY := 0
const BLACK := 1
const WHITE := 2

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

const DIRS8 := [[1, 0], [-1, 0], [0, 1], [0, -1], [1, 1], [1, -1], [-1, 1], [-1, -1]]

## 經典位置權重表：角最值錢、角旁（X/C 位）最危險
const WEIGHTS := [
	100, -25, 10, 5, 5, 10, -25, 100,
	-25, -50, -2, -2, -2, -2, -50, -25,
	10, -2, 1, 1, 1, 1, -2, 10,
	5, -2, 1, 1, 1, 1, -2, 5,
	5, -2, 1, 1, 1, 1, -2, 5,
	10, -2, 1, 1, 1, 1, -2, 10,
	-25, -50, -2, -2, -2, -2, -50, -25,
	100, -25, 10, 5, 5, 10, -25, 100,
]


static func opponent(p: int) -> int:
	return BLACK + WHITE - p


static func idx(x: int, y: int) -> int:
	return y * SIZE + x


static func initial_board() -> Array[int]:
	var b: Array[int] = []
	b.resize(CELLS)
	b[idx(3, 3)] = WHITE
	b[idx(4, 4)] = WHITE
	b[idx(3, 4)] = BLACK
	b[idx(4, 3)] = BLACK
	return b


## 在 i 落子 p 會翻轉的所有棋子；空陣列 = 非法手
static func flips_for(board: Array[int], p: int, i: int) -> Array[int]:
	if board[i] != EMPTY:
		return []
	var out: Array[int] = []
	var x := i % SIZE
	var y := i / SIZE
	var opp := opponent(p)
	for d in DIRS8:
		var dx: int = d[0]
		var dy: int = d[1]
		var cx := x + dx
		var cy := y + dy
		var line: Array[int] = []
		while cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE and board[idx(cx, cy)] == opp:
			line.append(idx(cx, cy))
			cx += dx
			cy += dy
		if not line.is_empty() and cx >= 0 and cx < SIZE and cy >= 0 and cy < SIZE \
				and board[idx(cx, cy)] == p:
			out.append_array(line)
	return out


static func legal_moves(board: Array[int], p: int) -> Array[int]:
	var out: Array[int] = []
	for i in CELLS:
		if not flips_for(board, p, i).is_empty():
			out.append(i)
	return out


static func has_move(board: Array[int], p: int) -> bool:
	for i in CELLS:
		if not flips_for(board, p, i).is_empty():
			return true
	return false


## 落子並翻棋（flips 由 flips_for 取得）
static func apply_move(board: Array[int], p: int, i: int, flips: Array[int]) -> void:
	board[i] = p
	for f in flips:
		board[f] = p


## 回傳 [黑子數, 白子數]
static func count(board: Array[int]) -> Array[int]:
	var black := 0
	var white := 0
	for v in board:
		if v == BLACK:
			black += 1
		elif v == WHITE:
			white += 1
	return [black, white]


static func empties(board: Array[int]) -> int:
	var n := 0
	for v in board:
		if v == EMPTY:
			n += 1
	return n


## 局面評估（player 視角）：中盤 = 位置權重 + 行動力差，終盤（≤10 空格）看子數
static func evaluate(board: Array[int], player: int) -> float:
	var opp := opponent(player)
	var pos := 0.0
	var mine := 0
	var theirs := 0
	var empty_n := 0
	for i in CELLS:
		var v := board[i]
		if v == player:
			pos += WEIGHTS[i]
			mine += 1
		elif v == opp:
			pos -= WEIGHTS[i]
			theirs += 1
		else:
			empty_n += 1
	if empty_n == 0:
		return float(mine - theirs) * 1000.0
	if empty_n <= 10:
		return float(mine - theirs) * 100.0 + pos
	var mob := legal_moves(board, player).size() - legal_moves(board, opp).size()
	return pos + mob * 8.0


## AI 決策入口。board 會被暫時修改但保證還原。
## 回傳 -1 = 無合法手（跳過回合）。
static func choose_move(board: Array[int], player: int, difficulty: int, rng: RandomNumberGenerator) -> int:
	var moves := legal_moves(board, player)
	if moves.is_empty():
		return -1
	if moves.size() == 1:
		return moves[0]

	if difficulty == Difficulty.BEGINNER:
		return moves[rng.randi_range(0, moves.size() - 1)]

	var depth: int
	match difficulty:
		Difficulty.NORMAL:
			depth = 1
		Difficulty.HARD:
			depth = 3
		_:
			depth = 4
	# 專家級在殘局改為算到底（空格少、分支小，可精確計算）
	if difficulty == Difficulty.EXPERT and empties(board) <= 8:
		depth = empties(board)

	# 依位置權重排序，讓 Alpha-Beta 更快剪枝
	moves.sort_custom(func(a, b): return WEIGHTS[a] > WEIGHTS[b])

	var best_c := moves[0]
	var alpha := -INF
	for m in moves:
		var fl := flips_for(board, player, m)
		apply_move(board, player, m, fl)
		var v := -_search(board, opponent(player), depth - 1, -INF, -alpha)
		_undo_move(board, player, m, fl)
		if v > alpha:
			alpha = v
			best_c = m
	return best_c


static func _undo_move(board: Array[int], p: int, i: int, flips: Array[int]) -> void:
	board[i] = EMPTY
	var opp := opponent(p)
	for f in flips:
		board[f] = opp


## Negamax + Alpha-Beta，含「無子可下則跳過」規則
static func _search(board: Array[int], player: int, depth: int, alpha: float, beta: float) -> float:
	if depth <= 0:
		return evaluate(board, player)
	var moves := legal_moves(board, player)
	if moves.is_empty():
		if not has_move(board, opponent(player)):
			# 終局：以子數差給決定性分數
			var c := count(board)
			var diff := c[0] - c[1] if player == BLACK else c[1] - c[0]
			return signf(diff) * 100000.0 + diff
		return -_search(board, opponent(player), depth - 1, -beta, -alpha)
	moves.sort_custom(func(a, b): return WEIGHTS[a] > WEIGHTS[b])
	var best := -INF
	for m in moves:
		var fl := flips_for(board, player, m)
		apply_move(board, player, m, fl)
		var v := -_search(board, opponent(player), depth - 1, -beta, -alpha)
		_undo_move(board, player, m, fl)
		if v > best:
			best = v
		if best > alpha:
			alpha = best
		if alpha >= beta:
			break
	return best
