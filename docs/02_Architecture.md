# 02 系統架構

*更新：2026-07-12（v0.1）*

## 一、整體結構

```
main.tscn（唯一場景）
└── Main（scripts/main.gd）畫面路由 + 套用 AppTheme
    ├── HomeScreen   首頁（每日挑戰、續玩、遊戲清單、戰績）
    └── SudokuScreen 數獨畫面（之後：GomokuScreen、ReversiScreen…）

Autoload（全域單例）
├── SaveManager  user://save.json 讀寫、戰績、進行中遊戲
└── Daily        每日挑戰種子、難度輪替、連續天數
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

- 每款遊戲用自己的 section（`sudoku_stats`、`gomoku_stats`…），**不修改別人的結構**。
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

## 五、AI 模組規劃（v0.2+）

五子棋與黑白棋共用一套對戰 AI 介面：

```
GameState 介面：合法手列舉 / 落子 / 勝負判定 / 局面評分
     ↓
Minimax + Alpha-Beta（難度 = 深度 + 評分函數雜訊）
     ↓
之後視需要升級 MCTS
```

難度分級策略：Beginner（深度 1 + 隨機性）→ Expert（深度 4+、完整評分）。

## 六、測試

| 測試 | 指令 | 涵蓋 |
| --- | --- | --- |
| 邏輯單元測試 | `--headless --script res://tests/test_sudoku_logic.gd` | 產生器唯一解、種子重現性、難度評估 |
| 全流程自動測試 | `BRAINCLUB_AUTOTEST=1` + `--headless` 執行 | 首頁、輸入、筆記、錯誤、復原、提示、存檔續玩 |

慣例：**每款新遊戲的 logic 必須有單元測試**；autotest 隨功能擴充。
