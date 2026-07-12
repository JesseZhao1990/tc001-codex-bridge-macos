# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Vollständige Anleitung](USAGE.de.md)

## Überblick

TC001 Codex Bridge ist eine native macOS-App, die Codex-Kontingente für 5 Stunden und 7 Tage sowie den Arbeitsstatus auf einem Ulanzi TC001 anzeigt. Sie unterstützt AWTRIX über HTTP und den Bluetooth-Transport der Begleit-Firmware.

## Hauptfunktionen

Die App zeigt zwei Kontingentbalken, wechselnde 5H/7D-Werte und eine vierfarbige Statusampel. Außerdem lassen sich Zeit-, Datums-, Temperatur-, Feuchtigkeits- und Batterieseite konfigurieren. Die Codex-Auswertung bleibt lokal auf dem Mac.

## Voraussetzungen

Erforderlich sind macOS 13 oder neuer, eine angemeldete Codex-Desktop-App oder CLI und ein TC001 mit AWTRIX 3. Für Bluetooth wird die Begleit-Firmware awtrix3-ble benötigt.

## Schnellstart

1. Führe `./run-tests.sh` und `./build.sh` aus.
2. Öffne `dist/TC001 Bridge.app` und erlaube Bluetooth sowie lokales Netzwerk.
3. Wähle Automatisch, Wi-Fi oder Bluetooth.

- Gib bei Wi-Fi die IP oder `awtrix.local` ein; warte bei Bluetooth auf AWTRIX-BLE.
- Aktiviere die automatische Codex-Überwachung und teste die Lampenfarben.
- Konfiguriere die fünf eingebauten AWTRIX-Seiten nach Bedarf.

## Datenschutz und Sicherheit

Es gibt keine Telemetrie und keinen Projektserver. Die App liest nur lokalen Codex-Status und sendet gerenderte Pixel sowie Seiteneinstellungen an den TC001. Die lokale API bindet an 127.0.0.1 und lehnt Browser-Ursprünge ab.

## Lizenz

Die macOS-App steht unter der MIT-Lizenz. Das Projekt ist nicht mit OpenAI, Codex, Ulanzi, AWTRIX oder Blueforcer verbunden oder von ihnen unterstützt.

[Lizenz](../../LICENSE)
