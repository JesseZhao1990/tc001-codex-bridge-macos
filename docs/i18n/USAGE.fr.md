# TC001 Codex Bridge for macOS - Guide d'utilisation complet

[← README](README.fr.md) | [English usage guide](../USAGE.md)

## Installation et connexion

1. Exécutez `./run-tests.sh` puis `./build.sh`.
2. Ouvrez `dist/TC001 Bridge.app` et accordez les autorisations Bluetooth et réseau local.
3. Choisissez le transport Automatique, Wi-Fi ou Bluetooth.
4. En Wi-Fi, saisissez l'adresse IP ou `awtrix.local`; en Bluetooth, attendez la connexion AWTRIX-BLE.
5. Activez la surveillance automatique de Codex et testez les couleurs du voyant.
6. Réglez les cinq pages AWTRIX intégrées selon vos besoins.

## Signification de l'affichage

La barre 1x8 gauche représente le quota restant sur 5 heures et celle de droite le quota sur 7 jours. 5H s'affiche 7 secondes et 7D 3 secondes. Jaune signifie inactif, vert en cours, bleu en attente de confirmation et rouge erreur.

## Dépannage

Si le périphérique BLE est absent, vérifiez le micrologiciel 0.98-ble.4, les autorisations et les anciens jumelages. Pour le Wi-Fi, vérifiez la connectivité entre Mac et TC001. Sans quota, confirmez la connexion Codex et attendez l'actualisation.

## Confidentialité et sécurité

Aucune télémétrie ni serveur de projet n'est utilisé. L'application lit uniquement l'état local de Codex et envoie au TC001 des pixels rendus et des réglages de pages. L'API locale écoute sur 127.0.0.1 et refuse les requêtes provenant d'un navigateur.

## Licence

L'application macOS est sous licence MIT. Ce projet n'est ni affilié ni approuvé par OpenAI, Codex, Ulanzi, AWTRIX ou Blueforcer.

[Licence](../../LICENSE)
