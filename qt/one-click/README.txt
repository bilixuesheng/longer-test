事件点全屏提醒 · 一键应用到 Universal-Timer
==========================================

不需要 git，也不需要懂补丁。Linux 和 Windows 都能用。

【Linux】
1. 把这个文件夹整个解压出来，放进 Universal-Timer 项目文件夹里
   （就是有 src、assets、CMakeLists.txt 的那一层）。
2. 打开这个文件夹，在空白处右键 →“在这里打开终端”，输入下面这行并回车：
       bash apply.sh
   （也可以在文件管理器里双击 apply.sh，选“在终端中运行”。）
   工具文件夹放在别处也行，把项目路径跟在后面：bash apply.sh ~/文档/projects/Universal-Timer
3. 看到绿色的“完成！”后，重新编译运行（新增了源文件，用 CMake 构建时会自动重新配置）。
撤销：在同一个地方运行 bash undo.sh

【Windows】
1. 同样把整个文件夹放进项目文件夹里。
2. 双击 apply.bat；放在别处时会弹窗让你选项目文件夹，或者把项目文件夹拖到 apply.bat 上。
   如果提示“已保护你的电脑”，点“更多信息”→“仍要运行”。
3. 看到“完成！”后重新编译运行（新增了源文件，用 CMake 构建时会自动重新配置）。
撤销：双击 undo.bat

【它改了什么】
- 新增 src/ui/EventPointFullscreenReminder.h 和 .cpp（全屏提醒本身）
- src/CMakeLists.txt：加入上面两个文件
- src/ui/EventPointReminder.h / .cpp：倒数到 0 时发出信号，交给全屏提醒
- src/core/UniversalTimer2.cpp：收到信号后打开全屏提醒

改之前会把原文件备份到本文件夹的 backup 里。
如果项目里这几处代码和预期的不一样，它会提示是哪一步对不上，并且一个文件都不改。

【运行时需要】
和原来的倒计时全屏提醒一样，程序运行目录下要有 sounds/countdown.wav。
