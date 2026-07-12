# TC001 Codex Bridge for macOS

[← English](../../README.md) | [Guia de uso completo](USAGE.pt-BR.md)

## Visão geral

TC001 Codex Bridge é um aplicativo nativo para macOS que mostra no Ulanzi TC001 os limites de 5 horas e 7 dias do Codex e o estado de trabalho. Ele funciona com AWTRIX por HTTP e com o transporte Bluetooth do firmware complementar.

## Principais recursos

Exibe barras laterais de cota, valores 5H/7D alternados e um indicador de quatro cores. Também configura as páginas de hora, data, temperatura, umidade e bateria. A análise do Codex acontece localmente no Mac.

## Requisitos

Requer macOS 13 ou posterior, Codex Desktop ou CLI conectado e um TC001 com AWTRIX 3. O Bluetooth exige o firmware complementar awtrix3-ble.

## Início rápido

1. Execute `./run-tests.sh` e `./build.sh`.
2. Abra `dist/TC001 Bridge.app` e permita Bluetooth e rede local.
3. Escolha Automático, Wi-Fi ou Bluetooth.

- No Wi-Fi, informe o IP ou `awtrix.local`; no Bluetooth, aguarde a conexão AWTRIX-BLE.
- Ative o monitoramento automático do Codex e teste as cores do indicador.
- Configure as cinco páginas internas do AWTRIX conforme necessário.

## Privacidade e segurança

Não há telemetria nem servidor do projeto. O aplicativo lê apenas o estado local do Codex e envia pixels renderizados e ajustes de páginas ao TC001. A API local escuta em 127.0.0.1 e rejeita origens de navegador.

## Licença

O aplicativo macOS usa a licença MIT. Este projeto não é afiliado nem endossado por OpenAI, Codex, Ulanzi, AWTRIX ou Blueforcer.

[Licença](../../LICENSE)
