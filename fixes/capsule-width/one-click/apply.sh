#!/usr/bin/env bash
# 事件点胶囊展开修复 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 capsule-width-fix.patch 相同（在“事件点全屏提醒”之后应用；没应用过全屏提醒也能用）。
# 任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 事件点胶囊展开修复 · 一键应用 ===='

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

    # 1. EventPointReminder.h：声明 resizeEvent，去掉 m_adjustLabelAnimation
    if has "$header" 'void resizeEvent('; then
        gray '  [跳过] EventPointReminder.h 已修复'
    else
        nl=$(newline_of "$header")
        anchor OLD <<'EOF'
#include <QScreen>
EOF
        anchor NEW <<'EOF'
#include <QScreen>
#include <QResizeEvent>
EOF
        replace_once header "$nl" "$OLD" "$NEW" 'EventPointReminder.h（头文件）' || return 1
        anchor OLD <<'EOF'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);

EOF
        anchor NEW <<'EOF'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);

protected:

    void resizeEvent(QResizeEvent* event) override;

EOF
        replace_once header "$nl" "$OLD" "$NEW" 'EventPointReminder.h（resizeEvent 声明）' || return 1
        anchor OLD <<'EOF'
    QPropertyAnimation* m_adjustLabelAnimation;
EOF
        replace_once header "$nl" "$OLD" '' 'EventPointReminder.h（m_adjustLabelAnimation）' || return 1
    fi

    # 2. EventPointReminder.cpp：m_label 始终铺满胶囊
    if has "$source" 'EventPointReminder::resizeEvent'; then
        gray '  [跳过] EventPointReminder.cpp 已修复'
    else
        nl=$(newline_of "$source")
        anchor OLD <<'EOF'
    m_adjustLabelAnimation = new QPropertyAnimation(m_label, "size");
    m_adjustLabelAnimation->setDuration(500);
    m_adjustLabelAnimation->setEasingCurve(QEasingCurve::OutCubic);

EOF
        replace_once source "$nl" "$OLD" '' 'EventPointReminder.cpp（setupAnimation）' || return 1
        anchor OLD <<'EOF'
    m_label->adjustSize();
    m_adjustAnimation->setStartValue(this->geometry());
    m_adjustAnimation->setEndValue(QRect((desktop.width() - m_label->width() / GOLDEN_RATIO_INV) / 2, desktop.height() * 0.1, m_label->width() / GOLDEN_RATIO_INV, this->height()));
    m_adjustLabelAnimation->setStartValue(this->size());
    m_adjustLabelAnimation->setEndValue(QSize(m_label->width() / GOLDEN_RATIO_INV, this->height()));
    m_adjustAnimation->start();
    m_adjustLabelAnimation->start();
EOF
        anchor NEW <<'EOF'
    // 只量出文字需要的宽度，不改 m_label 的大小（它始终铺满胶囊，见 resizeEvent）
    const int labelWidth = m_label->sizeHint().width();
    m_adjustAnimation->setStartValue(this->geometry());
    m_adjustAnimation->setEndValue(QRect((desktop.width() - labelWidth / GOLDEN_RATIO_INV) / 2, desktop.height() * 0.1, labelWidth / GOLDEN_RATIO_INV, this->height()));
    m_adjustAnimation->start();
EOF
        replace_once source "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（updateLabel）' || return 1
        anchor NEW <<'EOF'


void EventPointReminder::resizeEvent(QResizeEvent* event)
{
    QLabel::resizeEvent(event);
    // 胶囊本身设置了 WA_TranslucentBackground，Qt 不会绘制它自己的样式表背景和红边，
    // 屏幕上看到的黑底红边其实是 m_label。让 m_label 始终铺满胶囊，展开和宽度变化的动画才能完整显示
    m_label->setGeometry(this->rect());
}
EOF
        NEW=${NEW%$'\n'}
        [ "$nl" = crlf ] && NEW=${NEW//$'\n'/$'\r\n'}
        source+=$NEW
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
