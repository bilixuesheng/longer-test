# 事件点胶囊展开修复 · 一键应用到 Universal-Timer
# 由 apply.bat 调用；不需要 git。修改内容与 capsule-width-fix.patch 相同：
#   src/ui/EventPointReminder.h / .cpp —— 让 m_label 始终铺满胶囊（resizeEvent），去掉 m_adjustLabelAnimation
# 无论有没有应用过“事件点全屏提醒”都可以用。
# 先在内存里改完，任何一步对不上就一个文件都不动；修改前把原文件备份到本工具的 backup 文件夹。

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
Say '==== 事件点胶囊展开修复 · 一键应用 ====' 'Cyan'

$root = Find-ProjectRoot
if (-not $root) {
    Say '没有找到 Universal-Timer 项目文件夹。' 'Red'
    Say '请把整个工具文件夹放进项目文件夹里再双击 apply.bat，或者把项目文件夹拖到 apply.bat 上。' 'Yellow'
    exit 1
}
Say ('项目位置：' + $root)

try {
    $header = Read-Source (Join-Path $root 'src/ui/EventPointReminder.h')
    $source = Read-Source (Join-Path $root 'src/ui/EventPointReminder.cpp')
} catch {
    Say ('读取项目文件失败：' + $_.Exception.Message) 'Red'
    exit 1
}

try {
    # 1. EventPointReminder.h：声明 resizeEvent，去掉 m_adjustLabelAnimation
    if (Has $header 'void resizeEvent(') {
        Say '  [跳过] EventPointReminder.h 已修复' 'DarkGray'
    } else {
        Replace-Once $header @'
#include <QScreen>

'@ @'
#include <QScreen>
#include <QResizeEvent>

'@ 'EventPointReminder.h（头文件）'
        Replace-Once $header @'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);


'@ @'
    explicit EventPointReminder(QWidget* parent, const EventPoint& eventPoint);

protected:

    void resizeEvent(QResizeEvent* event) override;


'@ 'EventPointReminder.h（resizeEvent 声明）'
        Replace-Once $header @'
    QPropertyAnimation* m_adjustLabelAnimation;

'@ '' 'EventPointReminder.h（m_adjustLabelAnimation）'
    }

    # 2. EventPointReminder.cpp：m_label 始终铺满胶囊
    if (Has $source 'EventPointReminder::resizeEvent') {
        Say '  [跳过] EventPointReminder.cpp 已修复' 'DarkGray'
    } else {
        Replace-Once $source @'
    m_adjustLabelAnimation = new QPropertyAnimation(m_label, "size");
    m_adjustLabelAnimation->setDuration(500);
    m_adjustLabelAnimation->setEasingCurve(QEasingCurve::OutCubic);


'@ '' 'EventPointReminder.cpp（setupAnimation）'
        Replace-Once $source @'
    m_label->adjustSize();
    m_adjustAnimation->setStartValue(this->geometry());
    m_adjustAnimation->setEndValue(QRect((desktop.width() - m_label->width() / GOLDEN_RATIO_INV) / 2, desktop.height() * 0.1, m_label->width() / GOLDEN_RATIO_INV, this->height()));
    m_adjustLabelAnimation->setStartValue(this->size());
    m_adjustLabelAnimation->setEndValue(QSize(m_label->width() / GOLDEN_RATIO_INV, this->height()));
    m_adjustAnimation->start();
    m_adjustLabelAnimation->start();

'@ @'
    // 只量出文字需要的宽度，不改 m_label 的大小（它始终铺满胶囊，见 resizeEvent）
    const int labelWidth = m_label->sizeHint().width();
    m_adjustAnimation->setStartValue(this->geometry());
    m_adjustAnimation->setEndValue(QRect((desktop.width() - labelWidth / GOLDEN_RATIO_INV) / 2, desktop.height() * 0.1, labelWidth / GOLDEN_RATIO_INV, this->height()));
    m_adjustAnimation->start();

'@ 'EventPointReminder.cpp（updateLabel）'
        $source.Text += Use-Newline $source @'


void EventPointReminder::resizeEvent(QResizeEvent* event)
{
    QLabel::resizeEvent(event);
    // 胶囊本身设置了 WA_TranslucentBackground，Qt 不会绘制它自己的样式表背景和红边，
    // 屏幕上看到的黑底红边其实是 m_label。让 m_label 始终铺满胶囊，展开和宽度变化的动画才能完整显示
    m_label->setGeometry(this->rect());
}
'@
    }
} catch {
    Say ''
    Say $_.Exception.Message 'Red'
    Say '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。' 'Yellow'
    exit 1
}

$changed = @($header, $source | Where-Object { $_.Text -ne $_.Original })
if ($changed.Count -eq 0) {
    Say ''
    Say '这个项目已经修复过了，没有需要修改的地方。' 'Green'
    exit 0
}

# 全部对上了才开始写：先备份
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $PackageDir ('backup/' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Set-Content -LiteralPath (Join-Path $backup 'project.txt') -Value $root -Encoding UTF8
foreach ($f in @($header, $source)) {
    $relative = $f.Path.Substring($root.Length).TrimStart('\', '/')
    $target = Join-Path $backup ('original/' + $relative)
    New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
    Copy-Item -LiteralPath $f.Path -Destination $target -Force
}

foreach ($f in $changed) {
    Write-Source $f
    Say ('  [已修改] ' + $f.Path.Substring($root.Length).TrimStart('\', '/')) 'Green'
}

Say ''
Say '完成！' 'Green'
Say '接下来在 Qt Creator（或 Visual Studio）里重新编译运行即可。' 'Cyan'
Say ('原文件已备份到：' + $backup)
Say '想恢复原样，双击 undo.bat。'
exit 0
