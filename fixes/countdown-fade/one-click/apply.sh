#!/usr/bin/env bash
# 事件点倒计时淡入淡出修复 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 countdown-fade-fix.patch 相同：数字淡入淡出时整个胶囊（黑底和红边）跟着一起变透明。
# 如果还没加 m_countdownGroup->stop();（数字隔一秒消失的修复），会一起加上。
# 任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 事件点倒计时淡入淡出修复 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"

P_HEADER=src/ui/EventPointReminder.h
P_SOURCE=src/ui/EventPointReminder.cpp
if ! { load header "$ROOT/$P_HEADER" && load source "$ROOT/$P_SOURCE"; }; then
    err '读取项目文件失败。'
    finish 1
fi
header0=$header; source0=$source

edit() {
    local nl

    # 0. 数字隔一秒消失的修复（已经加过就跳过）
    if has "$source" 'm_countdownGroup->stop();'; then
        gray '  [跳过] 已有 m_countdownGroup->stop();'
    else
        nl=$(newline_of "$source")
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
        replace_once source "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（stop）' || return 1
    fi

    # 1. EventPointReminder.h：声明 paintEvent
    if has "$header" 'void paintEvent('; then
        gray '  [跳过] EventPointReminder.h 已修复'
    else
        nl=$(newline_of "$header")
        anchor OLD <<'EOF'
#include <QResizeEvent>
EOF
        anchor NEW <<'EOF'
#include <QResizeEvent>
#include <QPaintEvent>
EOF
        replace_once header "$nl" "$OLD" "$NEW" 'EventPointReminder.h（头文件）' || return 1
        anchor OLD <<'EOF'
    void resizeEvent(QResizeEvent* event) override;
EOF
        anchor NEW <<'EOF'
    void resizeEvent(QResizeEvent* event) override;
    void paintEvent(QPaintEvent* event) override;
EOF
        replace_once header "$nl" "$OLD" "$NEW" 'EventPointReminder.h（paintEvent 声明）' || return 1
    fi

    # 2. EventPointReminder.cpp：胶囊自己画黑底和红边，m_label 只显示数字
    if has "$source" 'EventPointReminder::paintEvent'; then
        gray '  [跳过] EventPointReminder.cpp 已修复'
    else
        nl=$(newline_of "$source")
        anchor OLD <<'EOF'
#include "../core/Global.h"
EOF
        anchor NEW <<'EOF'
#include "../core/Global.h"

#include <QPainter>
EOF
        replace_once source "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（头文件）' || return 1
        anchor OLD <<'EOF'
    this->setStyleSheet("background-color: rgba(0, 0, 0, 0.75); color: white; border-left: 5px solid red; border-right: 5px solid red;");
EOF
        anchor NEW <<'EOF'
    // 黑底和左右红边在 paintEvent 里画，样式表只管文字颜色（会继承给 m_label）
    this->setStyleSheet("color: white;");
EOF
        replace_once source "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（样式表）' || return 1
        anchor OLD <<'EOF'
    m_label->setAlignment(Qt::AlignCenter);
EOF
        anchor NEW <<'EOF'
    m_label->setAlignment(Qt::AlignCenter);
    m_label->setContentsMargins(5, 0, 5, 0); // 让出左右红边，数字的位置和 sizeHint 与以前一致
EOF
        replace_once source "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（m_label 边距）' || return 1
        anchor OLD <<'EOF'
    // 胶囊本身设置了 WA_TranslucentBackground，Qt 不会绘制它自己的样式表背景和红边，
    // 屏幕上看到的黑底红边其实是 m_label。让 m_label 始终铺满胶囊，展开和宽度变化的动画才能完整显示
    m_label->setGeometry(this->rect());
}
EOF
        anchor NEW <<'EOF'
    // m_label 始终铺满胶囊，数字才能在整个胶囊里居中
    m_label->setGeometry(this->rect());
}

void EventPointReminder::paintEvent(QPaintEvent* event)
{
    Q_UNUSED(event);
    // 胶囊设置了 WA_TranslucentBackground，Qt 不会替它画样式表背景，所以黑底和红边在这里自己画。
    // 这样 m_label 只有数字，数字上的 QGraphicsOpacityEffect 就不会带着整个胶囊一起变透明
    QPainter painter(this);
    painter.fillRect(this->rect(), QColor(0, 0, 0, 191)); // rgba(0, 0, 0, 0.75)
    painter.fillRect(QRect(0, 0, 5, this->height()), Qt::red);
    painter.fillRect(QRect(this->width() - 5, 0, 5, this->height()), Qt::red);
}
EOF
        replace_once source "$nl" "${OLD%$'\n'}" "${NEW%$'\n'}" 'EventPointReminder.cpp（paintEvent）' || return 1
    fi
}

if ! edit; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。'
    finish 1
fi

if [ "$header" = "$header0" ] && [ "$source" = "$source0" ]; then
    echo
    ok '这个项目已经修复过了，没有需要修改的地方。'
    finish 0
fi

# 全部对上了才开始写：先备份
start_backup "$P_HEADER" "$P_SOURCE"
[ "$header" != "$header0" ] && printf '%s' "$header" > "$ROOT/$P_HEADER" && ok "  [已修改] $P_HEADER"
[ "$source" != "$source0" ] && printf '%s' "$source" > "$ROOT/$P_SOURCE" && ok "  [已修改] $P_SOURCE"

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
