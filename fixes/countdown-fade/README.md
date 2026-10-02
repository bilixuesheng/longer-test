# 事件点倒计时淡入淡出修复

**问题**：事件点胶囊里的数字淡入淡出时，整个胶囊（黑底和左右红边）也跟着一起变透明。

**原因**：胶囊（`EventPointReminder`，顶层 `QLabel`）设置了 `WA_TranslucentBackground`，Qt 不会替它画样式表背景，屏幕上的黑底红边其实一直是子控件 `m_label` 画的（见 `fixes/capsule-width`）。`0466a01` 把数字的 `QGraphicsOpacityEffect` 加在 `m_label` 上，于是透明度变化作用在整个胶囊上，而不只是数字。

**修复**：
- 胶囊在 `paintEvent` 里自己画黑底 `rgba(0, 0, 0, 0.75)` 和左右 5px 红边；样式表只保留 `color: white;`。
- `m_label` 只显示数字（没有背景和边框），并设置左右 5px 内边距，数字的位置和 `sizeHint` 与以前一致。
- 如果还没有 `m_countdownGroup->stop();`（`fixes/countdown-blink`），一键应用工具会一起加上；补丁本身要在 `stop()` 之后应用。

## 应用

- 会用 git：在已经加了 `m_countdownGroup->stop();` 的 Universal-Timer 根目录 `git apply countdown-fade-fix.patch`
- 不会用 git：用 `one-click/`，整个文件夹放进项目文件夹后，Linux 在该文件夹里运行 `bash apply.sh`，Windows 双击 `apply.bat`；`undo.sh` / `undo.bat` 撤销。

## 验证

- 在 Xvfb + xfwm4（开启合成）下，于每秒的 100 / 500 / 900ms 截图。修复前胶囊背景的像素在 (56,57,58) 到 (180,183,187) 之间变化、红边褪成粉色；修复后所有截图里背景都是 (56,57,58)、红边都是 (255,0,0)，只有数字在淡入淡出。
- 展开动画（竖线 → 加宽）不受影响；每个数字的最大不透明度仍是 1.0。
- 打上补丁的完整程序能编译链接。
- 一键应用工具：有 / 没有 `stop()` 两种起点 × LF / CRLF × bash / PowerShell，共 8 种组合，结果都与补丁逐字节相同；重复运行不会重复修改；撤销后与原文件一致。
