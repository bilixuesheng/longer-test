# 事件点倒计时数字闪烁修复 · 一键应用到 Universal-Timer
# 由 apply.bat 调用；不需要 git。修改内容与 countdown-blink-fix.patch 相同：
#   src/ui/EventPointReminder.cpp —— 每秒重新开始数字动画前先 stop()，避免数字隔一秒消失
# 对不上就不改文件；修改前把原文件备份到本工具的 backup 文件夹。

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
Say '==== 事件点倒计时数字闪烁修复 · 一键应用 ====' 'Cyan'

$root = Find-ProjectRoot
if (-not $root) {
    Say '没有找到 Universal-Timer 项目文件夹。' 'Red'
    Say '请把整个工具文件夹放进项目文件夹里再双击 apply.bat，或者把项目文件夹拖到 apply.bat 上。' 'Yellow'
    exit 1
}
Say ('项目位置：' + $root)

try {
    $source = Read-Source (Join-Path $root 'src/ui/EventPointReminder.cpp')
} catch {
    Say ('读取项目文件失败：' + $_.Exception.Message) 'Red'
    exit 1
}

if (Has $source 'm_countdownGroup->stop();') {
    Say ''
    Say '这个项目已经修复过了，没有需要修改的地方。' 'Green'
    exit 0
}

try {
    Replace-Once $source @'
    m_adjustAnimation->start();
    m_countdownGroup->start();

'@ @'
    m_adjustAnimation->start();
    // 数字动画（250 + 500 + 250）正好 1 秒，和计时器间隔一样长；计时器稍微早到时动画还没结束，
    // 这时 start() 不会重新开始，数字就停在透明度 0，整整一秒看不到。先 stop() 再 start() 保证每秒都从头播放
    m_countdownGroup->stop();
    m_countdownGroup->start();

'@ 'EventPointReminder.cpp（updateLabel）'
} catch {
    Say ''
    Say $_.Exception.Message 'Red'
    Say '没有修改任何文件。可以把上面这段提示和对应的文件发给帮你做这个修复的人。' 'Yellow'
    exit 1
}

# 先备份再写
$stamp = Get-Date -Format 'yyyyMMdd_HHmmss'
$backup = Join-Path $PackageDir ('backup/' + $stamp)
New-Item -ItemType Directory -Path $backup -Force | Out-Null
Set-Content -LiteralPath (Join-Path $backup 'project.txt') -Value $root -Encoding UTF8
$relative = $source.Path.Substring($root.Length).TrimStart('\', '/')
$target = Join-Path $backup ('original/' + $relative)
New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
Copy-Item -LiteralPath $source.Path -Destination $target -Force

Write-Source $source
Say ('  [已修改] ' + $relative) 'Green'

Say ''
Say '完成！' 'Green'
Say '接下来重新编译运行即可。' 'Cyan'
Say ('原文件已备份到：' + $backup)
Say '想恢复原样，双击 undo.bat。'
exit 0
