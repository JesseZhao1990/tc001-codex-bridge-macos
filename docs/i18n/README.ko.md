# TC001 Codex Bridge for macOS

[← English](../../README.md) | [전체 사용 설명서](USAGE.ko.md)

## 개요

TC001 Codex Bridge는 Codex의 5시간 및 7일 잔여 한도와 작업 상태를 Ulanzi TC001에 표시하는 네이티브 macOS 앱입니다. AWTRIX HTTP와 보조 펌웨어의 Bluetooth 전송을 지원합니다.

## 주요 기능

좌우 한도 막대, 번갈아 표시되는 5H/7D 값, 네 가지 색상의 상태등을 제공합니다. 시간, 날짜, 온도, 습도, 배터리 페이지도 설정할 수 있으며 Codex 분석은 Mac에서만 수행됩니다.

## 요구 사항

macOS 13 이상, 로그인된 Codex Desktop 또는 CLI, AWTRIX 3가 설치된 TC001이 필요합니다. Bluetooth를 사용하려면 awtrix3-ble 펌웨어가 필요합니다.

## 빠른 시작

1. `./run-tests.sh`와 `./build.sh`를 실행합니다.
2. `dist/TC001 Bridge.app`을 열고 Bluetooth 및 로컬 네트워크 권한을 허용합니다.
3. 자동, Wi-Fi 또는 Bluetooth 전송을 선택합니다.

- Wi-Fi에서는 IP나 `awtrix.local`을 입력하고 Bluetooth에서는 AWTRIX-BLE 연결을 기다립니다.
- Codex 자동 모니터링을 켜고 상태등 테스트를 실행합니다.
- 필요에 따라 다섯 개의 AWTRIX 기본 페이지를 설정합니다.

## 개인정보 및 보안

원격 측정이나 프로젝트 서버가 없습니다. 앱은 로컬 Codex 상태만 읽고 렌더링된 픽셀과 페이지 설정만 TC001에 보냅니다. 로컬 API는 127.0.0.1에서만 수신하며 브라우저 Origin 요청을 거부합니다.

## 라이선스

macOS 앱은 MIT 라이선스입니다. 이 프로젝트는 OpenAI, Codex, Ulanzi, AWTRIX 또는 Blueforcer와 공식 제휴되거나 보증되지 않습니다.

[라이선스](../../LICENSE)
