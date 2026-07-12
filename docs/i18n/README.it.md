# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Guida completa](USAGE.it.md)

## Panoramica

TC001 Codex Bridge è un'app macOS nativa che mostra su Ulanzi TC001 i limiti Codex di 5 ore e 7 giorni e lo stato di lavoro. Supporta AWTRIX via HTTP e il trasporto Bluetooth del firmware associato.

## Funzioni principali

Mostra due barre di quota, valori 5H/7D alternati e un indicatore a quattro colori. Consente anche di configurare le pagine ora, data, temperatura, umidità e batteria. L'analisi Codex avviene localmente sul Mac.

## Requisiti

Richiede macOS 13 o successivo, Codex Desktop o CLI con accesso effettuato e un TC001 con AWTRIX 3. Per Bluetooth serve il firmware awtrix3-ble.

## Avvio rapido

1. Esegui `./run-tests.sh` e `./build.sh`.
2. Apri `dist/TC001 Bridge.app` e consenti Bluetooth e rete locale.
3. Scegli Automatico, Wi-Fi o Bluetooth.

- Per Wi-Fi inserisci IP o `awtrix.local`; per Bluetooth attendi AWTRIX-BLE.
- Attiva il monitoraggio automatico Codex e prova i colori dell'indicatore.
- Configura le cinque pagine AWTRIX integrate secondo necessità.

## Privacy e sicurezza

Non esistono telemetria o server del progetto. L'app legge solo lo stato Codex locale e invia al TC001 pixel renderizzati e impostazioni delle pagine. L'API locale ascolta su 127.0.0.1 e rifiuta richieste con origine browser.

## Licenza

L'app macOS usa la licenza MIT. Il progetto non è affiliato né approvato da OpenAI, Codex, Ulanzi, AWTRIX o Blueforcer.

[Licenza](../../LICENSE)
