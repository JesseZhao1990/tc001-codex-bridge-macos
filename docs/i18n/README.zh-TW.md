# TC001 Codex Bridge for macOS

[← English](../../README.md) | [完整使用說明](USAGE.zh-TW.md)

## 簡介

TC001 Codex Bridge 是原生 macOS 應用程式，可將 Codex 的 5 小時、7 天額度與工作狀態顯示在 Ulanzi TC001。它支援 AWTRIX HTTP，也支援配套韌體提供的藍牙連線。

## 主要功能

應用程式會顯示左右額度燈條、5H/7D 交替數字與四色狀態燈，並可設定時間、日期、溫度、濕度及電量頁面。所有 Codex 狀態分析都在 Mac 本機完成。

## 系統需求

需要 macOS 13 或更新版本、已登入的 Codex 桌面程式或 CLI，以及執行 AWTRIX 3 的 TC001。使用藍牙時必須安裝 awtrix3-ble 配套韌體。

## 快速開始

1. 執行 `./run-tests.sh` 與 `./build.sh`。
2. 開啟 `dist/TC001 Bridge.app`，允許藍牙與區域網路權限。
3. 在設定中選擇自動、Wi-Fi 或藍牙。

- Wi-Fi 模式輸入裝置 IP 或 `awtrix.local`；藍牙模式等待 AWTRIX-BLE 裝置連線。
- 啟用 Codex 自動監測，並用狀態燈測試按鈕確認畫面。
- 依需要設定五個 AWTRIX 內建頁面開關。

## 隱私與安全

專案沒有遙測或自建伺服器。應用程式只讀取本機 Codex 狀態，並向 TC001 傳送渲染後的像素與頁面開關。本機介面只監聽 127.0.0.1，並拒絕瀏覽器來源請求。

## 授權條款

macOS 應用程式採用 MIT 授權。專案與 OpenAI、Codex、Ulanzi、AWTRIX 或 Blueforcer 沒有官方隸屬或背書關係。

[授權條款](../../LICENSE)
