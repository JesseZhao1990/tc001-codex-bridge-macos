# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Guía de uso completa](USAGE.es.md)

## Descripción

TC001 Codex Bridge es una aplicación nativa para macOS que muestra en un Ulanzi TC001 los límites de 5 horas y 7 días de Codex, además de su estado de trabajo. Admite AWTRIX por HTTP y el transporte Bluetooth del firmware complementario.

## Funciones principales

Muestra barras laterales de cuota, valores 5H/7D alternos y un semáforo de cuatro colores. También permite configurar las páginas de hora, fecha, temperatura, humedad y batería. El análisis de Codex se realiza localmente en el Mac.

## Requisitos

Requiere macOS 13 o posterior, Codex Desktop o CLI con sesión iniciada y un TC001 con AWTRIX 3. Para Bluetooth se necesita el firmware complementario awtrix3-ble.

## Inicio rápido

1. Ejecuta `./run-tests.sh` y `./build.sh`.
2. Abre `dist/TC001 Bridge.app` y concede permisos de Bluetooth y red local.
3. Elige transporte Automático, Wi-Fi o Bluetooth.

- En Wi-Fi introduce la IP o `awtrix.local`; en Bluetooth espera la conexión AWTRIX-BLE.
- Activa la supervisión automática de Codex y prueba los colores del indicador.
- Configura las cinco páginas integradas de AWTRIX según tus necesidades.

## Privacidad y seguridad

No hay telemetría ni servidor del proyecto. La aplicación solo lee el estado local de Codex y envía píxeles renderizados y ajustes de página al TC001. La API local escucha en 127.0.0.1 y rechaza solicitudes de origen web.

## Licencia

La aplicación macOS usa la licencia MIT. Este proyecto no está afiliado ni respaldado por OpenAI, Codex, Ulanzi, AWTRIX o Blueforcer.

[Licencia](../../LICENSE)
