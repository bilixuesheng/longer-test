#!/usr/bin/env bash
# 悬浮条隐藏规则 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 floating-bar-hide-rules.patch 相同。需要先应用 features/floating-bar（悬浮条淡化、点击穿透和 Win11 样式）。
# 任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 悬浮条隐藏规则 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"

if ! grep -q 'reapplyClickThrough' "$ROOT/src/ui/FloatingBar.cpp" 2>/dev/null; then
    err '这个项目还没有应用“悬浮条淡化、点击穿透和 Win11 样式”（features/floating-bar）。'
    warn '请先用 features/floating-bar/one-click 里的 apply.sh 应用它，再运行这个。没有修改任何文件。'
    finish 1
fi

P_0=src/CMakeLists.txt
P_1=src/core/ConfigManager.h
P_2=src/core/ConfigManager.cpp
P_3=src/ui/FloatingBar.h
P_4=src/ui/FloatingBar.cpp
P_5=src/ui/SettingsContent.h
P_6=src/ui/SettingsContent.cpp
P_7=src/core/UniversalTimer2.cpp
N_0=src/core/HideRules.h
N_1=src/core/HideRules.cpp
N_2=src/core/ForegroundWindow.h
N_3=src/core/ForegroundWindow.cpp
N_4=src/ui/HideRulesEditor.h
N_5=src/ui/HideRulesEditor.cpp
MODCOUNT=8
NEWCOUNT=6
for ((i = 0; i < MODCOUNT; i++)); do
    p=P_$i
    if ! load "f$i" "$ROOT/${!p}"; then
        err "读取项目文件失败：${!p}"
        finish 1
    fi
    v=f$i
    printf -v "f${i}_0" '%s' "${!v}" # 保存原始内容，最后比较哪些文件改了
done

# 新文件的内容
    anchor n0 <<'EOF'
#pragma once

// 悬浮条隐藏规则集，结构和判断方式参考 ClassIsland 的规则集：规则集 → 规则组 → 规则

#include <QString>
#include <QTime>
#include <QDateTime>
#include <QList>
#include <QJsonObject>

// 前台窗口信息（由 ForegroundWindow 按平台获取）
struct ForegroundWindowInfo {
    bool valid = false; // 是否取到了前台窗口
    bool own = false; // 是不是万能倒计时自己的窗口（设置中心、全屏提醒等）
    QString title; // 标题
    QString className; // 类名（Linux 上是 WM_CLASS 的类名部分）
    QString processName; // 进程名（Windows 上不带 .exe）
    bool maximized = false; // 最大化
    bool fullscreen = false; // 全屏
    bool minimized = false; // 最小化
};

enum class HideRuleType {
    None, // 未选择（不参与判断）
    WindowTitle, // 前台窗口标题
    WindowClassName, // 前台窗口类名
    WindowProcessName, // 前台窗口进程
    WindowStatus, // 前台窗口状态是
    TimeRange, // 当前时间在时间段内
    Weekday, // 今天是星期
    RemainingDays, // 距目标时间剩余天数
    AlwaysTrue, // 总是为真
    AlwaysFalse // 总是为假
};

enum class HideRuleWindowStatus {
    Normal, // 普通
    Maximized, // 最大化
    Minimized, // 最小化
    Fullscreen // 全屏
};

enum class HideRuleCompare {
    LessOrEqual, // ≤
    GreaterOrEqual, // ≥
    Equal // =
};

// 满足状态，用于在编辑界面里显示
enum class HideRuleState {
    Unknown, // 未判断 / 不参与判断
    Unsatisfied, // 不满足
    Satisfied // 满足
};

struct HideRule {
    HideRuleType type = HideRuleType::None;
    bool reversed = false; // 反转（非）

    // 前台窗口标题 / 类名 / 进程：和 ClassIsland 一样，不用正则时要完全相等，用正则时只要能匹配上
    QString text;
    bool regex = false;

    HideRuleWindowStatus windowStatus = HideRuleWindowStatus::Maximized; // 前台窗口状态

    QTime startTime = QTime(8, 0); // 时间段开始（结束早于开始时表示跨过午夜）
    QTime endTime = QTime(17, 0); // 时间段结束

    unsigned weekdays = 0b0011111; // 星期：第 0 位是星期一 …… 第 6 位是星期日，默认周一到周五

    HideRuleCompare compare = HideRuleCompare::LessOrEqual; // 剩余天数比较方式
    int days = 0; // 剩余天数

    HideRuleState state = HideRuleState::Unknown;

    QJsonObject toJson() const;
    static HideRule fromJson(const QJsonObject& json);
};

enum class HideRuleLogicalMode {
    Or, // 任一满足
    And // 全部满足
};

struct HideRuleGroup {
    QList<HideRule> rules = { HideRule() };
    HideRuleLogicalMode mode = HideRuleLogicalMode::And; // 组内默认全部满足，和 ClassIsland 一样
    bool reversed = false;
    bool enabled = true;

    HideRuleState state = HideRuleState::Unknown;

    QJsonObject toJson() const;
    static HideRuleGroup fromJson(const QJsonObject& json);
};

struct HideRuleset {
    QList<HideRuleGroup> groups = { HideRuleGroup() };
    HideRuleLogicalMode mode = HideRuleLogicalMode::Or; // 组与组之间默认任一满足，和 ClassIsland 一样
    bool reversed = false;

    HideRuleState state = HideRuleState::Unknown;

    QJsonObject toJson() const;
    static HideRuleset fromJson(const QJsonObject& json);
};

// 判断时需要的当前状态
struct HideRuleContext {
    ForegroundWindowInfo window;
    QDateTime now;
    long long remainingDays = 0; // 距目标时间剩余天数（和悬浮条上显示的天数一致）
};

// 判断规则集是否满足，并把每个组和规则的满足状态写回去（供编辑界面显示）
bool evaluateHideRuleset(HideRuleset& ruleset, const HideRuleContext& context);
EOF
    anchor n1 <<'EOF'
#include "core/HideRules.h"

#include <QJsonArray>
#include <QRegularExpression>

// 规则类型在 JSON 里的名字
static const QList<QPair<HideRuleType, QString>> RULE_TYPE_NAMES = {
    { HideRuleType::None, "none" },
    { HideRuleType::WindowTitle, "window_title" },
    { HideRuleType::WindowClassName, "window_class_name" },
    { HideRuleType::WindowProcessName, "window_process_name" },
    { HideRuleType::WindowStatus, "window_status" },
    { HideRuleType::TimeRange, "time_range" },
    { HideRuleType::Weekday, "weekday" },
    { HideRuleType::RemainingDays, "remaining_days" },
    { HideRuleType::AlwaysTrue, "always_true" },
    { HideRuleType::AlwaysFalse, "always_false" },
};

static QString ruleTypeToString(HideRuleType type)
{
    for (const auto& [t, name] : RULE_TYPE_NAMES)
        if (t == type) return name;
    return "none";
}

static HideRuleType ruleTypeFromString(const QString& name)
{
    for (const auto& [t, n] : RULE_TYPE_NAMES)
        if (n == name) return t;
    return HideRuleType::None;
}

static QString modeToString(HideRuleLogicalMode mode) { return mode == HideRuleLogicalMode::And ? "and" : "or"; }
static HideRuleLogicalMode modeFromString(const QString& name, HideRuleLogicalMode fallback)
{
    if (name == "and") return HideRuleLogicalMode::And;
    if (name == "or") return HideRuleLogicalMode::Or;
    return fallback;
}

QJsonObject HideRule::toJson() const
{
    QJsonObject json;
    json["type"] = ruleTypeToString(type);
    json["reversed"] = reversed;
    switch (type) {
        case HideRuleType::WindowTitle:
        case HideRuleType::WindowClassName:
        case HideRuleType::WindowProcessName:
            json["text"] = text;
            json["regex"] = regex;
            break;
        case HideRuleType::WindowStatus:
            json["window_status"] = static_cast<int>(windowStatus);
            break;
        case HideRuleType::TimeRange:
            json["start"] = startTime.toString("HH:mm:ss");
            json["end"] = endTime.toString("HH:mm:ss");
            break;
        case HideRuleType::Weekday: {
            QJsonArray array;
            for (int i = 0; i < 7; i++)
                if (weekdays & (1u << i)) array.append(i + 1);
            json["weekdays"] = array;
            break;
        }
        case HideRuleType::RemainingDays:
            json["compare"] = compare == HideRuleCompare::LessOrEqual ? "<=" : (compare == HideRuleCompare::GreaterOrEqual ? ">=" : "=");
            json["days"] = days;
            break;
        default:
            break;
    }
    return json;
}

HideRule HideRule::fromJson(const QJsonObject& json)
{
    HideRule rule;
    rule.type = ruleTypeFromString(json["type"].toString());
    rule.reversed = json["reversed"].toBool(false);
    rule.text = json["text"].toString();
    rule.regex = json["regex"].toBool(false);
    rule.windowStatus = static_cast<HideRuleWindowStatus>(qBound(0, json["window_status"].toInt(static_cast<int>(HideRuleWindowStatus::Maximized)), 3));
    if (json.contains("start")) rule.startTime = QTime::fromString(json["start"].toString(), "HH:mm:ss");
    if (json.contains("end")) rule.endTime = QTime::fromString(json["end"].toString(), "HH:mm:ss");
    if (!rule.startTime.isValid()) rule.startTime = QTime(8, 0);
    if (!rule.endTime.isValid()) rule.endTime = QTime(17, 0);
    if (json.contains("weekdays")) {
        rule.weekdays = 0;
        for (const QJsonValue& value : json["weekdays"].toArray()) {
            const int day = value.toInt();
            if (day >= 1 && day <= 7) rule.weekdays |= 1u << (day - 1);
        }
    }
    const QString compare = json["compare"].toString("<=");
    rule.compare = compare == ">=" ? HideRuleCompare::GreaterOrEqual : (compare == "=" ? HideRuleCompare::Equal : HideRuleCompare::LessOrEqual);
    rule.days = json["days"].toInt(0);
    return rule;
}

QJsonObject HideRuleGroup::toJson() const
{
    QJsonObject json;
    QJsonArray array;
    for (const HideRule& rule : rules) array.append(rule.toJson());
    json["rules"] = array;
    json["mode"] = modeToString(mode);
    json["reversed"] = reversed;
    json["enabled"] = enabled;
    return json;
}

HideRuleGroup HideRuleGroup::fromJson(const QJsonObject& json)
{
    HideRuleGroup group;
    group.rules.clear();
    for (const QJsonValue& value : json["rules"].toArray()) group.rules.append(HideRule::fromJson(value.toObject()));
    group.mode = modeFromString(json["mode"].toString(), HideRuleLogicalMode::And);
    group.reversed = json["reversed"].toBool(false);
    group.enabled = json["enabled"].toBool(true);
    return group;
}

QJsonObject HideRuleset::toJson() const
{
    QJsonObject json;
    QJsonArray array;
    for (const HideRuleGroup& group : groups) array.append(group.toJson());
    json["groups"] = array;
    json["mode"] = modeToString(mode);
    json["reversed"] = reversed;
    return json;
}

HideRuleset HideRuleset::fromJson(const QJsonObject& json)
{
    HideRuleset ruleset;
    ruleset.groups.clear();
    for (const QJsonValue& value : json["groups"].toArray()) ruleset.groups.append(HideRuleGroup::fromJson(value.toObject()));
    ruleset.mode = modeFromString(json["mode"].toString(), HideRuleLogicalMode::Or);
    ruleset.reversed = json["reversed"].toBool(false);
    return ruleset;
}

static HideRuleState toState(bool value) { return value ? HideRuleState::Satisfied : HideRuleState::Unsatisfied; }

static bool isStringMatching(const HideRule& rule, const QString& str)
{
    if (!rule.regex)
        return str == rule.text;
    const QRegularExpression expression(rule.text);
    return expression.isValid() && expression.match(str).hasMatch();
}

// 单条规则是否满足（不含反转）
static bool isRuleSatisfied(const HideRule& rule, const HideRuleContext& context)
{
    const ForegroundWindowInfo& window = context.window;
    switch (rule.type) {
        // 没有前台窗口（包括万能倒计时自己的窗口在前台）时，前台窗口相关的规则都不满足
        case HideRuleType::WindowTitle:
            return window.valid && isStringMatching(rule, window.title);
        case HideRuleType::WindowClassName:
            return window.valid && isStringMatching(rule, window.className);
        case HideRuleType::WindowProcessName:
            return window.valid && isStringMatching(rule, window.processName);
        case HideRuleType::WindowStatus:
            if (!window.valid)
                return false;
            // 与 ClassIsland 相同：普通 = 都不是，最大化 = 最大化但不是全屏
            switch (rule.windowStatus) {
                case HideRuleWindowStatus::Normal: return !(window.fullscreen || window.maximized || window.minimized);
                case HideRuleWindowStatus::Maximized: return window.maximized && !window.fullscreen;
                case HideRuleWindowStatus::Minimized: return window.minimized;
                case HideRuleWindowStatus::Fullscreen: return window.fullscreen;
            }
            return false;
        case HideRuleType::TimeRange: {
            const QTime time = context.now.time();
            if (rule.startTime <= rule.endTime)
                return time >= rule.startTime && time < rule.endTime;
            return time >= rule.startTime || time < rule.endTime; // 跨过午夜
        }
        case HideRuleType::Weekday:
            return rule.weekdays & (1u << (context.now.date().dayOfWeek() - 1));
        case HideRuleType::RemainingDays:
            switch (rule.compare) {
                case HideRuleCompare::LessOrEqual: return context.remainingDays <= rule.days;
                case HideRuleCompare::GreaterOrEqual: return context.remainingDays >= rule.days;
                case HideRuleCompare::Equal: return context.remainingDays == rule.days;
            }
            return false;
        case HideRuleType::AlwaysTrue:
            return true;
        case HideRuleType::AlwaysFalse:
        case HideRuleType::None:
            return false;
    }
    return false;
}

// 规则组是否满足；组里没有选了类型的规则时返回 -1（不参与判断），和 ClassIsland 一样
static int isGroupSatisfied(HideRuleGroup& group, const HideRuleContext& context)
{
    bool hasRule = false;
    for (const HideRule& rule : group.rules)
        if (rule.type != HideRuleType::None) hasRule = true;
    if (!hasRule)
        return -1;

    bool satisfied = group.mode == HideRuleLogicalMode::And;
    for (HideRule& rule : group.rules) {
        if (rule.type == HideRuleType::None)
            continue;
        const bool result = isRuleSatisfied(rule, context) ^ rule.reversed;
        rule.state = toState(result);
        if (!result && group.mode == HideRuleLogicalMode::And) {
            satisfied = false;
            break;
        }
        if (result && group.mode == HideRuleLogicalMode::Or) {
            satisfied = true;
            break;
        }
    }
    return (satisfied ^ group.reversed) ? 1 : 0;
}

bool evaluateHideRuleset(HideRuleset& ruleset, const HideRuleContext& context)
{
    for (HideRuleGroup& group : ruleset.groups) {
        group.state = HideRuleState::Unknown;
        for (HideRule& rule : group.rules)
            rule.state = HideRuleState::Unknown;
    }
    if (ruleset.groups.isEmpty()) {
        ruleset.state = HideRuleState::Unsatisfied;
        return false;
    }

    bool satisfied = ruleset.mode == HideRuleLogicalMode::And;
    for (HideRuleGroup& group : ruleset.groups) {
        if (!group.enabled)
            continue;
        const int result = isGroupSatisfied(group, context);
        if (result < 0)
            continue;
        group.state = toState(result == 1);
        if (result == 0 && ruleset.mode == HideRuleLogicalMode::And) {
            satisfied = false;
            break;
        }
        if (result == 1 && ruleset.mode == HideRuleLogicalMode::Or) {
            satisfied = true;
            break;
        }
    }
    satisfied ^= ruleset.reversed;
    ruleset.state = toState(satisfied);
    return satisfied;
}
EOF
    anchor n2 <<'EOF'
#pragma once

#include "core/HideRules.h"

// 获取前台窗口的标题、类名、进程名和状态。万能倒计时自己的窗口（设置中心、全屏提醒等）在前台时 own = true
// Windows 用 Win32 API；Linux 用 X11（需要编译时找到 libxcb，否则一直返回 valid = false）；其他平台一直返回 valid = false
ForegroundWindowInfo queryForegroundWindow();
EOF
    anchor n3 <<'EOF'
#include "core/ForegroundWindow.h"

#include <QFileInfo>

#if defined(Q_OS_WIN)

#include <windows.h>

static bool containsRect(const RECT& outer, const RECT& inner)
{
    return outer.left <= inner.left && outer.top <= inner.top && outer.right >= inner.right && outer.bottom >= inner.bottom;
}

ForegroundWindowInfo queryForegroundWindow()
{
    ForegroundWindowInfo info;
    HWND hwnd = GetForegroundWindow();
    if (!hwnd)
        return info;
    DWORD pid = 0;
    GetWindowThreadProcessId(hwnd, &pid);
    if (pid == 0)
        return info;

    info.valid = true;
    info.own = pid == GetCurrentProcessId();
    wchar_t buffer[1024];
    int length = GetWindowTextW(hwnd, buffer, 1024);
    info.title = QString::fromWCharArray(buffer, qMax(0, length));
    length = GetClassNameW(hwnd, buffer, 1024);
    info.className = QString::fromWCharArray(buffer, qMax(0, length));

    if (HANDLE process = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, pid)) {
        DWORD size = 1024;
        if (QueryFullProcessImageNameW(process, 0, buffer, &size))
            info.processName = QFileInfo(QString::fromWCharArray(buffer, int(size))).completeBaseName(); // 和 ClassIsland 一样不带 .exe
        CloseHandle(process);
    }

    info.minimized = IsIconic(hwnd);
    // 与 ClassIsland 相同：桌面（WorkerW / Progman）不算最大化或全屏；窗口盖住整个屏幕算全屏，盖住工作区（不含任务栏）算最大化
    if (info.className != "WorkerW" && info.className != "Progman") {
        RECT rect;
        MONITORINFO monitor = {};
        monitor.cbSize = sizeof(monitor);
        const POINT origin = { 0, 0 };
        if (GetWindowRect(hwnd, &rect) && GetMonitorInfoW(MonitorFromPoint(origin, MONITOR_DEFAULTTOPRIMARY), &monitor)) {
            info.fullscreen = containsRect(rect, monitor.rcMonitor);
            info.maximized = containsRect(rect, monitor.rcWork);
        }
    }
    return info;
}

#elif defined(UT_HAVE_XCB)

#include <QFile>
#include <QHash>

#include <xcb/xcb.h>
#include <cstdlib>
#include <cstring>
#include <unistd.h>

static xcb_connection_t* x11Connection()
{
    static xcb_connection_t* connection = nullptr;
    static bool tried = false;
    if (!tried) {
        tried = true;
        connection = xcb_connect(nullptr, nullptr);
        if (xcb_connection_has_error(connection)) {
            xcb_disconnect(connection);
            connection = nullptr;
        }
    }
    return connection;
}

static xcb_atom_t x11Atom(xcb_connection_t* connection, const char* name)
{
    static QHash<QByteArray, xcb_atom_t> atoms;
    const auto it = atoms.constFind(name);
    if (it != atoms.constEnd())
        return *it;
    xcb_atom_t atom = XCB_ATOM_NONE;
    if (xcb_intern_atom_reply_t* reply = xcb_intern_atom_reply(connection, xcb_intern_atom(connection, 0, uint16_t(strlen(name)), name), nullptr)) {
        atom = reply->atom;
        free(reply);
    }
    atoms.insert(name, atom);
    return atom;
}

static QByteArray x11Property(xcb_connection_t* connection, xcb_window_t window, xcb_atom_t property, xcb_atom_t type)
{
    QByteArray result;
    xcb_get_property_reply_t* reply = xcb_get_property_reply(connection, xcb_get_property(connection, 0, window, property, type, 0, 4096), nullptr);
    if (reply) {
        if (reply->type != XCB_ATOM_NONE)
            result = QByteArray(static_cast<const char*>(xcb_get_property_value(reply)), xcb_get_property_value_length(reply) * (reply->format / 8));
        free(reply);
    }
    return result;
}

static quint32 x11Cardinal(const QByteArray& value)
{
    quint32 result = 0;
    if (value.size() >= 4)
        memcpy(&result, value.constData(), 4);
    return result;
}

ForegroundWindowInfo queryForegroundWindow()
{
    ForegroundWindowInfo info;
    xcb_connection_t* connection = x11Connection();
    if (!connection)
        return info;
    const xcb_window_t root = xcb_setup_roots_iterator(xcb_get_setup(connection)).data->root;

    const xcb_window_t window = x11Cardinal(x11Property(connection, root, x11Atom(connection, "_NET_ACTIVE_WINDOW"), XCB_ATOM_WINDOW));
    if (window == XCB_WINDOW_NONE)
        return info;
    const quint32 pid = x11Cardinal(x11Property(connection, window, x11Atom(connection, "_NET_WM_PID"), XCB_ATOM_CARDINAL));
    info.valid = true;
    info.own = pid == quint32(getpid());
    QByteArray title = x11Property(connection, window, x11Atom(connection, "_NET_WM_NAME"), x11Atom(connection, "UTF8_STRING"));
    info.title = title.isEmpty() ? QString::fromLatin1(x11Property(connection, window, XCB_ATOM_WM_NAME, XCB_ATOM_STRING)) : QString::fromUtf8(title);
    const QList<QByteArray> wmClass = x11Property(connection, window, XCB_ATOM_WM_CLASS, XCB_ATOM_STRING).split('\0'); // “实例名\0类名\0”
    info.className = wmClass.size() >= 2 ? QString::fromLocal8Bit(wmClass[1]) : QString();
    if (pid != 0) {
        QFile comm(QString("/proc/%1/comm").arg(pid));
        if (comm.open(QIODevice::ReadOnly))
            info.processName = QString::fromLocal8Bit(comm.readAll()).trimmed();
    }

    const QByteArray states = x11Property(connection, window, x11Atom(connection, "_NET_WM_STATE"), XCB_ATOM_ATOM);
    bool maximizedVert = false, maximizedHorz = false;
    for (int i = 0; i + 4 <= states.size(); i += 4) {
        const xcb_atom_t state = x11Cardinal(states.mid(i, 4));
        if (state == x11Atom(connection, "_NET_WM_STATE_FULLSCREEN")) info.fullscreen = true;
        else if (state == x11Atom(connection, "_NET_WM_STATE_MAXIMIZED_VERT")) maximizedVert = true;
        else if (state == x11Atom(connection, "_NET_WM_STATE_MAXIMIZED_HORZ")) maximizedHorz = true;
        else if (state == x11Atom(connection, "_NET_WM_STATE_HIDDEN")) info.minimized = true;
    }
    info.maximized = maximizedVert && maximizedHorz;
    return info;
}

#else

ForegroundWindowInfo queryForegroundWindow()
{
    return ForegroundWindowInfo();
}

#endif
EOF
    anchor n4 <<'EOF'
#pragma once

#include "core/ConfigManager.h"
#include "ui/FloatingBar.h"

#include <QDialog>
#include <QVBoxLayout>
#include <QLabel>
#include <QComboBox>
#include <QPushButton>

// 悬浮条隐藏规则集编辑窗口，布局参考 ClassIsland 的规则集编辑器：规则集 → 规则组 → 规则
class HideRulesEditorClass : public QDialog
{
    Q_OBJECT

public:
    HideRulesEditorClass(QWidget* parent, ConfigManager& cfg, FloatingBarClass* bar, const QFont& font);

private:

    ConfigManager& config;
    FloatingBarClass* FloatingBar;

    QWidget* GroupsWidget; // 放所有规则组的容器（在滚动区域里）
    QVBoxLayout* GroupsLayout;
    QPushButton* RulesetReversedButton;
    QComboBox* RulesetModeComboBox;
    QLabel* RulesetStateLabel;
    QLabel* ForegroundWindowLabel;
    QLabel* TitleLabel;
    QFont m_font;

    QList<QLabel*> GroupStateLabels;
    QList<QList<QLabel*>> RuleStateLabels;

    HideRuleset& ruleset() { return config.floating_bar.floating_bar_hide_rules; }

    void rebuild(); // 按规则集重新生成所有规则组和规则的控件
    void scheduleRebuild(); // 增删规则组 / 规则、改规则类型后调用（不能在控件自己的信号里直接删除它）
    void save();
    void refreshStates(); // 刷新满足状态和前台窗口信息
    void applyFont(); // 和设置中心一样给每个控件设置字体（标题除外）

    QWidget* createGroupWidget(int groupIndex);
    QWidget* createRuleWidget(int groupIndex, int ruleIndex);
    QWidget* createRuleSettingsWidget(int groupIndex, int ruleIndex);
    QComboBox* createComboBox(QWidget* parent, const QStringList& items, int currentIndex);
    QPushButton* createReversedButton(QWidget* parent, bool checked);
};
EOF
    anchor n5 <<'EOF'
#include "ui/HideRulesEditor.h"

#include <QApplication>
#include <QScreen>
#include <QScrollArea>
#include <QHBoxLayout>
#include <QFrame>
#include <QCheckBox>
#include <QLineEdit>
#include <QSpinBox>
#include <QTimeEdit>
#include <QListView>
#include <QTimer>

// 规则类型的显示名称，顺序和 HideRuleType 一致；前四个和 ClassIsland 的名称相同
static const QStringList RULE_TYPE_TEXTS = {
    QObject::tr("请选择规则"),
    QObject::tr("前台窗口标题"),
    QObject::tr("前台窗口类名"),
    QObject::tr("前台窗口进程"),
    QObject::tr("前台窗口状态是"),
    QObject::tr("当前时间在时间段内"),
    QObject::tr("今天是星期"),
    QObject::tr("距目标时间剩余天数"),
    QObject::tr("总是为真"),
    QObject::tr("总是为假"),
};

static QString stateText(HideRuleState state)
{
    switch (state) {
        case HideRuleState::Satisfied: return QObject::tr("● 满足");
        case HideRuleState::Unsatisfied: return QObject::tr("○ 不满足");
        default: return QObject::tr("－");
    }
}

static QString stateColor(HideRuleState state)
{
    switch (state) {
        case HideRuleState::Satisfied: return "rgb(120, 230, 120)";
        case HideRuleState::Unsatisfied: return "gray";
        default: return "gray";
    }
}

static void setStateLabel(QLabel* label, HideRuleState state)
{
    label->setText(stateText(state));
    label->setStyleSheet("color: " + stateColor(state) + ";");
}

HideRulesEditorClass::HideRulesEditorClass(QWidget* parent, ConfigManager& cfg, FloatingBarClass* bar, const QFont& font)
    : QDialog(parent), config(cfg), FloatingBar(bar), m_font(font)
{
    this->setObjectName("HideRulesEditor");
    this->setWindowFlags(Qt::Dialog | Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint);
    this->setModal(true);
    // 输入框等控件沿用设置中心的样式表（从父控件继承），这里只补上窗口背景、规则组边框和“非”按钮按下的样式
    this->setStyleSheet(R"(
        #HideRulesEditor { background-color: rgb(25, 0, 0); border: 1px solid red; }
        #HideRuleGroup { border: 1px solid rgba(255, 0, 0, 0.5); }
        QPushButton:checked { background-color: rgba(255, 0, 0, 0.7); }
        QLabel, QCheckBox { color: white; }
        QScrollArea, #HideRuleGroups { background-color: transparent; border: none; }
        QScrollBar:vertical { background: transparent; width: 10px; }
        QScrollBar::handle:vertical { background: rgba(255, 0, 0, 0.5); min-height: 30px; border-radius: 5px; }
        QScrollBar::add-line:vertical, QScrollBar::sub-line:vertical { height: 0px; }
        QScrollBar::add-page:vertical, QScrollBar::sub-page:vertical { background: none; }
    )");

    const QRect desktop = QApplication::primaryScreen()->geometry();
    this->resize(desktop.width() * 0.7, desktop.height() * 0.8);
    this->move(desktop.x() + (desktop.width() - this->width()) / 2, desktop.y() + (desktop.height() - this->height()) / 2);

    QVBoxLayout* layout = new QVBoxLayout(this);
    layout->setContentsMargins(25, 25, 25, 25);

    TitleLabel = new QLabel(tr("悬浮条隐藏规则集"), this);
    TitleLabel->setStyleSheet("color: red;");
    layout->addWidget(TitleLabel);
    layout->addWidget(new QLabel(tr("满足下面的规则集时隐藏悬浮条。"), this));

    ForegroundWindowLabel = new QLabel(this);
    ForegroundWindowLabel->setWordWrap(true);
    ForegroundWindowLabel->setTextInteractionFlags(Qt::TextSelectableByMouse);
    layout->addWidget(ForegroundWindowLabel);

    // 规则集：非 + 规则组任一 / 全部满足时 + 添加组
    QHBoxLayout* rulesetLayout = new QHBoxLayout;
    RulesetReversedButton = createReversedButton(this, ruleset().reversed);
    connect(RulesetReversedButton, &QPushButton::toggled, this, [this](bool checked) {
        ruleset().reversed = checked;
        save();
        });
    RulesetModeComboBox = createComboBox(this, { tr("规则组任一满足时"), tr("规则组全部满足时") }, ruleset().mode == HideRuleLogicalMode::And ? 1 : 0);
    connect(RulesetModeComboBox, &QComboBox::currentIndexChanged, this, [this](int index) {
        ruleset().mode = index == 1 ? HideRuleLogicalMode::And : HideRuleLogicalMode::Or;
        save();
        });
    QPushButton* addGroupButton = new QPushButton(tr("添加组"), this);
    connect(addGroupButton, &QPushButton::clicked, this, [this] {
        ruleset().groups.append(HideRuleGroup());
        save();
        scheduleRebuild();
        });
    RulesetStateLabel = new QLabel(this);
    rulesetLayout->addWidget(RulesetReversedButton);
    rulesetLayout->addWidget(RulesetModeComboBox);
    rulesetLayout->addWidget(addGroupButton);
    rulesetLayout->addStretch();
    rulesetLayout->addWidget(RulesetStateLabel);
    layout->addLayout(rulesetLayout);

    QScrollArea* scrollArea = new QScrollArea(this);
    scrollArea->setWidgetResizable(true);
    scrollArea->setHorizontalScrollBarPolicy(Qt::ScrollBarAlwaysOff);
    GroupsWidget = new QWidget(scrollArea);
    GroupsWidget->setObjectName("HideRuleGroups");
    GroupsLayout = new QVBoxLayout(GroupsWidget);
    GroupsLayout->setContentsMargins(0, 0, 0, 0);
    scrollArea->setWidget(GroupsWidget);
    layout->addWidget(scrollArea, 1);

    QPushButton* doneButton = new QPushButton(tr("完成"), this);
    connect(doneButton, &QPushButton::clicked, this, &QDialog::accept);
    QHBoxLayout* bottomLayout = new QHBoxLayout;
    bottomLayout->addStretch();
    bottomLayout->addWidget(doneButton);
    layout->addLayout(bottomLayout);

    connect(FloatingBar, &FloatingBarClass::hideRulesEvaluated, this, &HideRulesEditorClass::refreshStates);

    rebuild();
}

QComboBox* HideRulesEditorClass::createComboBox(QWidget* parent, const QStringList& items, int currentIndex)
{
    QComboBox* comboBox = new QComboBox(parent);
    QListView* listView = new QListView(comboBox); // 和设置中心一样，换成 QListView 下拉列表的样式表才生效
    listView->setAutoFillBackground(false);
    comboBox->setView(listView);
    comboBox->addItems(items);
    comboBox->setCurrentIndex(currentIndex);
    return comboBox;
}

QPushButton* HideRulesEditorClass::createReversedButton(QWidget* parent, bool checked)
{
    QPushButton* button = new QPushButton(tr("非"), parent);
    button->setCheckable(true);
    button->setChecked(checked);
    button->setToolTip(tr("反转"));
    return button;
}

void HideRulesEditorClass::save()
{
    config.write();
}

void HideRulesEditorClass::scheduleRebuild()
{
    QTimer::singleShot(0, this, &HideRulesEditorClass::rebuild);
}

void HideRulesEditorClass::rebuild()
{
    while (QLayoutItem* item = GroupsLayout->takeAt(0)) {
        if (QWidget* widget = item->widget())
            widget->deleteLater();
        delete item;
    }
    GroupStateLabels.clear();
    RuleStateLabels.clear();

    for (int i = 0; i < ruleset().groups.size(); i++)
        GroupsLayout->addWidget(createGroupWidget(i));
    GroupsLayout->addStretch();
    applyFont();
    refreshStates();
}

void HideRulesEditorClass::applyFont()
{
    for (QWidget* child : this->findChildren<QWidget*>())
        child->setFont(m_font);
    QFont titleFont = m_font;
    titleFont.setPixelSize(m_font.pixelSize() * 1.5);
    TitleLabel->setFont(titleFont);
}

QWidget* HideRulesEditorClass::createGroupWidget(int groupIndex)
{
    HideRuleGroup& group = ruleset().groups[groupIndex];
    QFrame* frame = new QFrame(GroupsWidget);
    frame->setObjectName("HideRuleGroup");
    QVBoxLayout* layout = new QVBoxLayout(frame);

    // 规则组：启用 + 非 + 规则任一 / 全部满足时 …… 复制 删除
    QHBoxLayout* headerLayout = new QHBoxLayout;
    QCheckBox* enabledCheckBox = new QCheckBox(tr("启用"), frame);
    enabledCheckBox->setChecked(group.enabled);
    connect(enabledCheckBox, &QCheckBox::toggled, this, [this, groupIndex](bool checked) {
        ruleset().groups[groupIndex].enabled = checked;
        save();
        });
    QPushButton* reversedButton = createReversedButton(frame, group.reversed);
    connect(reversedButton, &QPushButton::toggled, this, [this, groupIndex](bool checked) {
        ruleset().groups[groupIndex].reversed = checked;
        save();
        });
    QComboBox* modeComboBox = createComboBox(frame, { tr("规则任一满足时"), tr("规则全部满足时") }, group.mode == HideRuleLogicalMode::And ? 1 : 0);
    connect(modeComboBox, &QComboBox::currentIndexChanged, this, [this, groupIndex](int index) {
        ruleset().groups[groupIndex].mode = index == 1 ? HideRuleLogicalMode::And : HideRuleLogicalMode::Or;
        save();
        });
    QLabel* stateLabel = new QLabel(frame);
    GroupStateLabels.append(stateLabel);
    QPushButton* copyButton = new QPushButton(tr("复制"), frame);
    connect(copyButton, &QPushButton::clicked, this, [this, groupIndex] {
        ruleset().groups.insert(groupIndex + 1, ruleset().groups[groupIndex]);
        save();
        scheduleRebuild();
        });
    QPushButton* deleteButton = new QPushButton(tr("删除"), frame);
    connect(deleteButton, &QPushButton::clicked, this, [this, groupIndex] {
        ruleset().groups.removeAt(groupIndex);
        save();
        scheduleRebuild();
        });
    headerLayout->addWidget(enabledCheckBox);
    headerLayout->addWidget(reversedButton);
    headerLayout->addWidget(modeComboBox);
    headerLayout->addStretch();
    headerLayout->addWidget(stateLabel);
    headerLayout->addWidget(copyButton);
    headerLayout->addWidget(deleteButton);
    layout->addLayout(headerLayout);

    RuleStateLabels.append(QList<QLabel*>());
    for (int i = 0; i < group.rules.size(); i++)
        layout->addWidget(createRuleWidget(groupIndex, i));

    QPushButton* addRuleButton = new QPushButton(tr("添加规则"), frame);
    connect(addRuleButton, &QPushButton::clicked, this, [this, groupIndex] {
        ruleset().groups[groupIndex].rules.append(HideRule());
        save();
        scheduleRebuild();
        });
    QHBoxLayout* addRuleLayout = new QHBoxLayout;
    addRuleLayout->addWidget(addRuleButton);
    addRuleLayout->addStretch();
    layout->addLayout(addRuleLayout);
    return frame;
}

QWidget* HideRulesEditorClass::createRuleWidget(int groupIndex, int ruleIndex)
{
    const HideRule& rule = ruleset().groups[groupIndex].rules[ruleIndex];
    QWidget* widget = new QWidget(GroupsWidget);
    QHBoxLayout* layout = new QHBoxLayout(widget);
    layout->setContentsMargins(0, 0, 0, 0);

    // 规则：非 + 规则类型 + 规则设置 …… 状态 删除
    QPushButton* reversedButton = createReversedButton(widget, rule.reversed);
    connect(reversedButton, &QPushButton::toggled, this, [this, groupIndex, ruleIndex](bool checked) {
        ruleset().groups[groupIndex].rules[ruleIndex].reversed = checked;
        save();
        });
    QComboBox* typeComboBox = createComboBox(widget, RULE_TYPE_TEXTS, static_cast<int>(rule.type));
    connect(typeComboBox, &QComboBox::currentIndexChanged, this, [this, groupIndex, ruleIndex](int index) {
        ruleset().groups[groupIndex].rules[ruleIndex].type = static_cast<HideRuleType>(index);
        save();
        scheduleRebuild();
        });
    QLabel* stateLabel = new QLabel(widget);
    RuleStateLabels.last().append(stateLabel);
    QPushButton* deleteButton = new QPushButton(tr("删除"), widget);
    connect(deleteButton, &QPushButton::clicked, this, [this, groupIndex, ruleIndex] {
        ruleset().groups[groupIndex].rules.removeAt(ruleIndex);
        save();
        scheduleRebuild();
        });
    layout->addWidget(reversedButton);
    layout->addWidget(typeComboBox);
    layout->addWidget(createRuleSettingsWidget(groupIndex, ruleIndex), 1);
    layout->addWidget(stateLabel);
    layout->addWidget(deleteButton);
    return widget;
}

QWidget* HideRulesEditorClass::createRuleSettingsWidget(int groupIndex, int ruleIndex)
{
    const HideRule& rule = ruleset().groups[groupIndex].rules[ruleIndex];
    auto ruleRef = [this, groupIndex, ruleIndex]() -> HideRule& { return ruleset().groups[groupIndex].rules[ruleIndex]; };
    QWidget* widget = new QWidget(GroupsWidget);
    QHBoxLayout* layout = new QHBoxLayout(widget);
    layout->setContentsMargins(0, 0, 0, 0);

    switch (rule.type) {
        case HideRuleType::WindowTitle:
        case HideRuleType::WindowClassName:
        case HideRuleType::WindowProcessName: {
            // 和 ClassIsland 一样：不勾“正则”时要完全相等
            QLineEdit* lineEdit = new QLineEdit(rule.text, widget);
            lineEdit->setPlaceholderText(tr("要匹配的文本（不勾“正则”时要完全相同）"));
            connect(lineEdit, &QLineEdit::textChanged, this, [this, ruleRef](const QString& text) {
                ruleRef().text = text;
                save();
                });
            QCheckBox* regexCheckBox = new QCheckBox(tr("正则"), widget);
            regexCheckBox->setChecked(rule.regex);
            connect(regexCheckBox, &QCheckBox::toggled, this, [this, ruleRef](bool checked) {
                ruleRef().regex = checked;
                save();
                });
            layout->addWidget(lineEdit, 1);
            layout->addWidget(regexCheckBox);
            break;
        }
        case HideRuleType::WindowStatus: {
            QComboBox* comboBox = createComboBox(widget, { tr("普通"), tr("最大化"), tr("最小化"), tr("全屏") }, static_cast<int>(rule.windowStatus));
            connect(comboBox, &QComboBox::currentIndexChanged, this, [this, ruleRef](int index) {
                ruleRef().windowStatus = static_cast<HideRuleWindowStatus>(index);
                save();
                });
            layout->addWidget(comboBox);
            layout->addStretch();
            break;
        }
        case HideRuleType::TimeRange: {
            QTimeEdit* startEdit = new QTimeEdit(rule.startTime, widget);
            startEdit->setDisplayFormat("HH:mm:ss");
            connect(startEdit, &QTimeEdit::timeChanged, this, [this, ruleRef](const QTime& time) {
                ruleRef().startTime = time;
                save();
                });
            QTimeEdit* endEdit = new QTimeEdit(rule.endTime, widget);
            endEdit->setDisplayFormat("HH:mm:ss");
            connect(endEdit, &QTimeEdit::timeChanged, this, [this, ruleRef](const QTime& time) {
                ruleRef().endTime = time;
                save();
                });
            layout->addWidget(new QLabel(tr("从"), widget));
            layout->addWidget(startEdit);
            layout->addWidget(new QLabel(tr("到"), widget));
            layout->addWidget(endEdit);
            layout->addStretch();
            break;
        }
        case HideRuleType::Weekday: {
            const QStringList days = { tr("一"), tr("二"), tr("三"), tr("四"), tr("五"), tr("六"), tr("日") };
            for (int i = 0; i < 7; i++) {
                QPushButton* dayButton = new QPushButton(days[i], widget);
                dayButton->setCheckable(true);
                dayButton->setChecked(rule.weekdays & (1u << i));
                connect(dayButton, &QPushButton::toggled, this, [this, ruleRef, i](bool checked) {
                    if (checked) ruleRef().weekdays |= 1u << i;
                    else ruleRef().weekdays &= ~(1u << i);
                    save();
                    });
                layout->addWidget(dayButton);
            }
            layout->addStretch();
            break;
        }
        case HideRuleType::RemainingDays: {
            QComboBox* compareComboBox = createComboBox(widget, { "≤", "≥", "=" }, static_cast<int>(rule.compare));
            connect(compareComboBox, &QComboBox::currentIndexChanged, this, [this, ruleRef](int index) {
                ruleRef().compare = static_cast<HideRuleCompare>(index);
                save();
                });
            QSpinBox* daysSpinBox = new QSpinBox(widget);
            daysSpinBox->setRange(-100000, 100000);
            daysSpinBox->setValue(rule.days);
            daysSpinBox->setSuffix(tr(" 天"));
            connect(daysSpinBox, &QSpinBox::valueChanged, this, [this, ruleRef](int value) {
                ruleRef().days = value;
                save();
                });
            layout->addWidget(compareComboBox);
            layout->addWidget(daysSpinBox);
            layout->addStretch();
            break;
        }
        default:
            layout->addStretch();
            break;
    }
    return widget;
}

void HideRulesEditorClass::refreshStates()
{
    const ForegroundWindowInfo window = FloatingBar->lastForeignWindow();
    if (window.valid)
        ForegroundWindowLabel->setText(tr("最近一个前台窗口（不算万能倒计时自己的）：标题“%1”，类名“%2”，进程“%3”%4")
            .arg(window.title, window.className, window.processName,
                 window.fullscreen ? tr("，全屏") : (window.maximized ? tr("，最大化") : (window.minimized ? tr("，最小化") : QString()))));
    else
        ForegroundWindowLabel->setText(tr("还没有取到前台窗口信息。切换到别的窗口后，这里会显示它的标题、类名和进程。"));

    const HideRuleset& rules = ruleset();
    setStateLabel(RulesetStateLabel, rules.state);
    if (rules.state == HideRuleState::Satisfied) RulesetStateLabel->setText(tr("● 满足，悬浮条已隐藏"));
    for (int i = 0; i < GroupStateLabels.size() && i < rules.groups.size(); i++) {
        setStateLabel(GroupStateLabels[i], rules.groups[i].state);
        for (int j = 0; j < RuleStateLabels[i].size() && j < rules.groups[i].rules.size(); j++)
            setStateLabel(RuleStateLabels[i][j], rules.groups[i].rules[j].state);
    }
}
EOF

edit() {
    local nl

    if has "$f0" 'HideRulesEditor.cpp'; then
        gray '  [跳过] src/CMakeLists.txt 已经改过'
    else
        nl=$(newline_of "$f0")
        anchor OLD <<'EOF'
    core/Global.h
    core/EventPoint.h
    ui/EventPointReminder.h
    ui/EventPointReminder.cpp
EOF
        anchor NEW <<'EOF'
    core/Global.h
    core/EventPoint.h
    core/HideRules.h
    core/HideRules.cpp
    core/ForegroundWindow.h
    core/ForegroundWindow.cpp
    ui/EventPointReminder.h
    ui/EventPointReminder.cpp
EOF
        replace_once f0 "$nl" "$OLD" "$NEW" 'src/CMakeLists.txt（第 1 处）' || return 1
        anchor OLD <<'EOF'
    ui/SettingsContent.h
    ui/SettingsContent.cpp
    ui/WelcomePage.h
    ui/WelcomePage.cpp
EOF
        anchor NEW <<'EOF'
    ui/SettingsContent.h
    ui/SettingsContent.cpp
    ui/HideRulesEditor.h
    ui/HideRulesEditor.cpp
    ui/WelcomePage.h
    ui/WelcomePage.cpp
EOF
        replace_once f0 "$nl" "$OLD" "$NEW" 'src/CMakeLists.txt（第 2 处）' || return 1
        anchor OLD <<'EOF'
target_compile_definitions(${PROJECT_NAME} PRIVATE
    $<$<CONFIG:Release>:QT_NO_DEBUG_OUTPUT>
)
EOF
        anchor NEW <<'EOF'
target_compile_definitions(${PROJECT_NAME} PRIVATE
    $<$<CONFIG:Release>:QT_NO_DEBUG_OUTPUT>
)

# 悬浮条隐藏规则在 Linux 上用 X11（libxcb）获取前台窗口；找不到 libxcb 时照常编译，只是前台窗口相关的规则不生效
if(UNIX AND NOT APPLE)
    find_package(PkgConfig QUIET)
    if(PkgConfig_FOUND)
        pkg_check_modules(XCB QUIET IMPORTED_TARGET xcb)
    endif()
    if(XCB_FOUND)
        target_link_libraries(${PROJECT_NAME} PRIVATE PkgConfig::XCB)
        target_compile_definitions(${PROJECT_NAME} PRIVATE UT_HAVE_XCB)
    else()
        message(WARNING "没有找到 libxcb（Debian / Ubuntu 上可以安装 libxcb1-dev），悬浮条隐藏规则里和前台窗口有关的规则在 Linux 上不会生效")
    endif()
endif()
EOF
        replace_once f0 "$nl" "${OLD%$'\n'}" "${NEW%$'\n'}" 'src/CMakeLists.txt（第 3 处）' || return 1
    fi

    if has "$f1" 'FloatingBarHideMode'; then
        gray '  [跳过] ConfigManager.h 已经改过'
    else
        nl=$(newline_of "$f1")
        anchor OLD <<'EOF'

#include "EventPoint.h"

#include <QDateTime>
EOF
        anchor NEW <<'EOF'

#include "EventPoint.h"
#include "HideRules.h"

#include <QDateTime>
EOF
        replace_once f1 "$nl" "$OLD" "$NEW" 'ConfigManager.h（第 1 处）' || return 1
        anchor OLD <<'EOF'
    Light, // 浅色
    Dark // 深色
};

EOF
        anchor NEW <<'EOF'
    Light, // 浅色
    Dark // 深色
};

enum class FloatingBarHideMode {
    Basic, // 基础模式
    Advanced // 高级模式（规则集）
};

EOF
        replace_once f1 "$nl" "$OLD" "$NEW" 'ConfigManager.h（第 2 处）' || return 1
        anchor OLD <<'EOF'
        FloatingBarStyle floating_bar_style = FloatingBarStyle::Default; // 悬浮条样式，默认样式
        FloatingBarTheme floating_bar_theme = FloatingBarTheme::FollowSystem; // 悬浮条深浅色（仅 Win11 样式），默认跟随系统
    };

EOF
        anchor NEW <<'EOF'
        FloatingBarStyle floating_bar_style = FloatingBarStyle::Default; // 悬浮条样式，默认样式
        FloatingBarTheme floating_bar_theme = FloatingBarTheme::FollowSystem; // 悬浮条深浅色（仅 Win11 样式），默认跟随系统
        FloatingBarHideMode floating_bar_hide_mode = FloatingBarHideMode::Basic; // 隐藏悬浮条的模式，默认基础模式
        bool hide_on_max_window = false; // 基础模式：前台是最大化窗口时隐藏，默认关闭
        bool hide_on_fullscreen = false; // 基础模式：前台是全屏窗口时隐藏，默认关闭
        HideRuleset floating_bar_hide_rules; // 高级模式：隐藏规则集（保存在 floating_bar_hide_rules.json）
    };

EOF
        replace_once f1 "$nl" "$OLD" "$NEW" 'ConfigManager.h（第 3 处）' || return 1
    fi

    if has "$f2" 'floating_bar_hide_rules.json'; then
        gray '  [跳过] ConfigManager.cpp 已经改过'
    else
        nl=$(newline_of "$f2")
        anchor OLD <<'EOF'
#include <QObject>
#include <QMessageBox>

ConfigManager::ConfigManager()
EOF
        anchor NEW <<'EOF'
#include <QObject>
#include <QMessageBox>
#include <QJsonDocument>

ConfigManager::ConfigManager()
EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
        floating_bar.floating_bar_style = static_cast<FloatingBarStyle>(Settings.value("floating_bar_style", static_cast<int>(FloatingBarStyle::Default)).toInt());
        floating_bar.floating_bar_theme = static_cast<FloatingBarTheme>(Settings.value("floating_bar_theme", static_cast<int>(FloatingBarTheme::FollowSystem)).toInt());
        Settings.endGroup();

EOF
        anchor NEW <<'EOF'
        floating_bar.floating_bar_style = static_cast<FloatingBarStyle>(Settings.value("floating_bar_style", static_cast<int>(FloatingBarStyle::Default)).toInt());
        floating_bar.floating_bar_theme = static_cast<FloatingBarTheme>(Settings.value("floating_bar_theme", static_cast<int>(FloatingBarTheme::FollowSystem)).toInt());
        floating_bar.floating_bar_hide_mode = static_cast<FloatingBarHideMode>(Settings.value("floating_bar_hide_mode", static_cast<int>(FloatingBarHideMode::Basic)).toInt());
        floating_bar.hide_on_max_window = Settings.value("hide_on_max_window", false).toBool();
        floating_bar.hide_on_fullscreen = Settings.value("hide_on_fullscreen", false).toBool();
        Settings.endGroup();

EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 2 处）' || return 1
        anchor OLD <<'EOF'
        }

        qInfo() << "配置文件读取成功";
    }
EOF
        anchor NEW <<'EOF'
        }

        QFile hide_rules_file("floating_bar_hide_rules.json");
        if (hide_rules_file.open(QIODevice::ReadOnly)) {
            const QJsonDocument document = QJsonDocument::fromJson(hide_rules_file.readAll());
            if (document.isObject())
                floating_bar.floating_bar_hide_rules = HideRuleset::fromJson(document.object());
            hide_rules_file.close();
        }

        qInfo() << "配置文件读取成功";
    }
EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 3 处）' || return 1
        anchor OLD <<'EOF'
    Settings.setValue("floating_bar_style", static_cast<int>(floating_bar.floating_bar_style));
    Settings.setValue("floating_bar_theme", static_cast<int>(floating_bar.floating_bar_theme));
    Settings.endGroup();

EOF
        anchor NEW <<'EOF'
    Settings.setValue("floating_bar_style", static_cast<int>(floating_bar.floating_bar_style));
    Settings.setValue("floating_bar_theme", static_cast<int>(floating_bar.floating_bar_theme));
    Settings.setValue("floating_bar_hide_mode", static_cast<int>(floating_bar.floating_bar_hide_mode));
    Settings.setValue("hide_on_max_window", floating_bar.hide_on_max_window);
    Settings.setValue("hide_on_fullscreen", floating_bar.hide_on_fullscreen);
    Settings.endGroup();

EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 4 处）' || return 1
        anchor OLD <<'EOF'
    }

    if (Settings.status() != QSettings::NoError) {
        QMessageBox::critical(NULL, QObject::tr("错误"), QObject::tr("配置文件写入失败<br>错误代码：") + QString::number(Settings.status()), QMessageBox::Ok);
EOF
        anchor NEW <<'EOF'
    }

    QFile hide_rules_file("floating_bar_hide_rules.json");
    if (hide_rules_file.open(QIODevice::WriteOnly)) {
        hide_rules_file.write(QJsonDocument(floating_bar.floating_bar_hide_rules.toJson()).toJson());
        hide_rules_file.close();
    }

    if (Settings.status() != QSettings::NoError) {
        QMessageBox::critical(NULL, QObject::tr("错误"), QObject::tr("配置文件写入失败<br>错误代码：") + QString::number(Settings.status()), QMessageBox::Ok);
EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 5 处）' || return 1
    fi

    if has "$f3" 'updateVisibility'; then
        gray '  [跳过] FloatingBar.h 已经改过'
    else
        nl=$(newline_of "$f3")
        anchor OLD <<'EOF'
    void updateOpacity(); // 按配置更新不透明度（平时 / 鼠标移入时淡化）
    void updatePosition(); // 按 Bar 的大小、悬浮条位置和距顶边距离更新窗口大小和位置

protected:
EOF
        anchor NEW <<'EOF'
    void updateOpacity(); // 按配置更新不透明度（平时 / 鼠标移入时淡化）
    void updatePosition(); // 按 Bar 的大小、悬浮条位置和距顶边距离更新窗口大小和位置
    void updateVisibility(); // 按“是否显示悬浮条”和隐藏规则显示或隐藏悬浮条
    ForegroundWindowInfo lastForeignWindow() const { return m_lastForeignWindow; } // 最近一个不是万能倒计时自己的前台窗口

Q_SIGNALS:
    void hideRulesEvaluated(); // 每次判断完隐藏规则（编辑界面用来刷新满足状态）

protected:
EOF
        replace_once f3 "$nl" "$OLD" "$NEW" 'FloatingBar.h（第 1 处）' || return 1
        anchor OLD <<'EOF'
    bool m_isMouseIn = false;
    bool m_isClickThroughPending = false; // 显示后还没有重新设置过点击穿透

    bool isDarkTheme() const;
    void updateMouseStatus();
    void reapplyClickThrough();
};
EOF
        anchor NEW <<'EOF'
    bool m_isMouseIn = false;
    bool m_isClickThroughPending = false; // 显示后还没有重新设置过点击穿透
    QTimer* m_hideRuleTimer; // 定时判断隐藏规则
    bool m_isHiddenByRule = false;
    ForegroundWindowInfo m_lastForeignWindow;

    bool isDarkTheme() const;
    void updateMouseStatus();
    void reapplyClickThrough();
    void evaluateHideRules();
};
EOF
        replace_once f3 "$nl" "$OLD" "$NEW" 'FloatingBar.h（第 2 处）' || return 1
    fi

    if has "$f4" 'evaluateHideRules'; then
        gray '  [跳过] FloatingBar.cpp 已经改过'
    else
        nl=$(newline_of "$f4")
        anchor OLD <<'EOF'
#include "FloatingBar.h"

#include <QApplication>
EOF
        anchor NEW <<'EOF'
#include "FloatingBar.h"
#include "../core/ForegroundWindow.h"

#include <QApplication>
EOF
        replace_once f4 "$nl" "$OLD" "$NEW" 'FloatingBar.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
    this->setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::Tool);
    this->setAttribute(Qt::WA_TranslucentBackground); // 设置窗口背景透明

    Bar = new QLabel(this);
EOF
        anchor NEW <<'EOF'
    this->setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::Tool);
    this->setAttribute(Qt::WA_TranslucentBackground); // 设置窗口背景透明
    this->setAttribute(Qt::WA_ShowWithoutActivating); // 显示时不抢焦点（按隐藏规则重新显示时不能打断正在用的窗口）

    Bar = new QLabel(this);
EOF
        replace_once f4 "$nl" "$OLD" "$NEW" 'FloatingBar.cpp（第 2 处）' || return 1
        anchor OLD <<'EOF'
    m_mouseTimer->setInterval(50);
    connect(m_mouseTimer, &QTimer::timeout, this, &FloatingBarClass::updateMouseStatus);

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
EOF
        anchor NEW <<'EOF'
    m_mouseTimer->setInterval(50);
    connect(m_mouseTimer, &QTimer::timeout, this, &FloatingBarClass::updateMouseStatus);

    m_hideRuleTimer = new QTimer(this);
    m_hideRuleTimer->setInterval(500);
    connect(m_hideRuleTimer, &QTimer::timeout, this, &FloatingBarClass::evaluateHideRules);
    m_hideRuleTimer->start();

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
EOF
        replace_once f4 "$nl" "$OLD" "$NEW" 'FloatingBar.cpp（第 3 处）' || return 1
        anchor OLD <<'EOF'
void FloatingBarClass::updateWindowFlags()
{
    Qt::WindowFlags flags = (config.floating_bar.floating_bar_on_top ? Qt::WindowStaysOnTopHint : Qt::WindowStaysOnBottomHint) | Qt::FramelessWindowHint | Qt::Tool;
    if (config.floating_bar.is_mouse_click_through_enabled)
        flags |= Qt::WindowTransparentForInput; // 鼠标点击直接穿过悬浮条
EOF
        anchor NEW <<'EOF'
void FloatingBarClass::updateWindowFlags()
{
    // 悬浮条不接受焦点：否则它显示时会变成前台窗口，前台窗口相关的隐藏规则就会判断错
    Qt::WindowFlags flags = (config.floating_bar.floating_bar_on_top ? Qt::WindowStaysOnTopHint : Qt::WindowStaysOnBottomHint) | Qt::FramelessWindowHint | Qt::Tool | Qt::WindowDoesNotAcceptFocus;
    if (config.floating_bar.is_mouse_click_through_enabled)
        flags |= Qt::WindowTransparentForInput; // 鼠标点击直接穿过悬浮条
EOF
        replace_once f4 "$nl" "$OLD" "$NEW" 'FloatingBar.cpp（第 4 处）' || return 1
        anchor OLD <<'EOF'
}

void FloatingBarClass::updatePosition()
{
EOF
        anchor NEW <<'EOF'
}

void FloatingBarClass::evaluateHideRules()
{
    // 和 ClassIsland 一样：基础模式里勾选的条件任一满足就隐藏；高级模式按规则集判断，满足就隐藏
    const auto& fb = config.floating_bar;
    ForegroundWindowInfo window = queryForegroundWindow();
    if (window.valid && !window.own)
        m_lastForeignWindow = window;
    if (window.own)
        window = ForegroundWindowInfo(); // 万能倒计时自己的窗口在前台时，当作没有前台窗口（否则一打开全屏的设置中心悬浮条就被隐藏）

    bool hidden = false;
    if (fb.floating_bar_hide_mode == FloatingBarHideMode::Advanced) {
        HideRuleContext context;
        context.window = window;
        context.now = QDateTime::currentDateTime();
        context.remainingDays = context.now.secsTo(config.general.target_date_time) / 86400; // 和悬浮条上显示的天数一致
        hidden = evaluateHideRuleset(config.floating_bar.floating_bar_hide_rules, context);
        emit hideRulesEvaluated();
    }
    else if (fb.hide_on_max_window || fb.hide_on_fullscreen) {
        hidden = (fb.hide_on_max_window && window.maximized) || (fb.hide_on_fullscreen && window.fullscreen);
    }
    if (hidden != m_isHiddenByRule) {
        m_isHiddenByRule = hidden;
        qInfo() << (hidden ? "满足隐藏规则，隐藏悬浮条" : "不再满足隐藏规则，显示悬浮条");
        updateVisibility();
    }
}

void FloatingBarClass::updateVisibility()
{
    const bool visible = config.floating_bar.is_show_floating_bar && !m_isHiddenByRule;
    if (visible != this->isVisible())
        this->setVisible(visible);
}

void FloatingBarClass::updatePosition()
{
EOF
        replace_once f4 "$nl" "$OLD" "$NEW" 'FloatingBar.cpp（第 5 处）' || return 1
    fi

    if has "$f5" 'EditHideRulesButton'; then
        gray '  [跳过] SettingsContent.h 已经改过'
    else
        nl=$(newline_of "$f5")
        anchor OLD <<'EOF'
    QCheckBox* IsMouseInFadingCheckBox;
    QCheckBox* IsMouseClickThroughCheckBox;

    // Reminder
EOF
        anchor NEW <<'EOF'
    QCheckBox* IsMouseInFadingCheckBox;
    QCheckBox* IsMouseClickThroughCheckBox;
    QComboBox* FloatingBarHideModeComboBox;
    QCheckBox* HideOnMaxWindowCheckBox;
    QCheckBox* HideOnFullscreenCheckBox;
    QPushButton* EditHideRulesButton;

    void updateHideModeWidgets(); // 基础模式只能改两个勾选项，高级模式只能编辑规则集

    // Reminder
EOF
        replace_once f5 "$nl" "$OLD" "$NEW" 'SettingsContent.h（第 1 处）' || return 1
    fi

    if has "$f6" 'EditHideRulesButton'; then
        gray '  [跳过] SettingsContent.cpp 已经改过'
    else
        nl=$(newline_of "$f6")
        anchor OLD <<'EOF'
#include "core/Global.h"
#include "ui/SettingsContent.h"

#include <QListView>
EOF
        anchor NEW <<'EOF'
#include "core/Global.h"
#include "ui/SettingsContent.h"
#include "ui/HideRulesEditor.h"

#include <QListView>
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
    IsMouseClickThroughCheckBox = new QCheckBox(tr("鼠标点击穿透"), FloatingBarSettingsPage);
    IsMouseClickThroughCheckBox->setChecked(config.floating_bar.is_mouse_click_through_enabled);

    // Reminder
EOF
        anchor NEW <<'EOF'
    IsMouseClickThroughCheckBox = new QCheckBox(tr("鼠标点击穿透"), FloatingBarSettingsPage);
    IsMouseClickThroughCheckBox->setChecked(config.floating_bar.is_mouse_click_through_enabled);
    FloatingBarHideModeComboBox = new QComboBox(FloatingBarSettingsPage);
    FloatingBarHideModeComboBox->addItems({tr("基础模式"), tr("高级模式（规则集）")});
    FloatingBarHideModeComboBox->setCurrentIndex(config.floating_bar.floating_bar_hide_mode == FloatingBarHideMode::Advanced ? 1 : 0);
    HideOnMaxWindowCheckBox = new QCheckBox(tr("前台是最大化窗口时隐藏"), FloatingBarSettingsPage);
    HideOnMaxWindowCheckBox->setChecked(config.floating_bar.hide_on_max_window);
    HideOnFullscreenCheckBox = new QCheckBox(tr("前台是全屏窗口时隐藏"), FloatingBarSettingsPage);
    HideOnFullscreenCheckBox->setChecked(config.floating_bar.hide_on_fullscreen);
    EditHideRulesButton = new QPushButton(tr("编辑规则集…"), FloatingBarSettingsPage);

    // Reminder
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 2 处）' || return 1
        anchor OLD <<'EOF'
        if (child != IsShowFloatingBarCheckBox)
            child->setEnabled(config.floating_bar.is_show_floating_bar);

    for (QWidget* child : ReminderSettingsPage->findChildren<QWidget*>())
EOF
        anchor NEW <<'EOF'
        if (child != IsShowFloatingBarCheckBox)
            child->setEnabled(config.floating_bar.is_show_floating_bar);
    updateHideModeWidgets();

    for (QWidget* child : ReminderSettingsPage->findChildren<QWidget*>())
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 3 处）' || return 1
        anchor OLD <<'EOF'
    FloatingBarSettingsPageLayout->addRow(IsMouseInFadingCheckBox);
    FloatingBarSettingsPageLayout->addRow(IsMouseClickThroughCheckBox);
    FloatingBarSettingsPageLayout->setContentsMargins(25, 25, 25, 25);
    FloatingBarSettingsPage->setLayout(FloatingBarSettingsPageLayout);
EOF
        anchor NEW <<'EOF'
    FloatingBarSettingsPageLayout->addRow(IsMouseInFadingCheckBox);
    FloatingBarSettingsPageLayout->addRow(IsMouseClickThroughCheckBox);
    FloatingBarSettingsPageLayout->addRow(tr("隐藏悬浮条："), FloatingBarHideModeComboBox);
    FloatingBarSettingsPageLayout->addRow(HideOnMaxWindowCheckBox);
    FloatingBarSettingsPageLayout->addRow(HideOnFullscreenCheckBox);
    FloatingBarSettingsPageLayout->addRow(EditHideRulesButton);
    FloatingBarSettingsPageLayout->setContentsMargins(25, 25, 25, 25);
    FloatingBarSettingsPage->setLayout(FloatingBarSettingsPageLayout);
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 4 处）' || return 1
        anchor OLD <<'EOF'
    connect(IsShowFloatingBarCheckBox, &QCheckBox::checkStateChanged, this, [this] {
        config.set(config.floating_bar.is_show_floating_bar, IsShowFloatingBarCheckBox->isChecked());
        if (!config.floating_bar.is_show_floating_bar) {
            FloatingBar->hide();
        }
        else FloatingBar->show();
        for (QWidget* child : FloatingBarSettingsPage->findChildren<QWidget*>())
            if (child != IsShowFloatingBarCheckBox)
                child->setEnabled(config.floating_bar.is_show_floating_bar);
        });
    connect(FloatingBarTextLineEdit, &QLineEdit::textChanged, this, [this](const QString& text) {
EOF
        anchor NEW <<'EOF'
    connect(IsShowFloatingBarCheckBox, &QCheckBox::checkStateChanged, this, [this] {
        config.set(config.floating_bar.is_show_floating_bar, IsShowFloatingBarCheckBox->isChecked());
        FloatingBar->updateVisibility();
        for (QWidget* child : FloatingBarSettingsPage->findChildren<QWidget*>())
            if (child != IsShowFloatingBarCheckBox)
                child->setEnabled(config.floating_bar.is_show_floating_bar);
        updateHideModeWidgets();
        });
    connect(FloatingBarTextLineEdit, &QLineEdit::textChanged, this, [this](const QString& text) {
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 5 处）' || return 1
        anchor OLD <<'EOF'
        FloatingBar->updateWindowFlags();
        FloatingBar->hide();
        FloatingBar->show();
#ifdef Q_OS_WIN
        if (config.floating_bar.floating_bar_on_top) {
EOF
        anchor NEW <<'EOF'
        FloatingBar->updateWindowFlags();
        FloatingBar->hide();
        FloatingBar->updateVisibility();
#ifdef Q_OS_WIN
        if (config.floating_bar.floating_bar_on_top) {
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 6 处）' || return 1
        anchor OLD <<'EOF'
        FloatingBar->updateWindowFlags();
        });

    // Reminder
EOF
        anchor NEW <<'EOF'
        FloatingBar->updateWindowFlags();
        });
    connect(FloatingBarHideModeComboBox, &QComboBox::currentIndexChanged, this, [this](int index) {
        config.set(config.floating_bar.floating_bar_hide_mode, index == 1 ? FloatingBarHideMode::Advanced : FloatingBarHideMode::Basic);
        updateHideModeWidgets();
        });
    connect(HideOnMaxWindowCheckBox, &QCheckBox::toggled, this, [this](bool checked) {
        config.set(config.floating_bar.hide_on_max_window, checked);
        });
    connect(HideOnFullscreenCheckBox, &QCheckBox::toggled, this, [this](bool checked) {
        config.set(config.floating_bar.hide_on_fullscreen, checked);
        });
    connect(EditHideRulesButton, &QPushButton::clicked, this, [this] {
        HideRulesEditorClass* editor = new HideRulesEditorClass(this, config, FloatingBar, EditHideRulesButton->font());
        editor->setAttribute(Qt::WA_DeleteOnClose);
        editor->open();
        });

    // Reminder
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 7 处）' || return 1
        anchor OLD <<'EOF'
        });

}

EOF
        anchor NEW <<'EOF'
        });

}

void SettingsContentClass::updateHideModeWidgets() {
    const bool enabled = config.floating_bar.is_show_floating_bar;
    const bool advanced = config.floating_bar.floating_bar_hide_mode == FloatingBarHideMode::Advanced;
    HideOnMaxWindowCheckBox->setEnabled(enabled && !advanced);
    HideOnFullscreenCheckBox->setEnabled(enabled && !advanced);
    EditHideRulesButton->setEnabled(enabled && advanced);
}

EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 8 处）' || return 1
    fi

    if has "$f7" 'FloatingBar->updateVisibility'; then
        gray '  [跳过] UniversalTimer2.cpp 已经改过'
    else
        nl=$(newline_of "$f7")
        anchor OLD <<'EOF'
    
    // Floating Bar
    if (!config.floating_bar.is_show_floating_bar) FloatingBar->hide();
    else FloatingBar->show();
    FloatingBar->updateWindowFlags(); // 更新悬浮条层级和点击穿透
    FloatingBar->Bar->resize(FloatingBar->Bar->width(), config.floating_bar.floating_bar_height);
EOF
        anchor NEW <<'EOF'
    
    // Floating Bar
    FloatingBar->updateVisibility(); // 按“是否显示悬浮条”和隐藏规则显示或隐藏
    FloatingBar->updateWindowFlags(); // 更新悬浮条层级和点击穿透
    FloatingBar->Bar->resize(FloatingBar->Bar->width(), config.floating_bar.floating_bar_height);
EOF
        replace_once f7 "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（第 1 处）' || return 1
    fi

}

# 新文件：不存在就新建；已经存在且内容相同就跳过；内容不同说明被改过，不覆盖
NEWNL=$(newline_of "$f4")
CREATE=()
check_new() {
    local i p v content existing
    for ((i = 0; i < NEWCOUNT; i++)); do
        p=N_$i; v=n$i
        content=${!v}
        [ "$NEWNL" = crlf ] && content=${content//$'\n'/$'\r\n'}
        printf -v "n$i" '%s' "$content"
        if [ -e "$ROOT/${!p}" ]; then
            load existing "$ROOT/${!p}" || { FAIL="[${!p}] 读取失败。"; return 1; }
            if [ "${existing//$'\r\n'/$'\n'}" = "${content//$'\r\n'/$'\n'}" ]; then
                gray "  [跳过] ${!p} 已经有了"
            else
                FAIL="[${!p}] 这个文件已经存在，但内容和预期的不一样，可能被改过。"
                return 1
            fi
        else
            CREATE+=("$i")
        fi
    done
}

if ! edit || ! check_new; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修改的人。'
    finish 1
fi

CHANGED=()
for ((i = 0; i < MODCOUNT; i++)); do
    a="f$i"; b="f${i}_0"
    [ "${!a}" != "${!b}" ] && CHANGED+=("$i")
done
if [ ${#CHANGED[@]} -eq 0 ] && [ ${#CREATE[@]} -eq 0 ]; then
    echo
    ok '这个项目已经改过了，没有需要修改的地方。'
    finish 0
fi

# 全部对上了才开始写：先备份（新建的文件记下来，撤销时删除）
BACKUP_LIST=()
for i in "${CHANGED[@]}"; do p=P_$i; BACKUP_LIST+=("${!p}"); done
for i in "${CREATE[@]}"; do p=N_$i; BACKUP_LIST+=("${!p}"); done
start_backup "${BACKUP_LIST[@]}"
for i in "${CHANGED[@]}"; do
    a="f$i"; p="P_$i"
    if ! printf '%s' "${!a}" > "$ROOT/${!p}"; then
        err "写入失败：${!p}。请运行 bash undo.sh 恢复。"
        finish 1
    fi
    ok "  [已修改] ${!p}"
done
for i in "${CREATE[@]}"; do
    a="n$i"; p="N_$i"
    if ! printf '%s' "${!a}" > "$ROOT/${!p}"; then
        err "写入失败：${!p}。请运行 bash undo.sh 恢复。"
        finish 1
    fi
    ok "  [已新建] ${!p}"
done

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可（新增了源文件，如果用的是旧的编译目录，CMake 会自动重新配置）。'
printf '\033[36m%s\033[0m\n' '新选项在“设置中心 → 悬浮条设置 → 隐藏悬浮条”里。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
