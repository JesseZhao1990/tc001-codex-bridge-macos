# TC001 Codex Bridge for macOS - Guida completa

[← README](README.it.md) | [English usage guide](../USAGE.md)

## Installazione e connessione

1. Esegui `./run-tests.sh` e `./build.sh`.
2. Apri `dist/TC001 Bridge.app` e consenti Bluetooth e rete locale.
3. Scegli Automatico, Wi-Fi o Bluetooth.
4. Per Wi-Fi inserisci IP o `awtrix.local`; per Bluetooth attendi AWTRIX-BLE.
5. Attiva il monitoraggio automatico Codex e prova i colori dell'indicatore.
6. Configura le cinque pagine AWTRIX integrate secondo necessità.

## Significato del display

La barra sinistra 1x8 indica la quota residua di 5 ore e quella destra la quota di 7 giorni. 5H appare per 7 secondi e 7D per 3. Giallo è inattivo, verde al lavoro, blu in attesa di conferma e rosso errore.

## Risoluzione dei problemi

Se BLE non appare, controlla firmware 0.98-ble.4, permessi e vecchi abbinamenti. Per Wi-Fi verifica la raggiungibilità tra Mac e TC001. Se manca la quota, controlla l'accesso a Codex e attendi l'aggiornamento.

## Privacy e sicurezza

Non esistono telemetria o server del progetto. L'app legge solo lo stato Codex locale e invia al TC001 pixel renderizzati e impostazioni delle pagine. L'API locale ascolta su 127.0.0.1 e rifiuta richieste con origine browser.

## Licenza

L'app macOS usa la licenza MIT. Il progetto non è affiliato né approvato da OpenAI, Codex, Ulanzi, AWTRIX o Blueforcer.

[Licenza](../../LICENSE)
