# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Tam kullanım kılavuzu](USAGE.tr.md)

## Genel bakış

TC001 Codex Bridge, Codex'in 5 saatlik ve 7 günlük kalan limitini ve çalışma durumunu Ulanzi TC001 üzerinde gösteren yerel bir macOS uygulamasıdır. AWTRIX HTTP ve yardımcı firmware'in Bluetooth aktarımını destekler.

## Temel özellikler

İki kota çubuğu, dönüşümlü 5H/7D değerleri ve dört renkli durum lambası gösterir. Saat, tarih, sıcaklık, nem ve pil sayfaları da ayarlanabilir. Codex analizi Mac üzerinde yerel olarak yapılır.

## Gereksinimler

macOS 13 veya sonrası, oturum açılmış Codex Desktop ya da CLI ve AWTRIX 3 çalıştıran TC001 gerekir. Bluetooth için awtrix3-ble yardımcı firmware'i zorunludur.

## Hızlı başlangıç

1. `./run-tests.sh` ve `./build.sh` komutlarını çalıştırın.
2. `dist/TC001 Bridge.app` uygulamasını açıp Bluetooth ve yerel ağ izinlerini verin.
3. Otomatik, Wi-Fi veya Bluetooth seçin.

- Wi-Fi için IP ya da `awtrix.local` girin; Bluetooth için AWTRIX-BLE bağlantısını bekleyin.
- Codex otomatik izlemeyi açın ve lamba renklerini test edin.
- Beş yerleşik AWTRIX sayfasını gerektiği gibi ayarlayın.

## Gizlilik ve güvenlik

Telemetri veya proje sunucusu yoktur. Uygulama yalnızca yerel Codex durumunu okur ve TC001'e işlenmiş pikseller ile sayfa ayarlarını gönderir. Yerel API 127.0.0.1 üzerinde dinler ve tarayıcı Origin isteklerini reddeder.

## Lisans

macOS uygulaması MIT lisanslıdır. Proje OpenAI, Codex, Ulanzi, AWTRIX veya Blueforcer ile bağlantılı ya da onlar tarafından onaylı değildir.

[Lisans](../../LICENSE)
