# 事件点胶囊展开修复

**问题**：事件点倒计时开始时，顶部的小胶囊在展开阶段没有变宽，也没有居中，停在一个很窄的宽度上；要等第一个数字出现后才恢复正常。

**原因**：`EventPointReminder`（胶囊本身，一个顶层 `QLabel`）设置了 `Qt::WA_TranslucentBackground`。这个属性会顺带设置 `WA_NoSystemBackground`，Qt 因此不会绘制它自己的样式表背景和红边。不带选择器的样式表会继承给子控件，所以屏幕上看到的黑底红边其实一直是里面的 `m_label`。

展开动画 `m_fadeInAnimation1/2` 只改胶囊的 geometry，而 `m_label` 停在第一次显示时的大小（空文字的 sizeHint，约 0.0156 × 0.036 倍屏宽），所以看起来“展开到一定宽度就停了”，并且贴在胶囊左边、不居中。`m_label` 只有在 `updateLabel()` 里才会被 `m_adjustLabelAnimation` 拉大，所以第一个数字出现后就正常了。

**修复**：在 `resizeEvent` 里让 `m_label` 始终铺满胶囊，所有尺寸动画就都能完整显示。`updateLabel()` 改用 `sizeHint()` 量文字宽度，不再 `adjustSize()`；多余的 `m_adjustLabelAnimation` 删掉。

## 应用

这个补丁要在 `qt/integration.patch`（事件点全屏提醒）**之后**应用：

- 会用 git：在 Universal-Timer 根目录 `git apply capsule-width-fix.patch`
- 不会用 git（Windows）：用 `one-click/`，放进项目文件夹后双击 `apply.bat`；`undo.bat` 撤销。有没有应用过全屏提醒都能用。

## 验证

- 在 Xvfb + xfwm4（开启合成，与 XFCE 相同）下复现了问题：0.65～0.9 秒窗口已经 57→95px 宽，屏幕上的方块却一直是 30×69px。
- 修复后同样条件下逐帧截图：竖线长到完整高度，再展开成居中的方块，之后正常显示数字。
- 打上全屏提醒补丁和本补丁的完整程序能编译链接，实际运行：胶囊正常展开，到点后交给全屏提醒。
- 一键应用工具在 LF / CRLF 两种换行的项目上都测试过，结果与补丁逐字节相同；重复运行不会重复修改；撤销后恢复到应用前的状态。
