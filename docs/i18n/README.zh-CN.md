# TC001 Codex Bridge for macOS

[← English](../../README.md) | [完整使用说明](USAGE.zh-CN.md)

## 简介

TC001 Codex Bridge 是一款原生 macOS 应用，可把 Codex 的 5 小时、7 天额度和工作状态显示在 Ulanzi TC001 上。它支持 AWTRIX HTTP，也支持配套固件提供的蓝牙连接。

## 主要功能

应用会显示左右额度条、5H/7D 数字和四色状态灯。5 小时与 7 天额度可分别开关，支持只显示其中一种或同时显示两种；还可配置时间、日期、温度、湿度、电量页面。所有 Codex 状态分析都在 Mac 本地完成。

## 环境要求

需要 macOS 13 或更高版本、已登录的 Codex 桌面应用或 CLI，以及运行 AWTRIX 3 的 TC001。使用蓝牙时必须刷入配套的 awtrix3-ble 固件。

## 快速开始

1. 运行 `./run-tests.sh` 和 `./build.sh`。
2. 打开 `dist/TC001 Bridge.app`，允许蓝牙和本地网络权限。
3. 在设置中选择自动、Wi-Fi 或蓝牙。

- Wi-Fi 模式填写设备 IP 或 `awtrix.local`；蓝牙模式等待 AWTRIX-BLE 设备连接。
- 开启 Codex 自动监测并使用状态灯测试按钮确认显示。
- 按需要配置五个 AWTRIX 内置页面开关。

## 隐私与安全

项目没有遥测或自建服务器。应用只读取本地 Codex 状态，并向 TC001 发送渲染后的像素和页面开关。本地接口仅监听 127.0.0.1，并拒绝浏览器来源请求。

## 许可证

macOS 应用使用 MIT 许可证。项目与 OpenAI、Codex、Ulanzi、AWTRIX 或 Blueforcer 无官方隶属或背书关系。

[许可证](../../LICENSE)
