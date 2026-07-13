extends Node
## 存檔管理（Autoload：SaveManager）
## 所有進度與統計存在單一 JSON：user://save.json，結構見 docs/02_Architecture.md。
## 平台原則：所有遊戲共用這套存檔 API，新遊戲只新增自己的 section，不改動既有結構。

const SAVE_PATH := "user://save.json"

var data: Dictionary = {}
## 實際使用的存檔路徑：自動化測試以 BRAINCLUB_SAVE 環境變數改用獨立檔案，
## 避免污染玩家的真實進度
var _path := SAVE_PATH


func _ready() -> void:
	var override := OS.get_environment("BRAINCLUB_SAVE")
	if override != "":
		_path = override
	reload()


func reload() -> void:
	data = {}
	if FileAccess.file_exists(_path):
		var f := FileAccess.open(_path, FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				data = parsed
	_migrate_in_progress()


## v0.7 以前全平台只有一格進行中存檔（"in_progress"），v0.8 起每款遊戲各自一格。
## 舊存檔自動搬到新結構，玩家進度不會遺失。
func _migrate_in_progress() -> void:
	var old: Variant = data.get("in_progress")
	if old is Dictionary and (old as Dictionary).has("game"):
		section("in_progress_games")[String(old["game"])] = old
		data.erase("in_progress")
		save()


func save() -> void:
	var f := FileAccess.open(_path, FileAccess.WRITE)
	if f != null:
		f.store_string(JSON.stringify(data, "\t"))


## 取得（必要時建立）一個資料區塊，例如 section("sudoku_stats")
func section(key: String) -> Dictionary:
	if not (data.get(key) is Dictionary):
		data[key] = {}
	return data[key]


# ---- 進行中的遊戲（v0.8 起每款遊戲各自一格，可同時掛多局） ----

func get_in_progress(game: String) -> Dictionary:
	var all: Variant = data.get("in_progress_games")
	if all is Dictionary:
		var v: Variant = (all as Dictionary).get(game)
		if v is Dictionary:
			return v
	return {}


## 傳入空字典代表清除該遊戲的進度
func set_in_progress(game: String, state: Dictionary) -> void:
	var all := section("in_progress_games")
	if state.is_empty():
		all.erase(game)
	else:
		all[game] = state
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
	Achievements.refresh()


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
	Achievements.refresh()


func sudoku_stats() -> Dictionary:
	return section("sudoku_stats")
