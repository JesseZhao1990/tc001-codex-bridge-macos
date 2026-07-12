# TC001 Codex Bridge for macOS - Panduan penggunaan lengkap

[← README](README.id.md) | [English usage guide](../USAGE.md)

## Instalasi dan koneksi

1. Jalankan `./run-tests.sh` dan `./build.sh`.
2. Buka `dist/TC001 Bridge.app` dan izinkan Bluetooth serta jaringan lokal.
3. Pilih Otomatis, Wi-Fi, atau Bluetooth.
4. Untuk Wi-Fi masukkan IP atau `awtrix.local`; untuk Bluetooth tunggu AWTRIX-BLE tersambung.
5. Aktifkan pemantauan Codex otomatis dan uji warna lampu.
6. Atur lima halaman bawaan AWTRIX sesuai kebutuhan.

## Arti tampilan

Batang kiri 1x8 menunjukkan sisa 5 jam dan kanan sisa 7 hari. 5H tampil 7 detik dan 7D 3 detik. Kuning berarti diam, hijau bekerja, biru menunggu konfirmasi, dan merah kesalahan.

## Pemecahan masalah

Jika BLE tidak muncul, periksa firmware 0.98-ble.4, izin, dan pasangan lama. Untuk Wi-Fi pastikan Mac dapat mencapai TC001. Jika kuota kosong, pastikan Codex sudah masuk lalu tunggu pembaruan.

## Privasi dan keamanan

Tidak ada telemetri atau server proyek. Aplikasi hanya membaca status Codex lokal dan mengirim piksel hasil render serta pengaturan halaman ke TC001. API lokal hanya pada 127.0.0.1 dan menolak permintaan dari browser.

## Lisensi

Aplikasi macOS menggunakan lisensi MIT. Proyek ini tidak berafiliasi atau didukung oleh OpenAI, Codex, Ulanzi, AWTRIX, atau Blueforcer.

[Lisensi](../../LICENSE)
