# TC001 Codex Bridge for macOS - 전체 사용 설명서

[← README](README.ko.md) | [English usage guide](../USAGE.md)

## 설치 및 연결

1. `./run-tests.sh`와 `./build.sh`를 실행합니다.
2. `dist/TC001 Bridge.app`을 열고 Bluetooth 및 로컬 네트워크 권한을 허용합니다.
3. 자동, Wi-Fi 또는 Bluetooth 전송을 선택합니다.
4. Wi-Fi에서는 IP나 `awtrix.local`을 입력하고 Bluetooth에서는 AWTRIX-BLE 연결을 기다립니다.
5. Codex 자동 모니터링을 켜고 상태등 테스트를 실행합니다.
6. 필요에 따라 다섯 개의 AWTRIX 기본 페이지를 설정합니다.

## 표시 의미

왼쪽 1x8 막대는 5시간 잔여량, 오른쪽은 7일 잔여량입니다. 5H는 7초, 7D는 3초 표시됩니다. 노랑은 유휴, 초록은 작업 중, 파랑은 확인 대기, 빨강은 오류입니다.

## 문제 해결

BLE 장치가 없으면 펌웨어 0.98-ble.4, 권한, 오래된 페어링을 확인하십시오. Wi-Fi에서는 Mac과 TC001의 연결 가능 여부를 확인합니다. 한도가 없으면 Codex 로그인을 확인하고 새로 고침을 기다립니다.

## 개인정보 및 보안

원격 측정이나 프로젝트 서버가 없습니다. 앱은 로컬 Codex 상태만 읽고 렌더링된 픽셀과 페이지 설정만 TC001에 보냅니다. 로컬 API는 127.0.0.1에서만 수신하며 브라우저 Origin 요청을 거부합니다.

## 라이선스

macOS 앱은 MIT 라이선스입니다. 이 프로젝트는 OpenAI, Codex, Ulanzi, AWTRIX 또는 Blueforcer와 공식 제휴되거나 보증되지 않습니다.

[라이선스](../../LICENSE)
