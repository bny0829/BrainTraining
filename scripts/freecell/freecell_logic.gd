class_name FreecellLogic
extends RefCounted
## 新接龍（FreeCell）核心邏輯：發牌、疊牌規則、整段搬移上限、勝利判定。
## 牌的表示法與接龍共用（SolitaireLogic：0~51、花色/點數/紅黑）。
## 特性：52 張全部明牌、幾乎所有牌局都有解 → 適合每日挑戰。

const CASCADES := 8
const FREE_CELLS := 4


## 發一副新牌：前 4 列 7 張、後 4 列 6 張，全部明牌。
## 回傳 { "cascades": [8 疊], "free": [4 個 -1], "foundations": [4 疊] }
static func new_deal(rng: RandomNumberGenerator) -> Dictionary:
	var deck: Array[int] = []
	for i in SolitaireLogic.CARDS:
		deck.append(i)
	for j in range(SolitaireLogic.CARDS - 1, 0, -1):
		var k := rng.randi_range(0, j)
		var t := deck[j]
		deck[j] = deck[k]
		deck[k] = t
	var cascades: Array = []
	var pos := 0
	for c in CASCADES:
		var n := 7 if c < 4 else 6
		var col: Array[int] = deck.slice(pos, pos + n)
		cascades.append(col)
		pos += n
	var free: Array[int] = [-1, -1, -1, -1]
	var foundations: Array = [[], [], [], []]
	return {"cascades": cascades, "free": free, "foundations": foundations}


## 一段牌是否為合法連續段（遞減、紅黑交錯）
static func is_valid_run(cards: Array) -> bool:
	for i in range(1, cards.size()):
		if not SolitaireLogic.can_stack(int(cards[i]), int(cards[i - 1])):
			return false
	return true


## 整段搬移上限 =（空自由格數 + 1）× 2^空列數；搬到空列時該列不計入
static func max_run_size(free_slots: int, empty_cascades: int, to_empty: bool) -> int:
	var empties := empty_cascades - 1 if to_empty else empty_cascades
	return (free_slots + 1) * int(pow(2.0, maxi(0, empties)))


static func count_free_slots(free: Array) -> int:
	var n := 0
	for v in free:
		if int(v) < 0:
			n += 1
	return n


static func count_empty_cascades(cascades: Array) -> int:
	var n := 0
	for col in cascades:
		if (col as Array).is_empty():
			n += 1
	return n
