# 事件点倒计时数字闪烁修复

**问题**：事件点胶囊里的倒计时数字有时隔一秒消失一次，比如 15 显示、14 不显示、13 显示、12 不显示……

**原因**：提交 `0466a01`（新增事件点提醒悬浮窗倒计时淡入淡出动画）加的数字动画 `m_countdownGroup` 是“渐入 250ms + 停顿 500ms + 渐出 250ms”，正好 1000ms，和 `m_timer` 的间隔一样长。`updateLabel()` 每秒调用一次 `m_countdownGroup->start()`，但 `QAbstractAnimation::start()` 在动画还处于 Running 状态时什么都不做。动画结束要等到下一次动画帧才会被标记为 Stopped，所以计时器常常在 991ms 左右就到了：这一次 `start()` 被忽略，动画随后停在渐出的终点（透明度 0），这个数字整整一秒都看不到；下一秒动画已经停了，`start()` 又能正常从头播放。于是就出现了隔一个数字消失一次的规律。

**修复**：在 `m_countdownGroup->start()` 之前加一行 `m_countdownGroup->stop();`，保证每一秒都从头播放。

## 应用

基于 Universal-Timer 最新的 `0466a01`：

- 会用 git：在 Universal-Timer 根目录 `git apply countdown-blink-fix.patch`
- 不会用 git：用 `one-click/`，整个文件夹放进项目文件夹后，Linux 在该文件夹里运行 `bash apply.sh`，Windows 双击 `apply.bat`；`undo.sh` / `undo.bat` 撤销。

## 验证

- 用最新代码复现：连续 3 次、每次 15 秒倒计时，13、11、9、7、5、3、1 的最大不透明度都是 0～0.1（看不到），其余数字是 1.0。日志里能看到这些秒计时器到达时动画组仍是 Running、`currentTime` = 991ms。
- 修复后同样 3 次，15 到 1 每个数字的最大不透明度都是 1.0。
- 打上补丁的完整程序能编译链接。
- 一键应用工具（bash 版和 PowerShell 版）在 LF / CRLF 两种换行的项目上都测试过，结果与补丁逐字节相同；重复运行不会重复修改；撤销后与原文件一致。
