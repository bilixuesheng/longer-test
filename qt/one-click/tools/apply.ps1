# 事件点全屏提醒 · 一键应用到 Universal-Timer
# 由 apply.bat 调用；不需要 git。
# 做的事情与 qt/integration.patch 完全相同：
#   1. 复制 EventPointFullscreenReminder.h/.cpp 到 src/ui/
#   2. 修改 src/CMakeLists.txt、src/ui/EventPointReminder.h/.cpp、src/core/UniversalTimer2.cpp
# 先在内存里改完全部文件，任何一步对不上就一个文件都不动；修改前把原文件备份到本工具的 backup 文件夹。

param([string]$ProjectDir = "")

$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageDir = Split-Path -Parent $ToolDir

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

function Test-Root([string]$dir) {
    if (-not $dir) { return $false }
    return (Test-Path -LiteralPath (Join-Path $dir 'src/ui/EventPointReminder.cpp'))
}

# 依次查找：拖到 bat 上的文件夹 → 工具所在位置往上 → 工具旁边的文件夹 → 弹窗选择
function Find-ProjectRoot {
    if ($ProjectDir) {
        $p = $ProjectDir.Trim('"')
        if (Test-Root $p) { return (Resolve-Path -LiteralPath $p).Path }
    }
    $dir = $PackageDir
    while ($dir) {
        if (Test-Root $dir) { return $dir }
        $parent = Split-Path -Parent $dir
        if (-not $parent -or $parent -eq $dir) { break }
        $dir = $parent
    }
    $around = @(Get-ChildItem -LiteralPath $PackageDir -Directory -ErrorAction SilentlyContinue)
    $outer = Split-Path -Parent $PackageDir
    if ($outer) { $around += @(Get-ChildItem -LiteralPath $outer -Directory -ErrorAction SilentlyContinue) }
    foreach ($d in $around) {
        if (Test-Root $d.FullName) { return $d.FullName }
    }
    try {
        Add-Type -AssemblyName System.Windows.Forms
        $dialog = New-Object System.Windows.Forms.FolderBrowserDialog
        $dialog.Description = '请选择 Universal-Timer 项目文件夹（里面有 src 文件夹的那一层）'
        $dialog.ShowNewFolderButton = $false
        if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
            if (Test-Root $dialog.SelectedPath) { return $dialog.SelectedPath }
            Say ('选择的文件夹里没有 src\ui\EventPointReminder.cpp：' + $dialog.SelectedPath) 'Red'
        }
    } catch { }
    return $null
}

# 按原样读写：保留 UTF-8 BOM 和换行符（LF / CRLF）
function Read-Source([string]$path) {
    $bytes = [System.IO.File]::ReadAllBytes($path)
    $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
    $text = (New-Object System.Text.UTF8Encoding($false)).GetString($bytes)
    if ($hasBom) { $text = $text.Substring(1) }
    $newline = "`n"
    if ($text.Contains("`r`n")) { $newline = "`r`n" }
    return [pscustomobject]@{ Path = $path; Text = $text; Original = $text; Bom = $hasBom; NL = $newline }
}

function Write-Source($file) {
    [System.IO.File]::WriteAllText($file.Path, $file.Text, (New-Object System.Text.UTF8Encoding($file.Bom)))
}

function Use-Newline($file, [string]$s) {
    return $s.Replace("`r`n", "`n").Replace("`n", $file.NL)
}

function Has($file, [string]$s) {
    return $file.Text.Contains((Use-Newline $file $s))
}

# 只替换唯一的一处；找不到或不唯一就报错（此时还没有写任何文件）
function Replace-Once($file, [string]$old, [string]$new, [string]$step) {
    $o = Use-Newline $file $old
    $n = Use-Newline $file $new
    $first = $file.Text.IndexOf($o, [System.StringComparison]::Ordinal)
    if ($first -lt 0) { throw ('[' + $step + '] 在 ' + $file.Path + ' 里找不到要修改的原代码，可能这个文件已经被改过。') }
    if ($file.Text.IndexOf($o, $first + 1, [System.StringComparison]::Ordinal) -ge 0) { throw ('[' + $step + '] 在 ' + $file.Path + ' 里找到不止一处，无法确定改哪里。') }
    $file.Text = $file.Text.Substring(0, $first) + $n + $file.Text.Substring($first + $o.Length)
}

Say ''
Say '==== 事件点全屏提醒 · 一键应用 ====' 'Cyan'

$root = Find-ProjectRoot
if (-not $root) {
    Say '没有找到 Universal-Timer 项目文件夹。' 'Red'
    Say '请把整个工具文件夹放进项目文件夹里再双击 apply.bat，或者把项目文件夹拖到 apply.bat 上。' 'Yellow'
    exit 1
}
Say ('项目位置：' + $root)

$newFiles = @('EventPointFullscreenReminder.h', 'EventPointFullscreenReminder.cpp')
foreach ($name in $newFiles) {
    if (-not (Test-Path -LiteralPath (Join-Path $PackageDir ('files/' + $name)))) {
        Say ('工具文件夹不完整，缺少 files\' + $name + '，请重新解压。') 'Red'
        exit 1
    }
}

try {
    $cmake = Read-Source (Join-Path $root 'src/CMakeLists.txt')
    $header = Read-Source (Join-Path $root 'src/ui/EventPointReminder.h')
    $source = Read-Source (Join-Path $root 'src/ui/EventPointReminder.cpp')
    $timer = Read-Source (Join-Path $root 'src/core/UniversalTimer2.cpp')
} catch {
    Say ('读取项目文件失败：' + $_.Exception.Message) 'Red'
    exit 1
}

try {
    # 1. CMakeLists.txt：加入新文件
    if (Has $cmake 'ui/EventPointFullscreenReminder.cpp') {
        Say '  [跳过] CMakeLists.txt 已包含新文件' 'DarkGray'
    } else {
        Replace-Once $cmake @'
    ui/EventPointReminder.cpp

'@ @'
    ui/EventPointReminder.cpp
    ui/EventPointFullscreenReminder.h
    ui/EventPointFullscreenReminder.cpp

'@ 'CMakeLists.txt'
    }

    # 2. EventPointReminder.h：新增 reached 信号
    if (Has $header 'void reached(') {
        Say '  [跳过] EventPointReminder.h 已有 reached 信号' 'DarkGray'
    } else {
        Replace-Once $header @'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);

'@ @'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);

Q_SIGNALS:

    void reached(const EventPoint& eventPoint, const QRect& capsuleGeometry); // 到达事件点，交给全屏提醒继续播放

'@ 'EventPointReminder.h'
    }

    # 3. EventPointReminder.cpp：到点时发出信号并收起自己
    if (Has $source 'emit reached(') {
        Say '  [跳过] EventPointReminder.cpp 已修改过' 'DarkGray'
    } else {
        Replace-Once $source @'
    int remainingSeconds = currentTime.secsTo(m_eventPoint.time());
    if (remainingSeconds <= 0) {
        m_label->setText(m_eventPoint.name());
    } else {
        m_label->setText(QString::number(remainingSeconds));
    }

'@ @'
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

'@ 'EventPointReminder.cpp（到点处理）'
        Replace-Once $source @'
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
'@ @'
    m_adjustAnimation->start();
    m_adjustLabelAnimation->start();
}
'@ 'EventPointReminder.cpp（删除旧的收起逻辑）'
    }

    # 4. UniversalTimer2.cpp：创建胶囊时连接 reached，打开全屏提醒
    if (Has $timer 'ui/EventPointFullscreenReminder.h') {
        Say '  [跳过] UniversalTimer2.cpp 已包含头文件' 'DarkGray'
    } else {
        Replace-Once $timer @'
#include "ui/EventPointReminder.h"

'@ @'
#include "ui/EventPointReminder.h"
#include "ui/EventPointFullscreenReminder.h"

'@ 'UniversalTimer2.cpp（头文件）'
    }
    if (Has $timer 'EventPointReminder::reached') {
        Say '  [跳过] UniversalTimer2.cpp 已连接 reached' 'DarkGray'
    } else {
        Replace-Once $timer @'
            EventPointReminder* event_point_reminder = new EventPointReminder(nullptr, event_point_item);
            event_point_reminder->setAttribute(Qt::WA_DeleteOnClose);

'@ @'
            EventPointReminder* event_point_reminder = new EventPointReminder(nullptr, event_point_item);
            event_point_reminder->setAttribute(Qt::WA_DeleteOnClose);
            connect(event_point_reminder, &EventPointReminder::reached, this, [this](const EventPoint& event_point, const QRect& capsule_geometry) {
                EventPointFullscreenReminder* event_point_fullscreen_reminder = new EventPointFullscreenReminder(event_point, config.event_point.event_point_list, capsule_geometry);
                event_point_fullscreen_reminder->start();
                });

'@ 'UniversalTimer2.cpp（连接信号）'
    }
} catch {
    Say ''
    Say $_.Exception.Message 'Red'
    Say '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个功能的人。' 'Yellow'
    exit 1
}

$changed = @($cmake, $header, $source, $timer | Where-Object { $_.Text -ne $_.Original })
if ($changed.Count -eq 0) {
    foreach ($name in $newFiles) {
        Copy-Item -LiteralPath (Join-Path $PackageDir ('files/' + $name)) -Destination (Join-Path $root ('src/ui/' + $name)) -Force
    }
    Say ''
    Say '这个项目已经应用过了，这次只把 EventPointFullscreenReminder 两个文件更新为最新版本。' 'Green'
    exit 0
}

# 全部对上了才开始写：先备份
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $PackageDir ('backup/' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Set-Content -LiteralPath (Join-Path $backup 'project.txt') -Value $root -Encoding UTF8
foreach ($f in @($cmake, $header, $source, $timer)) {
    $relative = $f.Path.Substring($root.Length).TrimStart('\', '/')
    $target = Join-Path $backup ('original/' + $relative)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $f.Path -Destination $target -Force
}
foreach ($name in $newFiles) {
    $existing = Join-Path $root ('src/ui/' + $name)
    if (Test-Path -LiteralPath $existing) {
        $target = Join-Path $backup ('original/src/ui/' + $name)
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        Copy-Item -LiteralPath $existing -Destination $target -Force
    } else {
        Add-Content -LiteralPath (Join-Path $backup 'added.txt') -Value ('src/ui/' + $name) -Encoding UTF8
    }
}

foreach ($f in $changed) {
    Write-Source $f
    Say ('  [已修改] ' + $f.Path.Substring($root.Length).TrimStart('\', '/')) 'Green'
}
foreach ($name in $newFiles) {
    Copy-Item -LiteralPath (Join-Path $PackageDir ('files/' + $name)) -Destination (Join-Path $root ('src/ui/' + $name)) -Force
    Say ('  [已复制] src/ui/' + $name) 'Green'
}

Say ''
Say '完成！' 'Green'
Say '接下来在 Qt Creator（或 Visual Studio）里重新运行一次 CMake，再编译运行即可。' 'Cyan'
Say ('原文件已备份到：' + $backup)
Say '想恢复原样，双击 undo.bat。'
exit 0
