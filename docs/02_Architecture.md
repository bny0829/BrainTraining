# 02 系統架構

*更新：2026-07-12（v0.1）*

## 一、整體結構

```
main.tscn（唯一場景）
└── Main（scripts/main.gd）畫面路由 + 套用 AppTheme
    ├── HomeScreen        首頁（每日挑戰、續玩、遊戲清單、成就入口、戰績）
    ├── SudokuScreen      數獨
    ├── GomokuScreen      五子棋
    ├── ReversiScreen     黑白棋
    └── AchievementScreen 成就清單

Autoload（全域單例）
├── SaveManager   user://save.json 讀寫、戰績、進行中遊戲（BRAINCLUB_SAVE 可換測試存檔）
├── Daily         每日挑戰輪替表（星期→遊戲+難度）、種子、連續天數
├── Achievements  成就解鎖紀錄與通知（定義在 scripts/achievement_defs.gd，純函式可測試）
└── Sfx           程式合成音效（正弦波+包絡，零音檔）；全域按鈕音在 Main 以 node_added 掛勾
```

設計決策：

- **UI 以程式建構**，只有 `main.tscn` 一個場景檔。v0.1 求迭代速度與版本控制乾淨；等 UI 穩定後若需要視覺編輯再抽成 .tscn。
- **畫面切換**走 `Main.instance.goto_home()` / `open_sudoku(config)`。新遊戲＝在 Main 加一個 `open_xxx()`。
- **核心演算法與 UI 完全分離**：`sudoku_logic.gd` 不依賴任何節點，可直接在 headless 測試、未來可搬到伺服器批次產題。

## 二、每日挑戰管線（零伺服器）

```
日期 → 種子（20260712）→ SudokuLogic.generate(難度, rng)
                              ↓
                    全球玩家同一天同一題
星期幾 → 難度輪替（一簡單…六專家）
完成 → Daily.mark_completed() → streak +1（斷一天歸零重算）
```

## 三、存檔格式（user://save.json）

```jsonc
{
  "sudoku_stats": {
    "played": 10, "won": 8,
    "best_0": 245        // 各難度最佳秒數，key = "best_" + difficulty
  },
  "daily": {
    "last_completed": "2026-07-12",
    "streak": 3, "best_streak": 7
  },
  "in_progress": {       // 進行中的一局（全平台同時只保留一局）
    "game": "sudoku", "mode": "daily", "difficulty": 2,
    "date": "2026-07-12",          // daily 專用，跨日即作廢
    "values": [/*81*/], "given": [/*81*/], "errors": [/*81*/], "notes": [/*81*/],
    "solution": [/*81*/], "mistakes": 1, "seconds": 130, "hints": 0
  }
}
```

規則：

- 每款遊戲用自己的 section（`sudoku_stats`、`gomoku_stats`…），**不修改別人的結構**。新遊戲一律用通用 API `SaveManager.record_result(game, difficulty, won)` 與 `stats(game)`。
- 五子棋的 `in_progress` 只存 `moves` 落子序列，還原＝重播（資料量小且不易壞檔）。
- JSON 讀回的數字都是 float，用 `_to_int_array()` 之類的輔助函式轉回。
- 每一步操作即存檔（檔案很小，行動裝置可承受），程式被系統殺掉也不掉進度。

## 四、新增一款遊戲的 SOP

以五子棋為例：

1. `scripts/gomoku/gomoku_logic.gd` — 規則 + AI（純邏輯，不碰 UI）
2. `scripts/gomoku/gomoku_board.gd` — 棋盤繪製（參考 `sudoku_board.gd` 的單一 Control 畫法）
3. `scripts/gomoku/gomoku_screen.gd` — 畫面與流程
4. `main.gd` 加 `open_gomoku(config)`；`home_screen.gd` 把卡片改為可用
5. `Daily` 支援多遊戲輪替（屆時再擴充，例如週一數獨、週二五子棋）
6. `tests/` 加對應測試
7. **不允許**為了新遊戲修改既有遊戲的程式

## 五、對戰 AI 模組（v0.2 已落地於五子棋）

```
候選手產生（既有棋子附近的空點）
     ↓
型態分數排序（進攻 + 防守加權）
     ↓
即勝 / 必擋 檢查（短路，不進搜尋）
     ↓
Negamax + Alpha-Beta（難度 = 深度 0～3 + 候選寬度 + 隨機性）
     ↓
背景 Thread 執行，_process 輪詢，離開畫面必 wait_to_finish()
```

黑白棋（v0.3）重用同一結構：換走子規則（夾吃）與評估函數（角/邊權重 + 行動力），搜尋框架不變。之後視需要升級 MCTS。

## 五之一、每日挑戰的多遊戲輪替（v0.3 已實作）

`Daily.ROTATION`：星期幾 → { game, difficulty }。數獨看「日期種子同題」、棋類看「當日指定難度獲勝」；`in_progress.date` 過期作廢機制不變。週六為數獨專家（週末 Boss）。

## 五之二、成就系統（v0.3 已實作）

- 定義：`scripts/achievement_defs.gd`，宣告式條件（存檔[section][key] ≥ min，可 AND 多條件），純函式可 headless 測試。
- 解鎖：`Achievements.refresh()` 在戰績寫入與每日完成後被呼叫；新解鎖存入存檔 `achievements` section（id → 日期）並彈出頂部通知。
- 新增成就 = 在 `all_defs()` 加一筆資料，不用動任何流程。
- **注意**：autoload 內的程式不能被 `--script` 測試 preload（autoload 識別字在該模式下無法編譯）——可測試的邏輯一律放 `scripts/` 純類別。
- **多語系陷阱（v0.8.1 修正）**：Godot 的 `internationalization/locale/fallback` 專案設定預設值是 `"en"`。若原文字串就是中文（沒有另外準備 zh_TW 翻譯表），玩家裝置語言只要不是英文，`tr()` 找不到對應語言的翻譯表時會直接套用這個回退語言的翻譯表，而不是顯示原文——導致中文裝置預設反而顯示英文。已在 `project.godot` 明確設定 `locale/fallback="zh_TW"` 修正。日後若新增其他語言的翻譯表，此設定要一併確認。
- **字元選用陷阱**：組合字串中的分隔符號一律用 `·`（U+00B7 MIDDLE DOT），不要用「・」（U+30FB 日文假名中點）——後者在部分 Android 裝置的內建字型缺字，會顯示成方框亂碼。

## 六、測試

| 測試 | 指令 | 涵蓋 |
| --- | --- | --- |
| 邏輯單元測試 | `--headless --script res://tests/test_sudoku_logic.gd` | 產生器唯一解、種子重現性、難度評估 |
| 全流程自動測試 | `BRAINCLUB_AUTOTEST=1` + `--headless` 執行 | 首頁、輸入、筆記、錯誤、復原、提示、存檔續玩 |

慣例：**每款新遊戲的 logic 必須有單元測試**；autotest 隨功能擴充。
