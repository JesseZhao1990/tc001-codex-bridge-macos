# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Guide d'utilisation complet](USAGE.fr.md)

## Présentation

TC001 Codex Bridge est une application macOS native qui affiche sur un Ulanzi TC001 les quotas Codex sur 5 heures et 7 jours ainsi que l'état de travail. Elle prend en charge AWTRIX par HTTP et le transport Bluetooth du micrologiciel associé.

## Fonctions principales

L'application affiche deux barres de quota, les valeurs 5H/7D en alternance et un voyant à quatre couleurs. Elle configure aussi les pages heure, date, température, humidité et batterie. L'analyse de Codex reste locale au Mac.

## Prérequis

macOS 13 ou ultérieur, Codex Desktop ou CLI connecté, et un TC001 sous AWTRIX 3 sont requis. Le Bluetooth nécessite le micrologiciel awtrix3-ble associé.

## Démarrage rapide

1. Exécutez `./run-tests.sh` puis `./build.sh`.
2. Ouvrez `dist/TC001 Bridge.app` et accordez les autorisations Bluetooth et réseau local.
3. Choisissez le transport Automatique, Wi-Fi ou Bluetooth.

- En Wi-Fi, saisissez l'adresse IP ou `awtrix.local`; en Bluetooth, attendez la connexion AWTRIX-BLE.
- Activez la surveillance automatique de Codex et testez les couleurs du voyant.
- Réglez les cinq pages AWTRIX intégrées selon vos besoins.

## Confidentialité et sécurité

Aucune télémétrie ni serveur de projet n'est utilisé. L'application lit uniquement l'état local de Codex et envoie au TC001 des pixels rendus et des réglages de pages. L'API locale écoute sur 127.0.0.1 et refuse les requêtes provenant d'un navigateur.

## Licence

L'application macOS est sous licence MIT. Ce projet n'est ni affilié ni approuvé par OpenAI, Codex, Ulanzi, AWTRIX ou Blueforcer.

[Licence](../../LICENSE)
