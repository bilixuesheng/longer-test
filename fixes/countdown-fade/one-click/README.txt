事件点倒计时淡入淡出修复 · 一键应用到 Universal-Timer
==================================================

修复的问题：事件点倒计时的数字淡入淡出时，整个胶囊（黑底和红边）也跟着一起变透明。
如果还没加“数字隔一秒消失”的修复（m_countdownGroup->stop();），这次会一起加上。

不需要 git，也不需要懂补丁。Linux 和 Windows 都能用。

【Linux】
1. 把这个文件夹整个解压出来，放进 Universal-Timer 项目文件夹里
   （就是有 src、assets、CMakeLists.txt 的那一层）。
2. 打开这个文件夹，在空白处右键 →“在这里打开终端”，输入下面这行并回车：
       bash apply.sh
   （也可以在文件管理器里双击 apply.sh，选“在终端中运行”。）
   工具文件夹放在别处也行，把项目路径跟在后面：bash apply.sh ~/文档/projects/Universal-Timer
3. 看到绿色的“完成！”后，重新编译运行。
撤销：在同一个地方运行 bash undo.sh

【Windows】
1. 同样把整个文件夹放进项目文件夹里。
2. 双击 apply.bat；放在别处时会弹窗让你选项目文件夹，或者把项目文件夹拖到 apply.bat 上。
   如果提示“已保护你的电脑”，点“更多信息”→“仍要运行”。
3. 看到“完成！”后重新编译运行。
撤销：双击 undo.bat

【它改了什么】
只改 src/ui/EventPointReminder.h 和 src/ui/EventPointReminder.cpp：
胶囊的黑底和红边改成在 paintEvent 里自己画，m_label 只显示数字，
数字上的淡入淡出效果就只作用在数字上。

改之前会把原文件备份到本文件夹的 backup 里。
如果代码和预期的不一样，它会提示是哪一步对不上，并且一个文件都不改。
