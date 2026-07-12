# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Panduan penggunaan lengkap](USAGE.id.md)

## Ringkasan

TC001 Codex Bridge adalah aplikasi macOS native yang menampilkan sisa batas Codex 5 jam dan 7 hari serta status kerja pada Ulanzi TC001. Aplikasi mendukung AWTRIX melalui HTTP dan Bluetooth dari firmware pendamping.

## Fitur utama

Aplikasi menampilkan dua batang kuota, nilai 5H/7D bergantian, dan lampu status empat warna. Halaman waktu, tanggal, suhu, kelembapan, dan baterai juga dapat diatur. Analisis Codex dilakukan secara lokal di Mac.

## Persyaratan

Memerlukan macOS 13 atau lebih baru, Codex Desktop atau CLI yang sudah masuk, dan TC001 dengan AWTRIX 3. Bluetooth memerlukan firmware awtrix3-ble.

## Mulai cepat

1. Jalankan `./run-tests.sh` dan `./build.sh`.
2. Buka `dist/TC001 Bridge.app` dan izinkan Bluetooth serta jaringan lokal.
3. Pilih Otomatis, Wi-Fi, atau Bluetooth.

- Untuk Wi-Fi masukkan IP atau `awtrix.local`; untuk Bluetooth tunggu AWTRIX-BLE tersambung.
- Aktifkan pemantauan Codex otomatis dan uji warna lampu.
- Atur lima halaman bawaan AWTRIX sesuai kebutuhan.

## Privasi dan keamanan

Tidak ada telemetri atau server proyek. Aplikasi hanya membaca status Codex lokal dan mengirim piksel hasil render serta pengaturan halaman ke TC001. API lokal hanya pada 127.0.0.1 dan menolak permintaan dari browser.

## Lisensi

Aplikasi macOS menggunakan lisensi MIT. Proyek ini tidak berafiliasi atau didukung oleh OpenAI, Codex, Ulanzi, AWTRIX, atau Blueforcer.

[Lisensi](../../LICENSE)
