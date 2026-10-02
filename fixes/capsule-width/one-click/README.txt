事件点胶囊展开修复 · 一键应用到 Universal-Timer
==============================================

修复的问题：事件点倒计时开始时，顶部的小胶囊没有展开到应有的宽度，也没有居中，
要等到第一个数字出现后才变正常；收起时也不完整。

不需要 git。只支持 Windows。有没有应用过“事件点全屏提醒”都可以用。

【怎么用】
1. 把这个文件夹整个解压出来，放进 Universal-Timer 项目文件夹里
   （就是有 src、assets、CMakeLists.txt 的那一层）。
2. 双击 apply.bat。
   - 放在别的地方也行：会弹出一个窗口，选 Universal-Timer 项目文件夹即可；
     或者直接把项目文件夹拖到 apply.bat 上。
   - 如果 Windows 提示“已保护你的电脑”，点“更多信息”→“仍要运行”。
3. 看到绿色的“完成！”后，在 Qt Creator（或 Visual Studio）里重新编译运行。

【它改了什么】
只改 src/ui/EventPointReminder.h 和 src/ui/EventPointReminder.cpp：
让里面的 m_label 始终铺满整个胶囊，展开 / 收起动画就能完整显示。

改之前会把原文件备份到本文件夹的 backup 里。
如果代码和预期的不一样，它会提示是哪一步对不上，并且一个文件都不改。

【撤销】
双击 undo.bat，恢复成应用之前的样子。
