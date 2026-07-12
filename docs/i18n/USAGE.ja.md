# TC001 Codex Bridge for macOS - 詳しい使い方

[← README](README.ja.md) | [English usage guide](../USAGE.md)

## インストールと接続

1. `./run-tests.sh` と `./build.sh` を実行します。
2. `dist/TC001 Bridge.app` を開き、Bluetooth とローカルネットワークを許可します。
3. 自動、Wi-Fi、Bluetooth のいずれかを選びます。
4. Wi-Fi では IP または `awtrix.local` を入力し、Bluetooth では AWTRIX-BLE の接続を待ちます。
5. Codex 自動監視を有効にし、ランプのテストを行います。
6. 必要に応じて 5 つの AWTRIX 内蔵ページを設定します。

## 表示の意味

左の 1x8 バーは 5 時間残量、右は 7 日残量です。5H は 7 秒、7D は 3 秒表示されます。黄は待機、緑は作業中、青は確認待ち、赤はエラーです。

## トラブルシューティング

BLE が見つからない場合はファームウェア 0.98-ble.4、権限、古いペアリングを確認します。Wi-Fi では Mac から TC001 に到達できるか確認します。残量が出ない場合は Codex のログインを確認して更新を待ちます。

## プライバシーとセキュリティ

テレメトリやプロジェクト運営サーバーはありません。アプリはローカル Codex 状態だけを読み、描画済みピクセルとページ設定だけを TC001 に送ります。ローカル API は 127.0.0.1 のみで、ブラウザー由来の要求を拒否します。

## ライセンス

macOS アプリは MIT ライセンスです。本プロジェクトは OpenAI、Codex、Ulanzi、AWTRIX、Blueforcer の公式製品・提携・推奨ではありません。

[ライセンス](../../LICENSE)
