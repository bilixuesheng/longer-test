# 一键应用工具的公共函数（Linux / macOS，bash）
# 由 apply.sh / undo.sh 引入，需要先设置 PKG（工具文件夹的绝对路径）。

ok()   { printf '\033[32m%s\033[0m\n' "$*"; }
warn() { printf '\033[33m%s\033[0m\n' "$*"; }
err()  { printf '\033[31m%s\033[0m\n' "$*"; }
gray() { printf '\033[90m%s\033[0m\n' "$*"; }

# 在终端里双击运行时，窗口会在结束后立刻关闭，先停一下让人看到结果
finish() {
    local code=$1
    if [ -t 0 ] && [ -t 1 ]; then printf '\n按回车键关闭…'; read -r _ || true; fi
    exit "$code"
}

is_root() { [ -f "$1/src/ui/EventPointReminder.cpp" ]; }

# 依次查找：命令行参数 → 工具所在位置往上 → 工具旁边的文件夹 → 弹窗选择（有 zenity 时）
find_root() {
    local d
    if [ -n "${1:-}" ] && is_root "$1"; then (cd -- "$1" && pwd); return 0; fi
    d=$PKG
    while :; do
        if is_root "$d"; then printf '%s\n' "$d"; return 0; fi
        [ "$d" = / ] && break
        d=$(dirname -- "$d")
    done
    for d in "$PKG"/*/ "$(dirname -- "$PKG")"/*/; do
        if [ -d "$d" ] && is_root "${d%/}"; then (cd -- "$d" && pwd); return 0; fi
    done
    if command -v zenity >/dev/null 2>&1 && [ -n "${DISPLAY:-}${WAYLAND_DISPLAY:-}" ]; then
        d=$(zenity --file-selection --directory --title='请选择 Universal-Timer 项目文件夹（里面有 src 的那一层）' 2>/dev/null) || d=
        if [ -n "$d" ] && is_root "$d"; then printf '%s\n' "$d"; return 0; fi
    fi
    return 1
}

# load 变量名 文件：原样读入（保留 BOM、CRLF 和末尾换行）
load() {
    local __content
    __content=$(cat -- "$2"; printf x) || return 1
    printf -v "$1" '%s' "${__content%x}"
}

# newline_of 文本：文件用 CRLF 就输出 crlf
newline_of() { if [[ $1 == *$'\r\n'* ]]; then echo crlf; else echo lf; fi; }

# has 文本 片段：片段（单行）是否出现在文本里
has() { [[ $1 == *"$2"* ]]; }

# replace_once 变量名 换行方式 旧文本 新文本 步骤名：只替换唯一的一处，失败时写入 FAIL 并返回 1
replace_once() {
    local -n __text=$1
    local old=$3 new=$4 step=$5 before after
    if [ "$2" = crlf ]; then old=${old//$'\n'/$'\r\n'}; new=${new//$'\n'/$'\r\n'}; fi
    if [[ $__text != *"$old"* ]]; then
        FAIL="[$step] 找不到要修改的原代码，可能这个文件已经被改过。"
        return 1
    fi
    before=${__text%%"$old"*}
    after=${__text#*"$old"}
    if [[ $after == *"$old"* ]]; then
        FAIL="[$step] 找到不止一处，无法确定改哪里。"
        return 1
    fi
    __text=$before$new$after
}

# anchor 变量名 <<'EOF' … EOF：把多行文本原样读进变量（以换行结尾）
anchor() { IFS= read -r -d '' "$1" || true; }

# start_backup 相对路径…：把这些文件复制到 backup/时间/original，返回备份目录到 BACKUP
start_backup() {
    local rel
    BACKUP="$PKG/backup/$(date +%Y%m%d_%H%M%S)"
    mkdir -p -- "$BACKUP/original"
    printf '%s\n' "$ROOT" > "$BACKUP/project.txt"
    for rel in "$@"; do
        if [ -f "$ROOT/$rel" ]; then
            mkdir -p -- "$BACKUP/original/$(dirname -- "$rel")"
            cp -p -- "$ROOT/$rel" "$BACKUP/original/$rel"
        else
            printf '%s\n' "$rel" >> "$BACKUP/added.txt"
        fi
    done
}
