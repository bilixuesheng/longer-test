# 事件点全屏提醒 · 动画演示

为 [Universal-Timer](https://github.com/0xlonger/Universal-Timer) 的「事件点」功能设计的到点全屏提醒动画（不是倒计时全屏提醒）。

直接用浏览器打开 `event-point-reminder/index.html` 即可查看。

## 动画流程（0 = 到达事件点）

| 时间 | 阶段 |
| --- | --- |
| −4.0 s ~ 0 | 现有 `EventPointReminder` 顶部胶囊倒数最后 3 秒（按源码复刻） |
| 0 ~ 0.3 s | 胶囊收窄成 5px 红线（同 `m_fadeOutAnimation1`） |
| 0.3 ~ 0.65 s | 红线贯穿全屏高度，背景压暗到 `rgba(0,0,0,0.75)` |
| 0.65 ~ 1.02 s | 从红线向两侧展开成满屏红色，接缝是 V 形，门上印着黑色事件时间 |
| 1.02 ~ 2.2 s | 两扇红门向左右分开（1000ms OutCubic），四段圆环、60 格刻度、事件时间 / 名称依次出现 |
| 2.2 s 起 | 每秒一次：四角三角闪烁（亮 500 / 灭 500）、冲击波、countdown.wav |
| 结尾 | 文字红块擦除、圆环收回，`windowOpacity` 1→0（1000ms InCubic） |

页面里的控制台可以拖动时间轴逐帧查看、改事件名称 / 时间 / 闪烁次数、0.25× 慢放，并列出每个图层对应的 QPainter 写法。

## Qt 实现

`qt/` 目录是同一套动画的 Qt 版本：`EventPointFullscreenReminder` 类、可以 `git apply` 到 Universal-Timer 的补丁，以及一个独立预览程序。详见 [qt/README.md](qt/README.md)。

## 修复

- [fixes/capsule-width](fixes/capsule-width/README.md)：事件点胶囊在展开阶段不变宽、不居中的问题。补丁要在 `qt/integration.patch` 之后应用，也有 Windows 一键应用包。
- [fixes/countdown-blink](fixes/countdown-blink/README.md)：事件点倒计时数字隔一秒消失一次的问题（基于 Universal-Timer 最新的 `0466a01`），也有一键应用包。
- [fixes/countdown-fade](fixes/countdown-fade/README.md)：数字淡入淡出时整个胶囊跟着变透明的问题（在 countdown-blink 之后应用，一键包会顺带补上 `stop()`）。
