# 设置页虚拟键盘与日历弹窗修复

基于上游 `a86dbfc`，只改 `src/ui/FullscreenPagesManager.{h,cpp}` 和 `src/ui/SettingsContent.{h,cpp}`，全部是新增代码，不删改已有的行。

## 1. Windows 触屏：刚打开设置后，触摸点击输入框不弹出触摸键盘

**问题**：在 Windows 触屏设备上，从托盘打开设置后，用手指点文本框、数字框或日期时间框，Windows 自带的触摸键盘有时不弹出（多见于打开后的第一次点击）。

**原因**（根据 Qt 6.10.1 源码分析）：
- 全屏窗口 `FullscreenPagesManager` 带有 `Qt::Tool` 标志。Qt 在 Windows 上显示 Tool 窗口时用的是 `SW_SHOWNOACTIVATE`（`qwindowswindow.cpp` 的 `show_sys()`），窗口只显示、不激活；项目里也没有调用 `activateWindow()`。
- 触摸点击输入框时，`QLineEdit` 在松开时调用 `QGuiApplication::inputMethod()->show()`。Windows 端的 `QWindowsInputContext::showInputPanel()` 在 `QGuiApplication::focusWindow()` 为空时直接返回；只有不为空时，才会在焦点窗口里建一个看不见的光标，由它带出触摸键盘。窗口还没激活时，这次请求就被丢掉了。`QSpinBox` 和 `QDateTimeEdit` 内部也是 `QLineEdit`，所以三种输入框都会受影响。

**修复**：
- `showSettings()` 里调用 `raise()` 和 `activateWindow()`，让设置窗口真正成为前台窗口。只对设置页这样做；全屏提醒是定时弹出的，如果也激活，会抢走正在使用的程序的焦点。
- 新增 `changeEvent()`：设置窗口被激活时，如果焦点已经在接受输入法的控件上，就补发一次 `inputMethod()->show()`，补上激活前被丢掉的那次请求。

**补充**：Windows 10/11 在非平板模式、或者接着实体键盘时，默认不会自动弹出触摸键盘（系统设置 →“时间和语言 → 输入 → 触摸键盘”→“没有连接键盘时显示触摸键盘”）。如果打了补丁之后还是每次都不弹，请先检查这项系统设置。

## 2. 目标时间的日历弹窗太丑

**问题**：日历弹窗很小；星期栏是白底白字，看不见；弹窗还会继承设置页 `QWidget { background-color: transparent; }` 的透明背景；上下月按钮是系统默认的绿色图标。

**修复**：给 `TargetDateTimeEdit` 设置一个自定义的 `QCalendarWidget`：
- 深红底 `rgb(40, 0, 0)`（和下拉框弹窗相同），导航栏 `rgb(80, 0, 0)`，选中日期纯红，周末浅红，非本月日期变暗。
- 不显示周数；上下月按钮改成文字箭头 `<` `>`；月份菜单和年份输入框用同样的配色。
- 格子大小随设置页高度缩放（最小 14×12.8 个 `高度×0.03`），方便手指点选。
- 一周从哪天开始跟随系统区域设置。

对比图见 `calendar-compare.png`（现状 / 采用的 A 深红底 / 未采用的 B 半透明黑底）。

## 应用

- 会用 git：在 Universal-Timer 根目录运行 `git apply settings-vkb-fix.patch`
- 不会用 git：把 `one-click/` 整个文件夹放进项目文件夹，在该文件夹里运行 `bash apply.sh`；撤销运行 `bash undo.sh`。

## 验证

- 补丁可以干净地应用到 `a86dbfc`，打上补丁的完整程序能编译链接（本地是 Qt 6.4；`checkStateChanged` 只在本地编译时临时换成了 `stateChanged`，补丁里不含这个改动）。
- Xvfb + xfwm4（开启合成）：打开设置后窗口处于激活状态；先让别的窗口拿走焦点，再点击“悬浮条文本”输入框，窗口被激活时补发了一次 `inputMethod()->show()`（用测试日志确认，日志不在补丁里）。
- 日历弹窗：翻月、月份菜单、点选日期都正常，选中的日期会写入配置，弹窗随后关闭。
- **没有在真实的 Windows 触屏设备上验证**：这个环境里没有 Windows 和它的触摸键盘，修复依据的是 Qt 源码分析，需要在真机上确认。
- 一键应用工具：LF / CRLF 两种情况下，结果都和补丁逐字节相同；重复运行会跳过；撤销后和原文件一致；锚点对不上、或者项目里已经有别的 `changeEvent` 时，一个文件都不改。
