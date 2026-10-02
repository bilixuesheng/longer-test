#!/usr/bin/env bash
# 撤销：用最近一次 apply.sh（或 apply.bat）留下的备份恢复原文件，并删除新增的文件。
# 用法：在工具文件夹里打开终端，运行  bash undo.sh
[ -z "${BASH_VERSION:-}" ] && exec bash "$0" "$@"

TITLE='事件点倒计时数字闪烁修复 · 撤销'
PKG=$(cd -- "$(dirname -- "$0")" && pwd)
. "$PKG/tools/common.sh"

echo
printf '\033[36m%s\033[0m\n' "==== $TITLE ===="

LATEST=
for d in "$PKG"/backup/*/; do
    d=${d%/}
    [ "$(basename -- "$d")" = restored ] && continue
    [ -f "$d/project.txt" ] && LATEST=$d   # 目录名是时间，按字母顺序最后一个就是最新的
done
if [ -z "$LATEST" ]; then
    warn '没有找到可以恢复的备份（还没应用过，或者已经撤销过了）。'
    finish 1
fi

ROOT=$(head -n 1 -- "$LATEST/project.txt" | tr -d '\r')
ROOT=${ROOT#$'\xef\xbb\xbf'}
if [ ! -d "$ROOT" ]; then
    err "备份记录的项目文件夹不存在了：$ROOT"
    finish 1
fi
echo "项目位置：$ROOT"

if [ -d "$LATEST/original" ]; then
    while IFS= read -r rel; do
        rel=${rel#./}
        cp -p -- "$LATEST/original/$rel" "$ROOT/$rel"
        ok "  [已恢复] $rel"
    done < <(cd -- "$LATEST/original" && find . -type f | sort)
fi
if [ -f "$LATEST/added.txt" ]; then
    while IFS= read -r rel; do
        rel=${rel%$'\r'}
        [ -n "$rel" ] && [ -f "$ROOT/$rel" ] && rm -f -- "$ROOT/$rel" && ok "  [已删除] $rel"
    done < "$LATEST/added.txt"
fi

# 用过的备份移到 restored 里，下次撤销不会再用它
mkdir -p -- "$PKG/backup/restored"
mv -- "$LATEST" "$PKG/backup/restored/"

echo
ok '已恢复原样。重新编译即可。'
finish 0
