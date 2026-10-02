# 事件点胶囊展开修复 · 撤销
# 由 undo.bat 调用：用最近一次 apply 留下的备份恢复原文件，并删除新增的两个文件。

$ErrorActionPreference = 'Stop'
$ToolDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageDir = Split-Path -Parent $ToolDir

function Say($text, $color = 'Gray') { Write-Host $text -ForegroundColor $color }

Say ''
Say '==== 事件点胶囊展开修复 · 撤销 ====' 'Cyan'

$backupRoot = Join-Path $PackageDir 'backup'
$latest = $null
if (Test-Path -LiteralPath $backupRoot) {
    $latest = Get-ChildItem -LiteralPath $backupRoot -Directory |
        Where-Object { $_.Name -ne 'restored' -and (Test-Path -LiteralPath (Join-Path $_.FullName 'project.txt')) } |
        Sort-Object Name -Descending | Select-Object -First 1
}
if (-not $latest) {
    Say '没有找到可以恢复的备份（还没应用过，或者已经撤销过了）。' 'Yellow'
    exit 1
}

$root = (Get-Content -LiteralPath (Join-Path $latest.FullName 'project.txt') -Encoding UTF8 | Select-Object -First 1).Trim()
if (-not (Test-Path -LiteralPath $root)) {
    Say ('备份记录的项目文件夹不存在了：' + $root) 'Red'
    exit 1
}
Say ('项目位置：' + $root)

$original = Join-Path $latest.FullName 'original'
foreach ($file in @(Get-ChildItem -LiteralPath $original -Recurse -File)) {
    $relative = $file.FullName.Substring($original.Length).TrimStart('\', '/')
    Copy-Item -LiteralPath $file.FullName -Destination (Join-Path $root $relative) -Force
    Say ('  [已恢复] ' + $relative) 'Green'
}

$added = Join-Path $latest.FullName 'added.txt'
if (Test-Path -LiteralPath $added) {
    foreach ($line in @(Get-Content -LiteralPath $added -Encoding UTF8)) {
        $relative = $line.Trim()
        if (-not $relative) { continue }
        $path = Join-Path $root $relative
        if (Test-Path -LiteralPath $path) {
            Remove-Item -LiteralPath $path -Force
            Say ('  [已删除] ' + $relative) 'Green'
        }
    }
}

# 用过的备份移到 restored 里，下次撤销不会再用它
$restored = Join-Path $backupRoot 'restored'
New-Item -ItemType Directory -Path $restored -Force | Out-Null
Move-Item -LiteralPath $latest.FullName -Destination (Join-Path $restored $latest.Name) -Force

Say ''
Say '已恢复原样。重新运行一次 CMake 再编译即可。' 'Green'
exit 0
