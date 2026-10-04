#!/usr/bin/env bash
# 设置页虚拟键盘与日历修复 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 settings-vkb-fix.patch 相同：
#   1. Windows 触屏设备上，刚打开设置后触摸点击输入框时触摸键盘不弹出
#   2. 目标时间的日历弹窗换成红黑主题、放大格子，方便手指点选
# 任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 设置页虚拟键盘与日历修复 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"

P_FPM_H=src/ui/FullscreenPagesManager.h
P_FPM_C=src/ui/FullscreenPagesManager.cpp
P_SC_H=src/ui/SettingsContent.h
P_SC_C=src/ui/SettingsContent.cpp
if ! { load fpmh "$ROOT/$P_FPM_H" && load fpmc "$ROOT/$P_FPM_C" && load sch "$ROOT/$P_SC_H" && load scc "$ROOT/$P_SC_C"; }; then
    err '读取项目文件失败。'
    finish 1
fi
fpmh0=$fpmh; fpmc0=$fpmc; sch0=$sch; scc0=$scc

edit() {
    local nl

    # 1. 虚拟键盘：打开设置时激活窗口，窗口激活时补发键盘请求
    if has "$fpmc" '补发一次显示虚拟键盘的请求'; then
        gray '  [跳过] 虚拟键盘部分已修复'
    elif has "$fpmh" 'void changeEvent(' || has "$fpmc" 'FullscreenPagesManager::changeEvent'; then
        FAIL='[FullscreenPagesManager] 项目里已经有别的 changeEvent，无法自动合并。'
        return 1
    else
        nl=$(newline_of "$fpmh")
        anchor OLD <<'EOF'
    void resizeEvent(QResizeEvent* event) override;
EOF
        anchor NEW <<'EOF'
    void resizeEvent(QResizeEvent* event) override;
    void changeEvent(QEvent* event) override;
EOF
        replace_once fpmh "$nl" "$OLD" "$NEW" 'FullscreenPagesManager.h（changeEvent 声明）' || return 1
        nl=$(newline_of "$fpmc")
        anchor OLD <<'EOF'
#include <QTimer>
EOF
        anchor NEW <<'EOF'
#include <QTimer>
#include <QApplication>
#include <QInputMethod>
EOF
        replace_once fpmc "$nl" "$OLD" "$NEW" 'FullscreenPagesManager.cpp（头文件）' || return 1
        anchor OLD <<'EOF'
        fullscreen_pages_mode = FullscreenPagesMode::Settings;
        startAnimation();
EOF
        anchor NEW <<'EOF'
        fullscreen_pages_mode = FullscreenPagesMode::Settings;
        startAnimation();
        // 本窗口是 Qt::Tool，在 Windows 上显示时不会被激活（SW_SHOWNOACTIVATE），
        // 没有焦点窗口时触摸点击输入框发出的触摸键盘请求会被 Qt 丢弃，所以设置页要主动激活窗口
        this->raise();
        this->activateWindow();
EOF
        replace_once fpmc "$nl" "$OLD" "$NEW" 'FullscreenPagesManager.cpp（打开设置时激活窗口）' || return 1
        anchor OLD <<'EOF'
void FullscreenPagesManager::resizeEvent(QResizeEvent* event) {
EOF
        anchor NEW <<'EOF'
void FullscreenPagesManager::changeEvent(QEvent* event) {
    QWidget::changeEvent(event);

    // 窗口被激活时，如果焦点已经在输入框上（例如激活前的那次触摸点击已经把焦点给了输入框，
    // 但当时窗口还没激活，触摸键盘请求被丢弃了），补发一次显示虚拟键盘的请求
    if (event->type() == QEvent::ActivationChange && this->isActiveWindow() && fullscreen_pages_mode == FullscreenPagesMode::Settings) {
        // 等 Qt 把焦点交给输入框之后再请求
        QTimer::singleShot(0, this, [this] {
            QWidget* focus_widget = QApplication::focusWidget();
            if (this->isActiveWindow() && focus_widget && this->isAncestorOf(focus_widget) && focus_widget->testAttribute(Qt::WA_InputMethodEnabled))
                QGuiApplication::inputMethod()->show();
            });
    }
}

void FullscreenPagesManager::resizeEvent(QResizeEvent* event) {
EOF
        replace_once fpmc "$nl" "$OLD" "$NEW" 'FullscreenPagesManager.cpp（激活时补发键盘请求）' || return 1
    fi

    # 2. 日历弹窗：红黑主题、格子放大
    if has "$scc" 'adjustTargetDateTimeCalendar'; then
        gray '  [跳过] 日历弹窗部分已修复'
    else
        nl=$(newline_of "$sch")
        anchor OLD <<'EOF'
#include <QDateTimeEdit>
EOF
        anchor NEW <<'EOF'
#include <QDateTimeEdit>
#include <QCalendarWidget>
EOF
        replace_once sch "$nl" "$OLD" "$NEW" 'SettingsContent.h（头文件）' || return 1
        anchor OLD <<'EOF'
    void connectEmissions();
EOF
        anchor NEW <<'EOF'
    void connectEmissions();
    void adjustTargetDateTimeCalendar();
EOF
        replace_once sch "$nl" "$OLD" "$NEW" 'SettingsContent.h（函数声明）' || return 1
        anchor OLD <<'EOF'
    QDateTimeEdit* TargetDateTimeEdit;
EOF
        anchor NEW <<'EOF'
    QDateTimeEdit* TargetDateTimeEdit;
    QCalendarWidget* TargetDateTimeCalendar;
EOF
        replace_once sch "$nl" "$OLD" "$NEW" 'SettingsContent.h（成员变量）' || return 1
        nl=$(newline_of "$scc")
        anchor OLD <<'EOF'
#include <QMessageBox>
EOF
        anchor NEW <<'EOF'
#include <QMessageBox>
#include <QToolButton>
#include <QTextCharFormat>
EOF
        replace_once scc "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（头文件）' || return 1
        anchor OLD <<'EOF'
    TargetDateTimeEdit->setDisplayFormat("yyyy-MM-dd HH:mm:ss"); // 设置显示格式
EOF
        anchor NEW <<'EOF'
    TargetDateTimeEdit->setDisplayFormat("yyyy-MM-dd HH:mm:ss"); // 设置显示格式
    // 目标时间的日历弹窗（默认弹窗太小、星期栏看不清，还会继承设置页的透明背景，这里换成自定义样式）
    TargetDateTimeCalendar = new QCalendarWidget(TargetDateTimeEdit);
    TargetDateTimeCalendar->setVerticalHeaderFormat(QCalendarWidget::NoVerticalHeader); // 不显示周数
    TargetDateTimeCalendar->setHorizontalHeaderFormat(QCalendarWidget::ShortDayNames);
    TargetDateTimeCalendar->setGridVisible(false);
    QTextCharFormat CalendarHeaderTextFormat; // 星期栏
    CalendarHeaderTextFormat.setBackground(QColor(255, 0, 0, 64));
    CalendarHeaderTextFormat.setForeground(QColor(255, 255, 255));
    TargetDateTimeCalendar->setHeaderTextFormat(CalendarHeaderTextFormat);
    QTextCharFormat CalendarWeekendTextFormat; // 周末
    CalendarWeekendTextFormat.setForeground(QColor(255, 110, 110));
    TargetDateTimeCalendar->setWeekdayTextFormat(Qt::Saturday, CalendarWeekendTextFormat);
    TargetDateTimeCalendar->setWeekdayTextFormat(Qt::Sunday, CalendarWeekendTextFormat);
    // 上一月、下一月按钮用文字箭头代替系统图标
    if (QToolButton* PrevMonthButton = TargetDateTimeCalendar->findChild<QToolButton*>("qt_calendar_prevmonth")) {
        PrevMonthButton->setIcon(QIcon());
        PrevMonthButton->setToolButtonStyle(Qt::ToolButtonTextOnly);
        PrevMonthButton->setText("<");
    }
    if (QToolButton* NextMonthButton = TargetDateTimeCalendar->findChild<QToolButton*>("qt_calendar_nextmonth")) {
        NextMonthButton->setIcon(QIcon());
        NextMonthButton->setToolButtonStyle(Qt::ToolButtonTextOnly);
        NextMonthButton->setText(">");
    }
    TargetDateTimeEdit->setCalendarWidget(TargetDateTimeCalendar);
EOF
        replace_once scc "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（创建日历弹窗）' || return 1
        anchor OLD <<'EOF'
void SettingsContentClass::resizeEvent(QResizeEvent* event) {
    QStackedWidget::resizeEvent(event);
EOF
        anchor NEW <<'EOF'
// 调整目标时间日历弹窗的大小和样式（随设置页高度缩放，格子足够大，方便触摸点选）
void SettingsContentClass::adjustTargetDateTimeCalendar() {
    const int unit = this->height() * 0.03; // 和输入框高度保持一致
    TargetDateTimeCalendar->setMinimumSize(unit * 2 * 7, unit * 1.6 * 8);
    TargetDateTimeCalendar->setStyleSheet(QString(R"(
            QCalendarWidget QWidget {
                background-color: rgb(40, 0, 0);
                color: white;
            }
            QCalendarWidget QWidget#qt_calendar_navigationbar {
                background-color: rgb(80, 0, 0);
            }
            QCalendarWidget QToolButton {
                background-color: transparent;
                color: white;
                border: none;
                border-radius: %1px;
                padding: %2px %3px;
            }
            QCalendarWidget QToolButton:hover {
                background-color: rgba(255, 0, 0, 0.3);
            }
            QCalendarWidget QToolButton:pressed {
                background-color: rgba(255, 0, 0, 0.5);
            }
            QCalendarWidget QToolButton::menu-indicator {
                image: none;
                width: 0px;
            }
            QCalendarWidget QMenu {
                background-color: rgb(40, 0, 0);
                color: white;
                border: none;
            }
            QCalendarWidget QMenu::item {
                padding: %2px %3px;
            }
            QCalendarWidget QMenu::item:selected {
                background-color: rgb(100, 0, 0);
            }
            QCalendarWidget QSpinBox {
                background-color: rgba(255, 0, 0, 0.25);
                color: white;
                border: none;
                border-radius: %1px;
                selection-background-color: red;
            }
            QCalendarWidget QAbstractItemView {
                background-color: rgb(40, 0, 0);
                color: white;
                selection-background-color: red;
                selection-color: white;
                outline: none;
                border: none;
            }
            QCalendarWidget QAbstractItemView:disabled {
                color: rgb(120, 80, 80);
            }
        )").arg(unit / 4).arg(unit / 6).arg(unit / 3)
    );
}

void SettingsContentClass::resizeEvent(QResizeEvent* event) {
    QStackedWidget::resizeEvent(event);

    adjustTargetDateTimeCalendar();
EOF
        replace_once scc "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（日历样式）' || return 1
    fi
}

if ! edit; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。'
    finish 1
fi

if [ "$fpmh" = "$fpmh0" ] && [ "$fpmc" = "$fpmc0" ] && [ "$sch" = "$sch0" ] && [ "$scc" = "$scc0" ]; then
    echo
    ok '这个项目已经修复过了，没有需要修改的地方。'
    finish 0
fi

# 全部对上了才开始写：先备份
start_backup "$P_FPM_H" "$P_FPM_C" "$P_SC_H" "$P_SC_C"
[ "$fpmh" != "$fpmh0" ] && printf '%s' "$fpmh" > "$ROOT/$P_FPM_H" && ok "  [已修改] $P_FPM_H"
[ "$fpmc" != "$fpmc0" ] && printf '%s' "$fpmc" > "$ROOT/$P_FPM_C" && ok "  [已修改] $P_FPM_C"
[ "$sch" != "$sch0" ] && printf '%s' "$sch" > "$ROOT/$P_SC_H" && ok "  [已修改] $P_SC_H"
[ "$scc" != "$scc0" ] && printf '%s' "$scc" > "$ROOT/$P_SC_C" && ok "  [已修改] $P_SC_C"

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
