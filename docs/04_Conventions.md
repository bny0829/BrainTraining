# 04 程式碼規範與專案原則

*更新：2026-07-12（v0.1）*

## 一、專案原則（最重要，違反前先停下來想）

1. 所有遊戲共用 UI 風格（只從 `AppTheme` 取色與樣式）
2. 所有遊戲共用存檔（`SaveManager`，各自的 section）
3. 所有遊戲共用每日挑戰機制（`Daily`）
4. 核心演算法不依賴 UI（logic 檔案不 import 任何節點）
5. 每款遊戲可獨立更新，新增遊戲**不修改既有遊戲的程式**
6. AI／產生器模組化，可跨遊戲重用
7. 每款遊戲的 logic 必有 headless 單元測試
8. 完全離線優先；雲端功能（排行榜、登入）永遠是可選的附加層

## 二、GDScript 風格

- 縮排：Tab。命名：類別 `PascalCase`、函式與變數 `snake_case`、常數 `CONSTANT_CASE`、私有成員 `_` 前綴。
- 一律使用型別註記與 `:=` 推斷；回傳型別必寫（`-> void`）。
- 檔案開頭用 `##` 文件註解說明「這個檔案負責什麼、不負責什麼」。
- 註解寫「為什麼」，不寫「做了什麼」。
- 訊號用 `signal xxx(arg: Type)` 定義；連接一律 `pressed.connect(_on_xxx)` 或 `.bind()`，**避免在字典常值裡寫多行 lambda**（GDScript 解析器不支援）。

## 三、檔案與命名

| 類型 | 位置 | 範例 |
| --- | --- | --- |
| 遊戲邏輯 | `scripts/<game>/<game>_logic.gd` | `sudoku_logic.gd` |
| 棋盤繪製 | `scripts/<game>/<game>_board.gd` | `sudoku_board.gd` |
| 遊戲畫面 | `scripts/<game>/<game>_screen.gd` | `sudoku_screen.gd` |
| 共用 UI | `scripts/ui/` | `app_theme.gd` |
| 全域單例 | `autoload/` | `save_manager.gd` |
| 測試 | `tests/` | `test_sudoku_logic.gd` |

## 四、Git 規範

- Commit 格式：`類型: 摘要`，類型 = `feat` / `fix` / `refactor` / `docs` / `test` / `chore`
  - 例：`feat: 五子棋 Minimax AI（4 級難度）`
- 每個版本（v0.2、v0.3…）開分支開發，完成後合回 main 並打 tag。
- `.godot/` 與匯出成品不進版控（見 `.gitignore`）。

## 五、發布前檢查（每版必跑）

1. 兩個 headless 測試 PASS
2. 桌面實際玩過：新局 × 4 難度、每日挑戰、續玩、失敗流程
3. 手機直向解析度檢查（720×1280 視窗）
4. 更新 `docs/` 與 README 的版本資訊
