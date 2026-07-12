# TC001 Codex Bridge for macOS

[← English](../../README.md) | [詳しい使い方](USAGE.ja.md)

## 概要

TC001 Codex Bridge は、Codex の 5 時間・7 日間の残量と稼働状態を Ulanzi TC001 に表示するネイティブ macOS アプリです。AWTRIX HTTP と、専用ファームウェアの Bluetooth 転送に対応します。

## 主な機能

左右の残量バー、交互に表示される 5H/7D の数値、4 色の状態ランプを表示します。時刻、日付、温度、湿度、バッテリーページも設定できます。Codex の解析はすべて Mac 内で行われます。

## 要件

macOS 13 以降、ログイン済みの Codex Desktop または CLI、AWTRIX 3 を実行する TC001 が必要です。Bluetooth には awtrix3-ble ファームウェアが必要です。

## クイックスタート

1. `./run-tests.sh` と `./build.sh` を実行します。
2. `dist/TC001 Bridge.app` を開き、Bluetooth とローカルネットワークを許可します。
3. 自動、Wi-Fi、Bluetooth のいずれかを選びます。

- Wi-Fi では IP または `awtrix.local` を入力し、Bluetooth では AWTRIX-BLE の接続を待ちます。
- Codex 自動監視を有効にし、ランプのテストを行います。
- 必要に応じて 5 つの AWTRIX 内蔵ページを設定します。

## プライバシーとセキュリティ

テレメトリやプロジェクト運営サーバーはありません。アプリはローカル Codex 状態だけを読み、描画済みピクセルとページ設定だけを TC001 に送ります。ローカル API は 127.0.0.1 のみで、ブラウザー由来の要求を拒否します。

## ライセンス

macOS アプリは MIT ライセンスです。本プロジェクトは OpenAI、Codex、Ulanzi、AWTRIX、Blueforcer の公式製品・提携・推奨ではありません。

[ライセンス](../../LICENSE)
