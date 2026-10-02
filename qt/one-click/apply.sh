#!/usr/bin/env bash
# 事件点全屏提醒 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 qt/integration.patch 完全相同；任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 事件点全屏提醒 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"

NEW_FILES=(EventPointFullscreenReminder.h EventPointFullscreenReminder.cpp)
for f in "${NEW_FILES[@]}"; do
    [ -f "$PKG/files/$f" ] || { err "工具文件夹不完整，缺少 files/$f，请重新解压。"; finish 1; }
done

P_CMAKE=src/CMakeLists.txt
P_HEADER=src/ui/EventPointReminder.h
P_SOURCE=src/ui/EventPointReminder.cpp
P_TIMER=src/core/UniversalTimer2.cpp
if ! { load cmake "$ROOT/$P_CMAKE" && load header "$ROOT/$P_HEADER" && load source "$ROOT/$P_SOURCE" && load timer "$ROOT/$P_TIMER"; }; then
    err '读取项目文件失败。'
    finish 1
fi
cmake0=$cmake; header0=$header; source0=$source; timer0=$timer

edit() {
    local nl

    # 1. CMakeLists.txt：加入新文件
    if has "$cmake" 'ui/EventPointFullscreenReminder.cpp'; then
        gray '  [跳过] CMakeLists.txt 已包含新文件'
    else
        nl=$(newline_of "$cmake")
        anchor OLD <<'EOF'
    ui/EventPointReminder.cpp
EOF
        anchor NEW <<'EOF'
    ui/EventPointReminder.cpp
    ui/EventPointFullscreenReminder.h
    ui/EventPointFullscreenReminder.cpp
EOF
        replace_once cmake "$nl" "$OLD" "$NEW" 'CMakeLists.txt' || return 1
    fi

    # 2. EventPointReminder.h：新增 reached 信号
    if has "$header" 'void reached('; then
        gray '  [跳过] EventPointReminder.h 已有 reached 信号'
    else
        nl=$(newline_of "$header")
        anchor OLD <<'EOF'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);
EOF
        anchor NEW <<'EOF'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);

Q_SIGNALS:

    void reached(const EventPoint& eventPoint, const QRect& capsuleGeometry); // 到达事件点，交给全屏提醒继续播放
EOF
        replace_once header "$nl" "$OLD" "$NEW" 'EventPointReminder.h' || return 1
    fi

    # 3. EventPointReminder.cpp：到点时发出信号并收起自己
    if has "$source" 'emit reached('; then
        gray '  [跳过] EventPointReminder.cpp 已修改过'
    else
        nl=$(newline_of "$source")
        anchor OLD <<'EOF'
    int remainingSeconds = currentTime.secsTo(m_eventPoint.time());
    if (remainingSeconds <= 0) {
        m_label->setText(m_eventPoint.name());
    } else {
        m_label->setText(QString::number(remainingSeconds));
    }
EOF
        anchor NEW <<'EOF'
    int remainingSeconds = currentTime.secsTo(m_eventPoint.time());
    if (remainingSeconds <= 0) {
        // 到达事件点：把胶囊当前位置交给全屏提醒，红线从这里开始
        m_timer->stop();
        emit reached(m_eventPoint, this->geometry());
        this->hide();
        this->deleteLater();
        return;
    }
    m_label->setText(QString::number(remainingSeconds));
EOF
        replace_once source "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（到点处理）' || return 1
        anchor OLD <<'EOF'
    m_adjustAnimation->start();
    m_adjustLabelAnimation->start();
    if (remainingSeconds <= -1) {
        m_timer->stop();
        m_fadeOutAnimation1->setStartValue(this->geometry());
        m_fadeOutGroup->start();
        connect(m_fadeOutGroup, &QSequentialAnimationGroup::finished, this, [this]() {
            this->hide();
            this->deleteLater();
        });
    }
}
EOF
        anchor NEW <<'EOF'
    m_adjustAnimation->start();
    m_adjustLabelAnimation->start();
}
EOF
        replace_once source "$nl" "${OLD%$'\n'}" "${NEW%$'\n'}" 'EventPointReminder.cpp（删除旧的收起逻辑）' || return 1
    fi

    # 4. UniversalTimer2.cpp：创建胶囊时连接 reached，打开全屏提醒
    nl=$(newline_of "$timer")
    if has "$timer" 'ui/EventPointFullscreenReminder.h'; then
        gray '  [跳过] UniversalTimer2.cpp 已包含头文件'
    else
        anchor OLD <<'EOF'
#include "ui/EventPointReminder.h"
EOF
        anchor NEW <<'EOF'
#include "ui/EventPointReminder.h"
#include "ui/EventPointFullscreenReminder.h"
EOF
        replace_once timer "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（头文件）' || return 1
    fi
    if has "$timer" 'EventPointReminder::reached'; then
        gray '  [跳过] UniversalTimer2.cpp 已连接 reached'
    else
        anchor OLD <<'EOF'
            EventPointReminder* event_point_reminder = new EventPointReminder(nullptr, event_point_item);
            event_point_reminder->setAttribute(Qt::WA_DeleteOnClose);
EOF
        anchor NEW <<'EOF'
            EventPointReminder* event_point_reminder = new EventPointReminder(nullptr, event_point_item);
            event_point_reminder->setAttribute(Qt::WA_DeleteOnClose);
            connect(event_point_reminder, &EventPointReminder::reached, this, [this](const EventPoint& event_point, const QRect& capsule_geometry) {
                EventPointFullscreenReminder* event_point_fullscreen_reminder = new EventPointFullscreenReminder(event_point, config.event_point.event_point_list, capsule_geometry);
                event_point_fullscreen_reminder->start();
                });
EOF
        replace_once timer "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（连接信号）' || return 1
    fi
}

if ! edit; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个功能的人。'
    finish 1
fi

copy_new_files() {
    local f
    for f in "${NEW_FILES[@]}"; do
        cp -- "$PKG/files/$f" "$ROOT/src/ui/$f"
        ok "  [已复制] src/ui/$f"
    done
}

if [ "$cmake" = "$cmake0" ] && [ "$header" = "$header0" ] && [ "$source" = "$source0" ] && [ "$timer" = "$timer0" ]; then
    copy_new_files > /dev/null
    echo
    ok '这个项目已经应用过了，这次只把 EventPointFullscreenReminder 两个文件更新为最新版本。'
    finish 0
fi

# 全部对上了才开始写：先备份
start_backup "$P_CMAKE" "$P_HEADER" "$P_SOURCE" "$P_TIMER" "src/ui/${NEW_FILES[0]}" "src/ui/${NEW_FILES[1]}"
[ "$cmake" != "$cmake0" ]   && printf '%s' "$cmake"  > "$ROOT/$P_CMAKE"  && ok "  [已修改] $P_CMAKE"
[ "$header" != "$header0" ] && printf '%s' "$header" > "$ROOT/$P_HEADER" && ok "  [已修改] $P_HEADER"
[ "$source" != "$source0" ] && printf '%s' "$source" > "$ROOT/$P_SOURCE" && ok "  [已修改] $P_SOURCE"
[ "$timer" != "$timer0" ]   && printf '%s' "$timer"  > "$ROOT/$P_TIMER"  && ok "  [已修改] $P_TIMER"
copy_new_files

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可（用 CMake 构建时会自动重新配置）。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
