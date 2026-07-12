# TC001 Codex Bridge for macOS - Guía de uso completa

[← README](README.es.md) | [English usage guide](../USAGE.md)

## Instalación y conexión

1. Ejecuta `./run-tests.sh` y `./build.sh`.
2. Abre `dist/TC001 Bridge.app` y concede permisos de Bluetooth y red local.
3. Elige transporte Automático, Wi-Fi o Bluetooth.
4. En Wi-Fi introduce la IP o `awtrix.local`; en Bluetooth espera la conexión AWTRIX-BLE.
5. Activa la supervisión automática de Codex y prueba los colores del indicador.
6. Configura las cinco páginas integradas de AWTRIX según tus necesidades.

## Significado de la pantalla

La barra izquierda 1x8 indica la cuota restante de 5 horas y la derecha la de 7 días. 5H aparece durante 7 segundos y 7D durante 3. Amarillo es inactivo, verde trabajando, azul esperando confirmación y rojo error.

## Solución de problemas

Si no aparece Bluetooth, verifica el firmware 0.98-ble.4, los permisos y emparejamientos antiguos. Para Wi-Fi comprueba que Mac y TC001 sean accesibles entre sí. Si no hay cuota, confirma que Codex tenga sesión iniciada y espera la actualización.

## Privacidad y seguridad

No hay telemetría ni servidor del proyecto. La aplicación solo lee el estado local de Codex y envía píxeles renderizados y ajustes de página al TC001. La API local escucha en 127.0.0.1 y rechaza solicitudes de origen web.

## Licencia

La aplicación macOS usa la licencia MIT. Este proyecto no está afiliado ni respaldado por OpenAI, Codex, Ulanzi, AWTRIX o Blueforcer.

[Licencia](../../LICENSE)
