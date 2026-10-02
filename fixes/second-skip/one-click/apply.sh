#!/usr/bin/env bash
# 事件点跳秒修复 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 second-skip-fix.patch 相同：倒计时数字、悬浮条秒数偶尔跳过或重复一秒，事件点 / 全屏提醒偶尔被错过。
# 任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 事件点跳秒修复 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"
P_0=src/ui/EventPointReminder.h
P_1=src/ui/EventPointReminder.cpp
P_2=src/core/UniversalTimer2.h
P_3=src/core/UniversalTimer2.cpp
if ! { load f0 "$ROOT/$P_0" && load f1 "$ROOT/$P_1" && load f2 "$ROOT/$P_2" && load f3 "$ROOT/$P_3"; }; then
    err '读取项目文件失败。'
    finish 1
fi
f0_0=$f0; f1_0=$f1; f2_0=$f2; f3_0=$f3

edit() {
    local nl

    if has "$f0" 'scheduleNextTick'; then
        gray '  [跳过] EventPointReminder.h 已修复'
    else
        nl=$(newline_of "$f0")
        anchor OLD <<'EOF'
    void showReminder();
EOF
        anchor NEW <<'EOF'
    void showReminder();
    void scheduleNextTick(); // 安排下一次更新：下一个整秒刚过 50ms
EOF
        replace_once f0 "$nl" "$OLD" "$NEW" 'EventPointReminder.h（声明）' || return 1
    fi

    if has "$f1" 'EventPointReminder::scheduleNextTick'; then
        gray '  [跳过] EventPointReminder.cpp 已修复'
    else
        nl=$(newline_of "$f1")
        anchor OLD <<'EOF'
    m_timer = new QTimer(this);
    m_timer->start(1000);
    connect(m_timer, &QTimer::timeout, this, [this]() {
        updateLabel();
    });
}
EOF
        anchor NEW <<'EOF'
    m_timer = new QTimer(this);
    m_timer->setSingleShot(true);
    m_timer->setTimerType(Qt::PreciseTimer);
    connect(m_timer, &QTimer::timeout, this, [this]() {
        updateLabel();
    });
    scheduleNextTick();
}

void EventPointReminder::scheduleNextTick()
{
    // 原来是每 1000ms 一次的普通（粗精度）计时器，触发时刻可能贴着整秒，前后抖几毫秒就会落到整秒的另一边，
    // secsTo() 算出的数字就会跳过一个或重复一个。改成每次都在下一个整秒刚过 50ms 时触发
    m_timer->start(1000 - QTime::currentTime().msec() + 50);
}
EOF
        replace_once f1 "$nl" "$OLD" "$NEW" 'EventPointReminder.cpp（showReminder）' || return 1
        anchor OLD <<'EOF'
    m_countdownGroup->start();
}
EOF
        anchor NEW <<'EOF'
    m_countdownGroup->start();
    scheduleNextTick();
}
EOF
        replace_once f1 "$nl" "${OLD%$'\n'}" "${NEW%$'\n'}" 'EventPointReminder.cpp（updateLabel）' || return 1
    fi

    if has "$f2" 'scheduleNextUpdate'; then
        gray '  [跳过] UniversalTimer2.h 已修复'
    else
        nl=$(newline_of "$f2")
        anchor OLD <<'EOF'
    void updateObjects(); // 更新对象
EOF
        anchor NEW <<'EOF'
    void updateObjects(); // 更新对象
    void scheduleNextUpdate(); // 安排下一次更新：下一个整 update_interval 刚过 50ms
EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'UniversalTimer2.h（声明）' || return 1
    fi

    if has "$f3" 'UniversalTimer2::scheduleNextUpdate'; then
        gray '  [跳过] UniversalTimer2.cpp 已修复'
    else
        nl=$(newline_of "$f3")
        anchor OLD <<'EOF'
    timer.start(config.general.update_interval);
    connect(&timer, &QTimer::timeout, this, &UniversalTimer2::updateObjects);
EOF
        anchor NEW <<'EOF'
    timer.setSingleShot(true);
    timer.setTimerType(Qt::PreciseTimer);
    connect(&timer, &QTimer::timeout, this, [this] {
        updateObjects();
        scheduleNextUpdate();
    });
    scheduleNextUpdate();
EOF
        replace_once f3 "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（计时器）' || return 1
        anchor OLD <<'EOF'
// 更新函数
// 悬浮条更新函数
EOF
        anchor NEW <<'EOF'
// 安排下一次更新
// 原来是普通的重复计时器，触发时刻可能贴着整秒，前后抖几毫秒就会跳过或重复某一秒：
// 悬浮条的秒数会跳，按整秒比对的全屏提醒时间和事件点也可能被错过。改成每次都在下一个整 update_interval 刚过 50ms 时触发
void UniversalTimer2::scheduleNextUpdate() {
    const int interval = qMax(1, int(config.general.update_interval));
    const int now = QTime::currentTime().msecsSinceStartOfDay();
    timer.start(interval - now % interval + 50);
}

// 更新函数
// 悬浮条更新函数
EOF
        replace_once f3 "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（scheduleNextUpdate）' || return 1
    fi
}

if ! edit; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。'
    finish 1
fi

if [ "$f0" = "$f0_0" ] && [ "$f1" = "$f1_0" ] && [ "$f2" = "$f2_0" ] && [ "$f3" = "$f3_0" ]; then
    echo
    ok '这个项目已经修复过了，没有需要修改的地方。'
    finish 0
fi

# 全部对上了才开始写：先备份
start_backup "$P_0" "$P_1" "$P_2" "$P_3"
[ "$f0" != "$f0_0" ] && printf '%s' "$f0" > "$ROOT/$P_0" && ok "  [已修改] $P_0"
[ "$f1" != "$f1_0" ] && printf '%s' "$f1" > "$ROOT/$P_1" && ok "  [已修改] $P_1"
[ "$f2" != "$f2_0" ] && printf '%s' "$f2" > "$ROOT/$P_2" && ok "  [已修改] $P_2"
[ "$f3" != "$f3_0" ] && printf '%s' "$f3" > "$ROOT/$P_3" && ok "  [已修改] $P_3"

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
