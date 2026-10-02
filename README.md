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
