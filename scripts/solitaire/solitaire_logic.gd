class_name SolitaireLogic
extends RefCounted
## 接龍（Klondike）核心邏輯：發牌、疊牌規則、勝利判定。
## 牌以 0~51 的整數表示：花色 = id / 13（0黑桃 1紅心 2方塊 3梅花）、點數 = id % 13（0 = A、12 = K）。
## 不依賴任何 UI，可 headless 測試。

const CARDS := 52
const COLUMNS := 7

const RANK_TEXT := ["A", "2", "3", "4", "5", "6", "7", "8", "9", "10", "J", "Q", "K"]

enum { SPADE, HEART, DIAMOND, CLUB }


static func suit_of(id: int) -> int:
	return id / 13


static func rank_of(id: int) -> int:
	return id % 13


static func is_red(id: int) -> bool:
	var s := suit_of(id)
	return s == HEART or s == DIAMOND


## 發一副新牌。回傳：
## { "stock": Array[int]（從尾端抽）, "waste": [], "foundations": [4 疊],
##   "columns": [7 疊], "face_up": [7 個尾端翻開張數] }
static func new_deal(rng: RandomNumberGenerator) -> Dictionary:
	var deck: Array[int] = []
	for i in CARDS:
		deck.append(i)
	for j in range(CARDS - 1, 0, -1):
		var k := rng.randi_range(0, j)
		var t := deck[j]
		deck[j] = deck[k]
		deck[k] = t
	var columns: Array = []
	var face_up: Array[int] = []
	var pos := 0
	for c in COLUMNS:
		var col: Array[int] = []
		for n in c + 1:
			col.append(deck[pos])
			pos += 1
		columns.append(col)
		face_up.append(1)
	var stock: Array[int] = deck.slice(pos)
	var waste: Array[int] = []
	var foundations: Array = [[], [], [], []]
	return {
		"stock": stock,
		"waste": waste,
		"foundations": foundations,
		"columns": columns,
		"face_up": face_up,
	}


## 牌桌疊牌：點數遞減、紅黑交錯
static func can_stack(card: int, onto: int) -> bool:
	return rank_of(card) == rank_of(onto) - 1 and is_red(card) != is_red(onto)


## 基礎堆：同花色由 A 往上疊
static func can_foundation(card: int, pile: Array) -> bool:
	if pile.is_empty():
		return rank_of(card) == 0
	var top := int(pile[-1])
	return suit_of(card) == suit_of(top) and rank_of(card) == rank_of(top) + 1


static func is_won(foundations: Array) -> bool:
	var total := 0
	for pile in foundations:
		total += (pile as Array).size()
	return total == CARDS
