extends Node
## 存檔管理（Autoload：SaveManager）
## 所有進度與統計存在單一 JSON：user://save.json，結構見 docs/02_Architecture.md。
## 平台原則：所有遊戲共用這套存檔 API，新遊戲只新增自己的 section，不改動既有結構。

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}


func _ready() -> void:
	reload()


func reload() -> void:
	data = {}
	if FileAccess.file_exists(SAVE_PATH):
		var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				data = parsed


func save() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## 取得（必要時建立）一個資料區塊，例如 section("sudoku_stats")
func section(key: String) -> Dictionary:
	if not (data.get(key) is Dictionary):
		data[key] = {}
	return data[key]


# ---- 進行中的遊戲（全平台同時只保留一局） ----

func get_in_progress() -> Dictionary:
	var v: Variant = data.get("in_progress")
	return v if v is Dictionary else {}


## 傳入空字典代表清除
func set_in_progress(state: Dictionary) -> void:
	if state.is_empty():
		data.erase("in_progress")
	else:
		data["in_progress"] = state
	save()


# ---- 通用戰績（所有新遊戲一律用這組 API） ----

func record_result(game: String, difficulty: int, won: bool) -> void:
	var s := section(game + "_stats")
	s["played"] = int(s.get("played", 0)) + 1
	if won:
		s["won"] = int(s.get("won", 0)) + 1
		var key := "won_%d" % difficulty
		s[key] = int(s.get(key, 0)) + 1
	save()


func stats(game: String) -> Dictionary:
	return section(game + "_stats")


# ---- 數獨戰績 ----

func record_sudoku_result(difficulty: int, seconds: int, won: bool) -> void:
	var s := section("sudoku_stats")
	s["played"] = int(s.get("played", 0)) + 1
	if won:
		s["won"] = int(s.get("won", 0)) + 1
		var key := "best_%d" % difficulty
		var best := int(s.get(key, 0))
		if best == 0 or seconds < best:
			s[key] = seconds
	save()


func sudoku_stats() -> Dictionary:
	return section("sudoku_stats")
