#!/usr/bin/env bash
# 悬浮条淡化、点击穿透和 Win11 样式 · 一键应用到 Universal-Timer（Linux）
# 用法：在工具文件夹里打开终端，运行  bash apply.sh
#       工具文件夹不在项目里时：      bash apply.sh 项目文件夹路径
# 修改内容与 floating-bar.patch 相同。基于 Universal-Timer 的 a86dbfc，打过 second-skip 修复也可以用。
# 任何一步对不上就一个文件都不改，修改前会备份原文件。
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' '==== 悬浮条淡化、点击穿透和 Win11 样式 · 一键应用 ===='

if ! ROOT=$(find_root "${1:-}"); then
    err '没有找到 Universal-Timer 项目文件夹。'
    warn '请把整个工具文件夹放进项目文件夹里再运行，或者运行：bash apply.sh 项目文件夹路径'
    finish 1
fi
echo "项目位置：$ROOT"
P_0=src/core/ConfigManager.h
P_1=src/core/ConfigManager.cpp
P_2=src/ui/FloatingBar.h
P_3=src/ui/FloatingBar.cpp
P_4=src/ui/SettingsContent.h
P_5=src/ui/SettingsContent.cpp
P_6=src/core/UniversalTimer2.cpp
for i in 0 1 2 3 4 5 6; do
    p=P_$i
    if ! load "f$i" "$ROOT/${!p}"; then
        err "读取项目文件失败：${!p}"
        finish 1
    fi
    v=f$i
    printf -v "f${i}_0" '%s' "${!v}" # 保存原始内容，最后比较哪些文件改了
done

edit() {
    local nl

    if has "$f0" 'FloatingBarStyle'; then
        gray '  [跳过] ConfigManager.h 已经改过'
    else
        nl=$(newline_of "$f0")
        anchor OLD <<'EOF'
    TopCenter,
    TopRight
};

EOF
        anchor NEW <<'EOF'
    TopCenter,
    TopRight
};

enum class FloatingBarStyle {
    Default, // 默认样式
    Win11 // 仿 Win11 样式
};

enum class FloatingBarTheme {
    FollowSystem, // 跟随系统
    Light, // 浅色
    Dark // 深色
};

EOF
        replace_once f0 "$nl" "$OLD" "$NEW" 'ConfigManager.h（第 1 处）' || return 1
        anchor OLD <<'EOF'
        unsigned floating_bar_height = 50; // 悬浮条高度，默认50
        QString floating_bar_text = "距会考还剩："; // 悬浮条文本
    };

EOF
        anchor NEW <<'EOF'
        unsigned floating_bar_height = 50; // 悬浮条高度，默认50
        QString floating_bar_text = "距会考还剩："; // 悬浮条文本
        unsigned floating_bar_top_margin = 0; // 悬浮条距屏幕顶边距离，默认0
        unsigned floating_bar_opacity = 100; // 悬浮条不透明度（百分比），默认100
        bool is_mouse_in_fading_enabled = true; // 鼠标移入时淡化，默认开启
        bool is_mouse_click_through_enabled = true; // 鼠标点击穿透，默认开启
        FloatingBarStyle floating_bar_style = FloatingBarStyle::Default; // 悬浮条样式，默认样式
        FloatingBarTheme floating_bar_theme = FloatingBarTheme::FollowSystem; // 悬浮条深浅色（仅 Win11 样式），默认跟随系统
    };

EOF
        replace_once f0 "$nl" "$OLD" "$NEW" 'ConfigManager.h（第 2 处）' || return 1
    fi

    if has "$f1" 'is_mouse_click_through_enabled'; then
        gray '  [跳过] ConfigManager.cpp 已经改过'
    else
        nl=$(newline_of "$f1")
        anchor OLD <<'EOF'
        floating_bar.floating_bar_height = Settings.value("floating_bar_height", 50).toUInt();
        floating_bar.floating_bar_text = Settings.value("floating_bar_text", "距会考还剩：").toString();
        Settings.endGroup();

EOF
        anchor NEW <<'EOF'
        floating_bar.floating_bar_height = Settings.value("floating_bar_height", 50).toUInt();
        floating_bar.floating_bar_text = Settings.value("floating_bar_text", "距会考还剩：").toString();
        floating_bar.floating_bar_top_margin = Settings.value("floating_bar_top_margin", 0).toUInt();
        floating_bar.floating_bar_opacity = Settings.value("floating_bar_opacity", 100).toUInt();
        floating_bar.is_mouse_in_fading_enabled = Settings.value("is_mouse_in_fading_enabled", true).toBool();
        floating_bar.is_mouse_click_through_enabled = Settings.value("is_mouse_click_through_enabled", true).toBool();
        floating_bar.floating_bar_style = static_cast<FloatingBarStyle>(Settings.value("floating_bar_style", static_cast<int>(FloatingBarStyle::Default)).toInt());
        floating_bar.floating_bar_theme = static_cast<FloatingBarTheme>(Settings.value("floating_bar_theme", static_cast<int>(FloatingBarTheme::FollowSystem)).toInt());
        Settings.endGroup();

EOF
        replace_once f1 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
    Settings.setValue("floating_bar_height", floating_bar.floating_bar_height);
    Settings.setValue("floating_bar_text", floating_bar.floating_bar_text);
    Settings.endGroup();

EOF
        anchor NEW <<'EOF'
    Settings.setValue("floating_bar_height", floating_bar.floating_bar_height);
    Settings.setValue("floating_bar_text", floating_bar.floating_bar_text);
    Settings.setValue("floating_bar_top_margin", floating_bar.floating_bar_top_margin);
    Settings.setValue("floating_bar_opacity", floating_bar.floating_bar_opacity);
    Settings.setValue("is_mouse_in_fading_enabled", floating_bar.is_mouse_in_fading_enabled);
    Settings.setValue("is_mouse_click_through_enabled", floating_bar.is_mouse_click_through_enabled);
    Settings.setValue("floating_bar_style", static_cast<int>(floating_bar.floating_bar_style));
    Settings.setValue("floating_bar_theme", static_cast<int>(floating_bar.floating_bar_theme));
    Settings.endGroup();

EOF
        replace_once f1 "$nl" "$OLD" "$NEW" 'ConfigManager.cpp（第 2 处）' || return 1
    fi

    if has "$f2" 'updateWindowFlags'; then
        gray '  [跳过] FloatingBar.h 已经改过'
    else
        nl=$(newline_of "$f2")
        anchor OLD <<'EOF'
#pragma once

#include <QLabel>


EOF
        anchor NEW <<'EOF'
#pragma once

#include "../core/ConfigManager.h"

#include <QLabel>
#include <QTimer>
#include <QPropertyAnimation>
#include <QGraphicsDropShadowEffect>
#include <QShowEvent>
#include <QPaintEvent>


EOF
        replace_once f2 "$nl" "$OLD" "$NEW" 'FloatingBar.h（第 1 处）' || return 1
        anchor OLD <<'EOF'

public:
    FloatingBarClass(QWidget* parent = nullptr);
    ~FloatingBarClass();

    QLabel* Bar;
};
EOF
        anchor NEW <<'EOF'

public:
    FloatingBarClass(ConfigManager& cfg, QWidget* parent = nullptr);
    ~FloatingBarClass();

    QLabel* Bar;

    void updateStyle(); // 按配置更新背景样式（样式、深浅色、圆角、阴影），并更新大小和位置
    void updateWindowFlags(); // 按配置更新窗口层级和点击穿透
    void updateOpacity(); // 按配置更新不透明度（平时 / 鼠标移入时淡化）
    void updatePosition(); // 按 Bar 的大小、悬浮条位置和距顶边距离更新窗口大小和位置

protected:

    void showEvent(QShowEvent* event) override;
    void paintEvent(QPaintEvent* event) override;

private:

    ConfigManager& config;

    QGraphicsDropShadowEffect* m_shadowEffect; // Win11 样式的阴影
    QPropertyAnimation* m_opacityAnimation; // 不透明度渐变
    QTimer* m_mouseTimer; // 定时查询鼠标位置（开了点击穿透后窗口收不到鼠标事件）
    bool m_isMouseIn = false;
    bool m_isClickThroughPending = false; // 显示后还没有重新设置过点击穿透

    bool isDarkTheme() const;
    void updateMouseStatus();
    void reapplyClickThrough();
};
EOF
        replace_once f2 "$nl" "${OLD%$'\n'}" "$NEW" 'FloatingBar.h（第 2 处）' || return 1
    fi

    if has "$f3" 'reapplyClickThrough'; then
        gray '  [跳过] FloatingBar.cpp 已经改过'
    else
        nl=$(newline_of "$f3")
        anchor OLD <<'EOF'
#include "FloatingBar.h"

FloatingBarClass::FloatingBarClass(QWidget* parent)
    : QWidget(parent)
{
    this->setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::Tool);
EOF
        anchor NEW <<'EOF'
#include "FloatingBar.h"

#include <QApplication>
#include <QScreen>
#include <QCursor>
#include <QStyleHints>
#include <QWindow>

// 鼠标移入时的不透明度和渐变时长，与 ClassIsland 一致
static constexpr double MOUSE_IN_FADED_OPACITY = 0.05;
static constexpr int OPACITY_ANIMATION_DURATION = 100;

// Win11 样式的阴影，参考 ClassIsland Fluent 主题的 BoxShadow="0 4 8 2 #48000000"
static constexpr int SHADOW_BLUR_RADIUS = 16;
static constexpr int SHADOW_OFFSET_Y = 4;

FloatingBarClass::FloatingBarClass(ConfigManager& cfg, QWidget* parent)
    : QWidget(parent), config(cfg)
{
    this->setWindowFlags(Qt::FramelessWindowHint | Qt::WindowStaysOnTopHint | Qt::Tool);
EOF
        replace_once f3 "$nl" "$OLD" "$NEW" 'FloatingBar.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
    Bar->setStyleSheet("font-family: Microsoft YaHei UI, Microsoft YaHei; background: rgba(255, 255, 255, 0.75); color: red;");
    Bar->show();
}

FloatingBarClass::~FloatingBarClass()
{}
EOF
        anchor NEW <<'EOF'
    Bar->setStyleSheet("font-family: Microsoft YaHei UI, Microsoft YaHei; background: rgba(255, 255, 255, 0.75); color: red;");
    Bar->show();

    m_shadowEffect = new QGraphicsDropShadowEffect(Bar);
    m_shadowEffect->setColor(QColor(0, 0, 0, 0x48));
    m_shadowEffect->setOffset(0, SHADOW_OFFSET_Y);
    m_shadowEffect->setBlurRadius(SHADOW_BLUR_RADIUS);
    m_shadowEffect->setEnabled(false);
    Bar->setGraphicsEffect(m_shadowEffect);

    m_opacityAnimation = new QPropertyAnimation(this, "windowOpacity", this);
    m_opacityAnimation->setDuration(OPACITY_ANIMATION_DURATION);

    m_mouseTimer = new QTimer(this);
    m_mouseTimer->setInterval(50);
    connect(m_mouseTimer, &QTimer::timeout, this, &FloatingBarClass::updateMouseStatus);

#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    // 系统切换深浅色时，跟随系统的 Win11 样式跟着变
    connect(QGuiApplication::styleHints(), &QStyleHints::colorSchemeChanged, this, &FloatingBarClass::updateStyle);
#endif
}

FloatingBarClass::~FloatingBarClass()
{}

bool FloatingBarClass::isDarkTheme() const
{
    switch (config.floating_bar.floating_bar_theme) {
        case FloatingBarTheme::Light: return false;
        case FloatingBarTheme::Dark: return true;
        default: break;
    }
#if QT_VERSION >= QT_VERSION_CHECK(6, 5, 0)
    return QGuiApplication::styleHints()->colorScheme() == Qt::ColorScheme::Dark;
#else
    return false;
#endif
}

void FloatingBarClass::updateStyle()
{
    const QString radius = QString::number(config.floating_bar.floating_bar_border_radius);
    if (config.floating_bar.floating_bar_style == FloatingBarStyle::Win11) {
        // 仿 Win11（参考 ClassIsland 的 Fluent 主题）：只换背景——纯色底、1px 描边（底边稍深）、圆角和阴影，文字不变
        const bool dark = isDarkTheme();
        Bar->setStyleSheet(QString("background: %1; border: 1px solid %2; border-bottom-color: %3; border-radius: %4px; color: red;")
            .arg(dark ? "rgb(28, 28, 28)" : "rgb(238, 238, 238)",
                 dark ? "rgba(255, 255, 255, 0.07)" : "rgba(0, 0, 0, 0.06)",
                 dark ? "rgba(255, 255, 255, 0.09)" : "rgba(0, 0, 0, 0.16)",
                 radius));
        m_shadowEffect->setEnabled(true);
    }
    else {
        Bar->setStyleSheet("background: rgba(255, 255, 255, 0.75); border-radius: " + radius + "px; color: red;");
        m_shadowEffect->setEnabled(false);
    }
    updatePosition();
}

void FloatingBarClass::updateWindowFlags()
{
    Qt::WindowFlags flags = (config.floating_bar.floating_bar_on_top ? Qt::WindowStaysOnTopHint : Qt::WindowStaysOnBottomHint) | Qt::FramelessWindowHint | Qt::Tool;
    if (config.floating_bar.is_mouse_click_through_enabled)
        flags |= Qt::WindowTransparentForInput; // 鼠标点击直接穿过悬浮条
    if (flags == this->windowFlags())
        return;
    const bool visible = this->isVisible();
    this->setWindowFlags(flags);
    if (visible)
        this->show(); // 修改窗口标志会把窗口隐藏
}

void FloatingBarClass::showEvent(QShowEvent* event)
{
    QWidget::showEvent(event);
    m_isClickThroughPending = true;
}

void FloatingBarClass::paintEvent(QPaintEvent* event)
{
    QWidget::paintEvent(event);
    // 第一次画出来时窗口已经真正显示了（已被窗口管理器接管），这时再设置一次点击穿透
    if (m_isClickThroughPending) {
        m_isClickThroughPending = false;
        QTimer::singleShot(0, this, &FloatingBarClass::reapplyClickThrough);
    }
}

void FloatingBarClass::reapplyClickThrough()
{
    // Linux 上 XFCE 的 xfwm4 会给窗口套一层外框，它只在接管窗口之后收到点击穿透（输入区域）的变化时才会让外框也跟着穿透，
    // 而 Qt 是在窗口隐藏时设置的，所以窗口显示后在这里关一下再开一下。Windows 没有这个问题
    if (QGuiApplication::platformName() != "xcb" || !config.floating_bar.is_mouse_click_through_enabled || !this->isVisible() || !this->windowHandle())
        return;
    this->windowHandle()->setFlag(Qt::WindowTransparentForInput, false);
    this->windowHandle()->setFlag(Qt::WindowTransparentForInput, true);
}

void FloatingBarClass::updateOpacity()
{
    const bool fading = config.floating_bar.is_mouse_in_fading_enabled;
    if (fading && !m_mouseTimer->isActive())
        m_mouseTimer->start();
    else if (!fading && m_mouseTimer->isActive())
        m_mouseTimer->stop();
    if (!fading)
        m_isMouseIn = false;

    double opacity = qBound(0u, config.floating_bar.floating_bar_opacity, 100u) / 100.0;
    if (m_isMouseIn)
        opacity = qMin(opacity, MOUSE_IN_FADED_OPACITY);

    m_opacityAnimation->stop();
    m_opacityAnimation->setStartValue(this->windowOpacity());
    m_opacityAnimation->setEndValue(opacity);
    m_opacityAnimation->start();
}

void FloatingBarClass::updateMouseStatus()
{
    // 开了点击穿透后窗口收不到鼠标事件，所以和 ClassIsland 一样直接查询鼠标位置；触摸也会移动鼠标位置，处理方式相同
    const bool mouseIn = this->isVisible() && QRect(Bar->mapToGlobal(QPoint(0, 0)), Bar->size()).contains(QCursor::pos());
    if (mouseIn != m_isMouseIn) {
        m_isMouseIn = mouseIn;
        updateOpacity();
    }
}

void FloatingBarClass::updatePosition()
{
    const QRect desktop = QApplication::primaryScreen()->geometry();

    // Win11 样式的阴影画在 Bar 外面，窗口四周要留出位置；贴着屏幕边的那一侧不留，悬浮条本身的位置不变
    QMargins margins;
    if (m_shadowEffect->isEnabled()) {
        margins = QMargins(SHADOW_BLUR_RADIUS, SHADOW_BLUR_RADIUS - SHADOW_OFFSET_Y, SHADOW_BLUR_RADIUS, SHADOW_BLUR_RADIUS + SHADOW_OFFSET_Y);
        margins.setTop(qMin(margins.top(), int(config.floating_bar.floating_bar_top_margin)));
        if (config.floating_bar.floating_bar_position == FloatingBarPosition::TopLeft)
            margins.setLeft(0);
        if (config.floating_bar.floating_bar_position == FloatingBarPosition::TopRight)
            margins.setRight(0);
    }

    Bar->move(margins.left(), margins.top());
    this->resize(Bar->width() + margins.left() + margins.right(), Bar->height() + margins.top() + margins.bottom());

    int x = 0;
    switch (config.floating_bar.floating_bar_position) {
        case FloatingBarPosition::TopCenter:
            x = (desktop.width() - Bar->width()) / 2;
            break;
        case FloatingBarPosition::TopRight:
            x = desktop.width() - Bar->width();
            break;
        case FloatingBarPosition::TopLeft:
            x = 0;
            break;
    }
    this->move(x - margins.left(), int(config.floating_bar.floating_bar_top_margin) - margins.top());
}
EOF
        replace_once f3 "$nl" "${OLD%$'\n'}" "$NEW" 'FloatingBar.cpp（第 2 处）' || return 1
    fi

    if has "$f4" 'IsMouseClickThroughCheckBox'; then
        gray '  [跳过] SettingsContent.h 已经改过'
    else
        nl=$(newline_of "$f4")
        anchor OLD <<'EOF'
    QSpinBox* FloatingBarHeightSpinBox;
    QSpinBox* FloatingBarBorderRadiusSpinBox;

    // Reminder
EOF
        anchor NEW <<'EOF'
    QSpinBox* FloatingBarHeightSpinBox;
    QSpinBox* FloatingBarBorderRadiusSpinBox;
    QSpinBox* FloatingBarTopMarginSpinBox;
    QSpinBox* FloatingBarOpacitySpinBox;
    QComboBox* FloatingBarStyleComboBox;
    QComboBox* FloatingBarThemeComboBox;
    QCheckBox* IsMouseInFadingCheckBox;
    QCheckBox* IsMouseClickThroughCheckBox;

    // Reminder
EOF
        replace_once f4 "$nl" "$OLD" "$NEW" 'SettingsContent.h（第 1 处）' || return 1
    fi

    if has "$f5" 'IsMouseClickThroughCheckBox'; then
        gray '  [跳过] SettingsContent.cpp 已经改过'
    else
        nl=$(newline_of "$f5")
        anchor OLD <<'EOF'
    FloatingBarBorderRadiusSpinBox->setValue(config.floating_bar.floating_bar_border_radius);
    FloatingBarBorderRadiusSpinBox->setSuffix(tr(" 像素")); // 悬浮条圆角半径后缀文本

    // Reminder
EOF
        anchor NEW <<'EOF'
    FloatingBarBorderRadiusSpinBox->setValue(config.floating_bar.floating_bar_border_radius);
    FloatingBarBorderRadiusSpinBox->setSuffix(tr(" 像素")); // 悬浮条圆角半径后缀文本
    FloatingBarTopMarginSpinBox = new QSpinBox(FloatingBarSettingsPage);
    FloatingBarTopMarginSpinBox->setRange(0, 5714);
    FloatingBarTopMarginSpinBox->setValue(config.floating_bar.floating_bar_top_margin);
    FloatingBarTopMarginSpinBox->setSuffix(tr(" 像素")); // 悬浮条距顶边距离后缀文本
    FloatingBarOpacitySpinBox = new QSpinBox(FloatingBarSettingsPage);
    FloatingBarOpacitySpinBox->setRange(0, 100);
    FloatingBarOpacitySpinBox->setValue(config.floating_bar.floating_bar_opacity);
    FloatingBarOpacitySpinBox->setSuffix(tr(" %")); // 悬浮条不透明度后缀文本
    FloatingBarStyleComboBox = new QComboBox(FloatingBarSettingsPage);
    FloatingBarStyleComboBox->addItems({tr("默认"), tr("Win11")});
    FloatingBarStyleComboBox->setCurrentIndex(config.floating_bar.floating_bar_style == FloatingBarStyle::Win11 ? 1 : 0);
    FloatingBarThemeComboBox = new QComboBox(FloatingBarSettingsPage);
    FloatingBarThemeComboBox->addItems({tr("跟随系统"), tr("浅色"), tr("深色")});
    FloatingBarThemeComboBox->setCurrentIndex(config.floating_bar.floating_bar_theme == FloatingBarTheme::Light ? 1 : (config.floating_bar.floating_bar_theme == FloatingBarTheme::Dark ? 2 : 0));
    IsMouseInFadingCheckBox = new QCheckBox(tr("鼠标移入时淡化"), FloatingBarSettingsPage);
    IsMouseInFadingCheckBox->setChecked(config.floating_bar.is_mouse_in_fading_enabled);
    IsMouseClickThroughCheckBox = new QCheckBox(tr("鼠标点击穿透"), FloatingBarSettingsPage);
    IsMouseClickThroughCheckBox->setChecked(config.floating_bar.is_mouse_click_through_enabled);

    // Reminder
EOF
        replace_once f5 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条高度："), FloatingBarHeightSpinBox);
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条圆角半径："), FloatingBarBorderRadiusSpinBox);
    FloatingBarSettingsPageLayout->setContentsMargins(25, 25, 25, 25);
    FloatingBarSettingsPage->setLayout(FloatingBarSettingsPageLayout);
EOF
        anchor NEW <<'EOF'
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条高度："), FloatingBarHeightSpinBox);
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条圆角半径："), FloatingBarBorderRadiusSpinBox);
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条距顶边距离："), FloatingBarTopMarginSpinBox);
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条不透明度："), FloatingBarOpacitySpinBox);
    FloatingBarSettingsPageLayout->addRow(tr("悬浮条样式："), FloatingBarStyleComboBox);
    FloatingBarSettingsPageLayout->addRow(tr("Win11 样式深浅色："), FloatingBarThemeComboBox);
    FloatingBarSettingsPageLayout->addRow(IsMouseInFadingCheckBox);
    FloatingBarSettingsPageLayout->addRow(IsMouseClickThroughCheckBox);
    FloatingBarSettingsPageLayout->setContentsMargins(25, 25, 25, 25);
    FloatingBarSettingsPage->setLayout(FloatingBarSettingsPageLayout);
EOF
        replace_once f5 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 2 处）' || return 1
        anchor OLD <<'EOF'
    connect(FloatingBarLevelComboBox, &QComboBox::currentIndexChanged, this, [this](int index) {
        config.set(config.floating_bar.floating_bar_on_top, index == 0);
        FloatingBar->setWindowFlags((config.floating_bar.floating_bar_on_top ? Qt::WindowStaysOnTopHint : Qt::WindowStaysOnBottomHint) | Qt::FramelessWindowHint | Qt::Tool);
        FloatingBar->hide();
        FloatingBar->show();
EOF
        anchor NEW <<'EOF'
    connect(FloatingBarLevelComboBox, &QComboBox::currentIndexChanged, this, [this](int index) {
        config.set(config.floating_bar.floating_bar_on_top, index == 0);
        FloatingBar->updateWindowFlags();
        FloatingBar->hide();
        FloatingBar->show();
EOF
        replace_once f5 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 3 处）' || return 1
        anchor OLD <<'EOF'
    connect(FloatingBarHeightSpinBox, &QSpinBox::valueChanged, this, [this](int value) {
        config.set(config.floating_bar.floating_bar_height, value);
        FloatingBar->setFixedHeight(value);
        QFont font;
        font.setPixelSize(value * GOLDEN_RATIO_INV);
        FloatingBar->Bar->setFont(font);
        FloatingBarBorderRadiusSpinBox->setMaximum(value / 2);
        });
    connect(FloatingBarBorderRadiusSpinBox, &QSpinBox::valueChanged, this, [this](int value) {
        config.set(config.floating_bar.floating_bar_border_radius, value);
        FloatingBar->Bar->setStyleSheet("background: rgba(255, 255, 255, 0.75); border-radius: " + QString::number(value) + "px; color: red;"); // 更新悬浮条样式
        });

EOF
        anchor NEW <<'EOF'
    connect(FloatingBarHeightSpinBox, &QSpinBox::valueChanged, this, [this](int value) {
        config.set(config.floating_bar.floating_bar_height, value);
        FloatingBar->Bar->resize(FloatingBar->Bar->width(), value);
        QFont font;
        font.setPixelSize(value * GOLDEN_RATIO_INV);
        FloatingBar->Bar->setFont(font);
        FloatingBar->updatePosition();
        FloatingBarBorderRadiusSpinBox->setMaximum(value / 2);
        });
    connect(FloatingBarBorderRadiusSpinBox, &QSpinBox::valueChanged, this, [this](int value) {
        config.set(config.floating_bar.floating_bar_border_radius, value);
        FloatingBar->updateStyle(); // 更新悬浮条样式
        });
    connect(FloatingBarTopMarginSpinBox, &QSpinBox::valueChanged, this, [this](int value) {
        config.set(config.floating_bar.floating_bar_top_margin, value);
        FloatingBar->updatePosition();
        });
    connect(FloatingBarOpacitySpinBox, &QSpinBox::valueChanged, this, [this](int value) {
        config.set(config.floating_bar.floating_bar_opacity, value);
        FloatingBar->updateOpacity();
        });
    connect(FloatingBarStyleComboBox, &QComboBox::currentIndexChanged, this, [this](int index) {
        config.set(config.floating_bar.floating_bar_style, index == 1 ? FloatingBarStyle::Win11 : FloatingBarStyle::Default);
        FloatingBar->updateStyle();
        });
    connect(FloatingBarThemeComboBox, &QComboBox::currentIndexChanged, this, [this](int index) {
        config.set(config.floating_bar.floating_bar_theme, index == 1 ? FloatingBarTheme::Light : (index == 2 ? FloatingBarTheme::Dark : FloatingBarTheme::FollowSystem));
        FloatingBar->updateStyle();
        });
    connect(IsMouseInFadingCheckBox, &QCheckBox::toggled, this, [this](bool checked) {
        config.set(config.floating_bar.is_mouse_in_fading_enabled, checked);
        FloatingBar->updateOpacity();
        });
    connect(IsMouseClickThroughCheckBox, &QCheckBox::toggled, this, [this](bool checked) {
        config.set(config.floating_bar.is_mouse_click_through_enabled, checked);
        FloatingBar->updateWindowFlags();
        });

EOF
        replace_once f5 "$nl" "$OLD" "$NEW" 'SettingsContent.cpp（第 4 处）' || return 1
    fi

    if has "$f6" 'FloatingBar->updatePosition'; then
        gray '  [跳过] UniversalTimer2.cpp 已经改过'
    else
        nl=$(newline_of "$f6")
        anchor OLD <<'EOF'

    // Floating Bar
    FloatingBar = new FloatingBarClass;

    // Fullscreen Pages
EOF
        anchor NEW <<'EOF'

    // Floating Bar
    FloatingBar = new FloatingBarClass(config);

    // Fullscreen Pages
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（第 1 处）' || return 1
        anchor OLD <<'EOF'
    if (!config.floating_bar.is_show_floating_bar) FloatingBar->hide();
    else FloatingBar->show();
    FloatingBar->Bar->setStyleSheet("background: rgba(255, 255, 255, 0.75); border-radius: " + QString::number(config.floating_bar.floating_bar_border_radius) + "px; color: red;"); // 更新悬浮条样式
    FloatingBar->setWindowFlags((config.floating_bar.floating_bar_on_top ? Qt::WindowStaysOnTopHint : Qt::WindowStaysOnBottomHint) | Qt::FramelessWindowHint | Qt::Tool);
    FloatingBar->setFixedHeight(config.floating_bar.floating_bar_height);
    QFont font;
    font.setPixelSize(config.floating_bar.floating_bar_height * GOLDEN_RATIO_INV);
    FloatingBar->Bar->setFont(font);

    // Reminder
EOF
        anchor NEW <<'EOF'
    if (!config.floating_bar.is_show_floating_bar) FloatingBar->hide();
    else FloatingBar->show();
    FloatingBar->updateWindowFlags(); // 更新悬浮条层级和点击穿透
    FloatingBar->Bar->resize(FloatingBar->Bar->width(), config.floating_bar.floating_bar_height);
    QFont font;
    font.setPixelSize(config.floating_bar.floating_bar_height * GOLDEN_RATIO_INV);
    FloatingBar->Bar->setFont(font);
    FloatingBar->updateStyle(); // 更新悬浮条样式（以及大小和位置）
    FloatingBar->updateOpacity(); // 更新悬浮条不透明度和鼠标移入淡化

    // Reminder
EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（第 2 处）' || return 1
        anchor OLD <<'EOF'
    FloatingBar->Bar->adjustSize();
    FloatingBar->Bar->resize(FloatingBar->Bar->width() + 20, config.floating_bar.floating_bar_height);
    FloatingBar->adjustSize();

    // 更新位置
    switch (config.floating_bar.floating_bar_position) {
        case FloatingBarPosition::TopCenter:
            FloatingBar->move((desktop.width() - FloatingBar->width()) / 2, 0);
            break;
        case FloatingBarPosition::TopRight:
            FloatingBar->move(desktop.width() - FloatingBar->width(), 0);
            break;
        case FloatingBarPosition::TopLeft:
            FloatingBar->move(0, 0);
            break;
    }
}

EOF
        anchor NEW <<'EOF'
    FloatingBar->Bar->adjustSize();
    FloatingBar->Bar->resize(FloatingBar->Bar->width() + 20, config.floating_bar.floating_bar_height);

    // 更新位置（以及窗口大小，Win11 样式要给阴影留位置）
    FloatingBar->updatePosition();
}

EOF
        replace_once f6 "$nl" "$OLD" "$NEW" 'UniversalTimer2.cpp（第 3 处）' || return 1
    fi
}

if ! edit; then
    echo
    err "$FAIL"
    warn '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修改的人。'
    finish 1
fi

CHANGED=()
for i in 0 1 2 3 4 5 6; do
    a="f$i"; b="f${i}_0"; p="P_$i"
    [ "${!a}" != "${!b}" ] && CHANGED+=("$i")
done
if [ ${#CHANGED[@]} -eq 0 ]; then
    echo
    ok '这个项目已经改过了，没有需要修改的地方。'
    finish 0
fi

# 全部对上了才开始写：先备份
start_backup "$P_0" "$P_1" "$P_2" "$P_3" "$P_4" "$P_5" "$P_6"
for i in "${CHANGED[@]}"; do
    a="f$i"; p="P_$i"
    if ! printf '%s' "${!a}" > "$ROOT/${!p}"; then
        err "写入失败：${!p}。请运行 bash undo.sh 恢复。"
        finish 1
    fi
    ok "  [已修改] ${!p}"
done

echo
ok '完成！'
printf '\033[36m%s\033[0m\n' '接下来重新编译运行即可。新选项在“设置中心 → 悬浮条设置”里。'
echo "原文件已备份到：$BACKUP"
echo '想恢复原样，运行：bash undo.sh'
finish 0
