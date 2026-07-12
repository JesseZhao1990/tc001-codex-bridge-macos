# TC001 Codex Bridge for macOS - Guia de uso completo

[← README](README.pt-BR.md) | [English usage guide](../USAGE.md)

## Instalação e conexão

1. Execute `./run-tests.sh` e `./build.sh`.
2. Abra `dist/TC001 Bridge.app` e permita Bluetooth e rede local.
3. Escolha Automático, Wi-Fi ou Bluetooth.
4. No Wi-Fi, informe o IP ou `awtrix.local`; no Bluetooth, aguarde a conexão AWTRIX-BLE.
5. Ative o monitoramento automático do Codex e teste as cores do indicador.
6. Configure as cinco páginas internas do AWTRIX conforme necessário.

## Significado da tela

A barra esquerda 1x8 mostra a cota restante de 5 horas e a direita a de 7 dias. 5H aparece por 7 segundos e 7D por 3. Amarelo é ocioso, verde trabalhando, azul aguardando confirmação e vermelho erro.

## Solução de problemas

Se o BLE não aparecer, confira o firmware 0.98-ble.4, permissões e pareamentos antigos. No Wi-Fi, confirme que Mac e TC001 se alcançam. Sem cota, verifique o login do Codex e aguarde a atualização.

## Privacidade e segurança

Não há telemetria nem servidor do projeto. O aplicativo lê apenas o estado local do Codex e envia pixels renderizados e ajustes de páginas ao TC001. A API local escuta em 127.0.0.1 e rejeita origens de navegador.

## Licença

O aplicativo macOS usa a licença MIT. Este projeto não é afiliado nem endossado por OpenAI, Codex, Ulanzi, AWTRIX ou Blueforcer.

[Licença](../../LICENSE)
