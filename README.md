# Brain Club（暫名）

一人團隊長期經營的**益智遊戲平台**：不是單一數獨 App，而是一個所有遊戲共用「每日挑戰、存檔、統計、UI 風格」的平台，每次更新新增一款經典遊戲。

**目前版本：v0.3** — 平台首頁 + 數獨 + 五子棋 + 黑白棋（皆含 4 級 AI 難度）+ 成就系統 + 每日挑戰三遊戲輪替。

## 如何執行

1. 開啟 Godot 4.x（`C:\Godot_v4.7-stable_win64.exe`）
2. 「匯入」→ 選擇本資料夾的 `project.godot`
3. 按 F5 執行

命令列直接執行（不開編輯器）：

```powershell
C:\Godot_v4.7-stable_win64.exe --path C:\Benny\Coding\MobileGame\BrainTraining
```

## 如何測試

```powershell
# 數獨邏輯單元測試（產生器、唯一解、同種子重現）
C:\Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/test_sudoku_logic.gd

# 五子棋邏輯單元測試（勝負判定、AI 即勝/防守、AI 對弈、效能）
C:\Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/test_gomoku_logic.gd

# 黑白棋邏輯單元測試（合法手、翻轉、跳過與終局、AI 對弈、效能）
C:\Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/test_reversi_logic.gd

# 成就判定單元測試
C:\Godot_v4.7-stable_win64.exe --headless --path . --script res://tests/test_achievements.gd

# 全流程自動化測試（模擬玩家操作；BRAINCLUB_SAVE 讓測試用獨立存檔，不污染真實進度）
$env:BRAINCLUB_AUTOTEST = "1"
$env:BRAINCLUB_SAVE = "user://save_autotest.json"
C:\Godot_v4.7-stable_win64.exe --headless --path .
Remove-Item Env:BRAINCLUB_AUTOTEST, Env:BRAINCLUB_SAVE
```

兩者最後都會印出 `PASS`，結束代碼 0。

## 專案結構

| 路徑 | 內容 |
| --- | --- |
| `autoload/` | 全域單例：`SaveManager`（存檔）、`Daily`（每日挑戰） |
| `scenes/main.tscn` | 唯一的場景檔，進入點 |
| `scripts/main.gd` | 畫面路由（首頁 ⇄ 遊戲） |
| `scripts/home_screen.gd` | 平台首頁 |
| `scripts/ui/` | 共用 UI：色票主題（`AppTheme`）、對話框（`OverlayDialog`） |
| `scripts/sudoku/` | 數獨：核心演算法、棋盤繪製、遊戲畫面 |
| `scripts/gomoku/` | 五子棋：AI（Negamax + Alpha-Beta）、棋盤繪製、遊戲畫面 |
| `scripts/reversi/` | 黑白棋：AI（位置權重 + 行動力）、棋盤繪製、遊戲畫面 |
| `scripts/achievement_defs.gd` | 成就定義與判定（純函式）；`achievement_screen.gd` 為清單畫面 |
| `tests/` | 單元測試與自動化操作測試 |
| `docs/` | 專案文件（見下） |

## 文件

| 文件 | 內容 |
| --- | --- |
| [01_Project_Overview.md](docs/01_Project_Overview.md) | 產品定位、版本路線圖、商業模式、上架注意事項 |
| [02_Architecture.md](docs/02_Architecture.md) | 系統架構、存檔格式、新增遊戲 SOP |
| [03_Game_Design_Sudoku.md](docs/03_Game_Design_Sudoku.md) | 數獨玩法規格與每日挑戰設計 |
| [04_Conventions.md](docs/04_Conventions.md) | 程式碼規範與專案原則 |
| [05_Game_Design_Gomoku.md](docs/05_Game_Design_Gomoku.md) | 五子棋玩法規格與 AI 設計 |
| [06_Game_Design_Reversi.md](docs/06_Game_Design_Reversi.md) | 黑白棋玩法規格與 AI 設計 |

## 技術選型

- **引擎：Godot 4.x**（GDScript）。純 2D 棋盤／UI 類遊戲，Godot 開發效率最高、APK 最小。
- **上架 iOS？** Godot 可匯出 iOS。不論用 Godot 或 Unity，上架 App Store 都需要 Mac + Xcode + Apple Developer 帳號（US$99/年），門檻在 Apple 而非引擎。核心演算法（產生器、AI、難度分析）為純邏輯，必要時可平移到任何引擎。
- **資料：** 本機 JSON（`user://save.json`），v0.1 完全離線、零伺服器成本。
