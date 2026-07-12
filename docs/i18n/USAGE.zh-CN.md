# TC001 Codex Bridge for macOS - 完整使用说明

[← README](README.zh-CN.md) | [English usage guide](../USAGE.md)

## 安装与连接

1. 运行 `./run-tests.sh` 和 `./build.sh`。
2. 打开 `dist/TC001 Bridge.app`，允许蓝牙和本地网络权限。
3. 在设置中选择自动、Wi-Fi 或蓝牙。
4. Wi-Fi 模式填写设备 IP 或 `awtrix.local`；蓝牙模式等待 AWTRIX-BLE 设备连接。
5. 开启 Codex 自动监测并使用状态灯测试按钮确认显示。
6. 按需要配置五个 AWTRIX 内置页面开关。

## 显示含义

左侧 1x8 灯条表示 5 小时余额，右侧表示 7 天余额。5H 显示 7 秒，7D 显示 3 秒。黄色为空闲、绿色为工作中、蓝色为等待确认、红色为异常。

## 故障排查

找不到蓝牙设备时检查固件版本 0.98-ble.4、系统蓝牙权限和旧配对记录；Wi-Fi 失败时确认 Mac 与 TC001 网络可达；没有额度时确认 Codex 已登录并等待刷新。

## 隐私与安全

项目没有遥测或自建服务器。应用只读取本地 Codex 状态，并向 TC001 发送渲染后的像素和页面开关。本地接口仅监听 127.0.0.1，并拒绝浏览器来源请求。

## 许可证

macOS 应用使用 MIT 许可证。项目与 OpenAI、Codex、Ulanzi、AWTRIX 或 Blueforcer 无官方隶属或背书关系。

[许可证](../../LICENSE)
