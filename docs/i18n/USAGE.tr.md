# TC001 Codex Bridge for macOS - Tam kullanım kılavuzu

[← README](README.tr.md) | [English usage guide](../USAGE.md)

## Kurulum ve bağlantı

1. `./run-tests.sh` ve `./build.sh` komutlarını çalıştırın.
2. `dist/TC001 Bridge.app` uygulamasını açıp Bluetooth ve yerel ağ izinlerini verin.
3. Otomatik, Wi-Fi veya Bluetooth seçin.
4. Wi-Fi için IP ya da `awtrix.local` girin; Bluetooth için AWTRIX-BLE bağlantısını bekleyin.
5. Codex otomatik izlemeyi açın ve lamba renklerini test edin.
6. Beş yerleşik AWTRIX sayfasını gerektiği gibi ayarlayın.

## Ekran anlamı

Sol 1x8 çubuk 5 saatlik, sağ çubuk 7 günlük kalan kotayı gösterir. 5H 7 saniye, 7D 3 saniye görünür. Sarı boşta, yeşil çalışıyor, mavi onay bekliyor, kırmızı hata demektir.

## Sorun giderme

BLE görünmüyorsa 0.98-ble.4 firmware'ini, izinleri ve eski eşleşmeleri denetleyin. Wi-Fi için Mac ile TC001 erişimini doğrulayın. Kota yoksa Codex oturumunu kontrol edip yenilemeyi bekleyin.

## Gizlilik ve güvenlik

Telemetri veya proje sunucusu yoktur. Uygulama yalnızca yerel Codex durumunu okur ve TC001'e işlenmiş pikseller ile sayfa ayarlarını gönderir. Yerel API 127.0.0.1 üzerinde dinler ve tarayıcı Origin isteklerini reddeder.

## Lisans

macOS uygulaması MIT lisanslıdır. Proje OpenAI, Codex, Ulanzi, AWTRIX veya Blueforcer ile bağlantılı ya da onlar tarafından onaylı değildir.

[Lisans](../../LICENSE)
