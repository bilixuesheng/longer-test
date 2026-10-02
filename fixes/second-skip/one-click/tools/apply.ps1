# 事件点跳秒修复 · 一键应用到 Universal-Timer
# 由 apply.bat 调用；不需要 git。修改内容与 second-skip-fix.patch 相同：
#   倒计时数字、悬浮条秒数偶尔跳过或重复一秒，事件点 / 全屏提醒偶尔被错过。
#   EventPointReminder 和 UniversalTimer2 的计时器改成每次在下一个整秒刚过 50ms 时触发。
# 任何一步对不上就一个文件都不改；修改前把原文件备份到本工具的 backup 文件夹。

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
Say '==== 事件点跳秒修复 · 一键应用 ====' 'Cyan'

$root = Find-ProjectRoot
if (-not $root) {
    Say '没有找到 Universal-Timer 项目文件夹。' 'Red'
    Say '请把整个工具文件夹放进项目文件夹里再双击 apply.bat，或者把项目文件夹拖到 apply.bat 上。' 'Yellow'
    exit 1
}
Say ('项目位置：' + $root)

try {
    $f0 = Read-Source (Join-Path $root 'src/ui/EventPointReminder.h')
    $f1 = Read-Source (Join-Path $root 'src/ui/EventPointReminder.cpp')
    $f2 = Read-Source (Join-Path $root 'src/core/UniversalTimer2.h')
    $f3 = Read-Source (Join-Path $root 'src/core/UniversalTimer2.cpp')
} catch {
    Say ('读取项目文件失败：' + $_.Exception.Message) 'Red'
    exit 1
}

try {
    if (Has $f0 'scheduleNextTick') {
        Say '  [跳过] EventPointReminder.h 已修复' 'DarkGray'
    } else {
        Replace-Once $f0 @'
    void showReminder();

'@ @'
    void showReminder();
    void scheduleNextTick(); // 安排下一次更新：下一个整秒刚过 50ms

'@ 'EventPointReminder.h（声明）'
    }
    if (Has $f1 'EventPointReminder::scheduleNextTick') {
        Say '  [跳过] EventPointReminder.cpp 已修复' 'DarkGray'
    } else {
        Replace-Once $f1 @'
    m_timer = new QTimer(this);
    m_timer->start(1000);
    connect(m_timer, &QTimer::timeout, this, [this]() {
        updateLabel();
    });
}

'@ @'
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

'@ 'EventPointReminder.cpp（showReminder）'
        Replace-Once $f1 @'
    m_countdownGroup->start();
}
'@ @'
    m_countdownGroup->start();
    scheduleNextTick();
}
'@ 'EventPointReminder.cpp（updateLabel）'
    }
    if (Has $f2 'scheduleNextUpdate') {
        Say '  [跳过] UniversalTimer2.h 已修复' 'DarkGray'
    } else {
        Replace-Once $f2 @'
    void updateObjects(); // 更新对象

'@ @'
    void updateObjects(); // 更新对象
    void scheduleNextUpdate(); // 安排下一次更新：下一个整 update_interval 刚过 50ms

'@ 'UniversalTimer2.h（声明）'
    }
    if (Has $f3 'UniversalTimer2::scheduleNextUpdate') {
        Say '  [跳过] UniversalTimer2.cpp 已修复' 'DarkGray'
    } else {
        Replace-Once $f3 @'
    timer.start(config.general.update_interval);
    connect(&timer, &QTimer::timeout, this, &UniversalTimer2::updateObjects);

'@ @'
    timer.setSingleShot(true);
    timer.setTimerType(Qt::PreciseTimer);
    connect(&timer, &QTimer::timeout, this, [this] {
        updateObjects();
        scheduleNextUpdate();
    });
    scheduleNextUpdate();

'@ 'UniversalTimer2.cpp（计时器）'
        Replace-Once $f3 @'
// 更新函数
// 悬浮条更新函数

'@ @'
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

'@ 'UniversalTimer2.cpp（scheduleNextUpdate）'
    }
} catch {
    Say ''
    Say $_.Exception.Message 'Red'
    Say '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。' 'Yellow'
    exit 1
}

$changed = @($f0, $f1, $f2, $f3 | Where-Object { $_.Text -ne $_.Original })
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
foreach ($f in @($f0, $f1, $f2, $f3)) {
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
Say '接下来重新编译运行即可。' 'Cyan'
Say ('原文件已备份到：' + $backup)
Say '想恢复原样，双击 undo.bat。'
exit 0
