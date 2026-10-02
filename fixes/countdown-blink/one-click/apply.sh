#!/usr/bin/env bash
# 事件点倒计时数字闪烁修复 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 countdown-blink-fix.patch 相同：倒计时数字有时隔一秒消失（如 15 显示、14 不显示、13 显示……）。
# 任何一步对不上就不改文件，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 事件点倒计时数字闪烁修复 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"

P_SOURCE=src/ui/EventPointReminder.cpp
if ! load source "$ROOT/$P_SOURCE"; then
    err '读取项目文件失败。'
    finish 1
fi
source0=$source

if has "$source" 'm_countdownGroup->stop();'; then
    echo
    ok '这个项目已经修复过了，没有需要修改的地方。'
    finish 0
fi

# 每秒重新开始数字动画前先停掉上一次的
anchor OLD <<'EOF'
    m_adjustAnimation->start();
    m_countdownGroup->start();
EOF
anchor NEW <<'EOF'
    m_adjustAnimation->start();
    // 数字动画（250 + 500 + 250）正好 1 秒，和计时器间隔一样长；计时器稍微早到时动画还没结束，
    // 这时 start() 不会重新开始，数字就停在透明度 0，整整一秒看不到。先 stop() 再 start() 保证每秒都从头播放
    m_countdownGroup->stop();
    m_countdownGroup->start();
EOF
if ! replace_once source "$(newline_of "$source")" "$OLD" "$NEW" 'EventPointReminder.cpp（updateLabel）'; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。'
    finish 1
fi

# 先备份再写
start_backup "$P_SOURCE"
printf '%s' "$source" > "$ROOT/$P_SOURCE" && ok "  [已修改] $P_SOURCE"

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
