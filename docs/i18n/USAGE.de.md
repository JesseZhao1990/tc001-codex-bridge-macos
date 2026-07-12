# TC001 Codex Bridge for macOS - Vollständige Anleitung

[← README](README.de.md) | [English usage guide](../USAGE.md)

## Installation und Verbindung

1. Führe `./run-tests.sh` und `./build.sh` aus.
2. Öffne `dist/TC001 Bridge.app` und erlaube Bluetooth sowie lokales Netzwerk.
3. Wähle Automatisch, Wi-Fi oder Bluetooth.
4. Gib bei Wi-Fi die IP oder `awtrix.local` ein; warte bei Bluetooth auf AWTRIX-BLE.
5. Aktiviere die automatische Codex-Überwachung und teste die Lampenfarben.
6. Konfiguriere die fünf eingebauten AWTRIX-Seiten nach Bedarf.

## Bedeutung der Anzeige

Der linke 1x8-Balken zeigt das 5-Stunden-Restkontingent, der rechte das 7-Tage-Kontingent. 5H erscheint 7 Sekunden, 7D 3 Sekunden. Gelb ist inaktiv, Grün arbeitet, Blau wartet auf Bestätigung und Rot meldet einen Fehler.

## Fehlerbehebung

Fehlt das BLE-Gerät, prüfe Firmware 0.98-ble.4, Berechtigungen und alte Kopplungen. Bei Wi-Fi muss der TC001 vom Mac erreichbar sein. Fehlen Kontingente, prüfe die Codex-Anmeldung und warte auf die Aktualisierung.

## Datenschutz und Sicherheit

Es gibt keine Telemetrie und keinen Projektserver. Die App liest nur lokalen Codex-Status und sendet gerenderte Pixel sowie Seiteneinstellungen an den TC001. Die lokale API bindet an 127.0.0.1 und lehnt Browser-Ursprünge ab.

## Lizenz

Die macOS-App steht unter der MIT-Lizenz. Das Projekt ist nicht mit OpenAI, Codex, Ulanzi, AWTRIX oder Blueforcer verbunden oder von ihnen unterstützt.

[Lizenz](../../LICENSE)
