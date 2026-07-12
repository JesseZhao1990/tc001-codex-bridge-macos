# TC001 Codex Bridge for macOS - 完整使用說明

[← README](README.zh-TW.md) | [English usage guide](../USAGE.md)

## 安裝與連線

1. 執行 `./run-tests.sh` 與 `./build.sh`。
2. 開啟 `dist/TC001 Bridge.app`，允許藍牙與區域網路權限。
3. 在設定中選擇自動、Wi-Fi 或藍牙。
4. Wi-Fi 模式輸入裝置 IP 或 `awtrix.local`；藍牙模式等待 AWTRIX-BLE 裝置連線。
5. 啟用 Codex 自動監測，並用狀態燈測試按鈕確認畫面。
6. 依需要設定五個 AWTRIX 內建頁面開關。

## 顯示含義

左側 1x8 燈條代表 5 小時餘額，右側代表 7 天餘額。5H 顯示 7 秒，7D 顯示 3 秒。黃色為閒置、綠色為工作中、藍色為等待確認、紅色為錯誤。

## 疑難排解

找不到藍牙裝置時請確認韌體 0.98-ble.4、系統藍牙權限與舊配對紀錄；Wi-Fi 失敗時確認 Mac 與 TC001 網路互通；沒有額度時確認 Codex 已登入並等待更新。

## 隱私與安全

專案沒有遙測或自建伺服器。應用程式只讀取本機 Codex 狀態，並向 TC001 傳送渲染後的像素與頁面開關。本機介面只監聽 127.0.0.1，並拒絕瀏覽器來源請求。

## 授權條款

macOS 應用程式採用 MIT 授權。專案與 OpenAI、Codex、Ulanzi、AWTRIX 或 Blueforcer 沒有官方隸屬或背書關係。

[授權條款](../../LICENSE)
