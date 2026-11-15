#!/usr/bin/env bash
set -euo pipefail

# =============================================================================
# 脚本名称: check-env.sh
# 功能描述: 检查 GNU awk、locale、示例数据和一次最小运行
# 用法:     bash scripts/check-env.sh [--help]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_DIR
readonly DATA_DIR="$REPO_DIR/examples/data"

usage() {
    cat <<EOF
用法: bash scripts/check-env.sh

检查项:
  - 找到 gawk, 或确认 awk 指向 GNU Awk
  - 打印版本、路径和 locale
  - 检查示例数据文件是否齐全
  - 运行一次最小 awk 命令

选项:
  -h, --help    显示本帮助

退出码:
  0  检查通过
  1  不是 GNU awk, 数据缺失或示例运行失败
  2  参数错误
EOF
}

die() {
    printf 'ERROR: %s\n' "$*" >&2
    exit 1
}

find_awk() {
    if command -v gawk >/dev/null 2>&1; then
        printf '%s\n' gawk
        return 0
    fi
    if command -v awk >/dev/null 2>&1; then
        printf '%s\n' awk
        return 0
    fi
    return 1
}

main() {
    case "${1:-}" in
        -h | --help)
            usage
            exit 0
            ;;
        "")
            ;;
        *)
            printf 'ERROR: 未知参数: %s\n' "$1" >&2
            usage >&2
            exit 2
            ;;
    esac

    local awk_bin
    awk_bin="$(find_awk)" || die "找不到 gawk 或 awk，请先安装 GNU awk"

    local awk_path
    awk_path="$(command -v "$awk_bin")"

    local version
    version="$("$awk_bin" --version 2>&1 | head -n 1 || true)"
    if [[ "$version" != *"GNU Awk"* ]]; then
        printf 'ERROR: %s 不是 GNU Awk。\n' "$awk_path" >&2
        printf '当前版本信息: %s\n' "$version" >&2
        printf '请安装 gawk，或让 awk 指向 GNU Awk。\n' >&2
        exit 1
    fi

    printf 'awk 路径: %s\n' "$awk_path"
    printf '版本: %s\n' "$version"
    printf 'locale: LC_ALL=%s LANG=%s LC_CTYPE=%s\n' \
        "${LC_ALL:-<未设置>}" "${LANG:-<未设置>}" "${LC_CTYPE:-<未设置>}"

    local char_len
    char_len="$("$awk_bin" 'BEGIN { print length("café") }')"
    printf 'UTF-8 长度探测: length("café") = %s (4 为按字符, 5 为按字节)\n' "$char_len"
    if [[ "$char_len" == "5" ]]; then
        printf '提示: 当前 locale 下按字节计数。需要字符计数时显式设置 UTF-8 locale，例如 LC_ALL=C.UTF-8。\n'
    fi

    local required_files=(
        employees.tsv
        scores.tsv
        sales.csv
        access.log
        poem.txt
        paragraphs.txt
        passwd.txt
        inventory.tsv
        orders.tsv
        numbers.txt
        messy.csv
        unicode.txt
        config.ini
        team-a.tsv
        team-b.tsv
        fixed-width.txt
    )
    local file
    for file in "${required_files[@]}"; do
        [[ -f "$DATA_DIR/$file" ]] || die "缺少数据文件: examples/data/$file"
    done
    printf '数据文件: %d 个检查通过\n' "${#required_files[@]}"

    local sample
    # shellcheck disable=SC2016  # $2/$3 是 awk 字段，不是 shell 参数
    sample="$("$awk_bin" -F '\t' 'NR == 2 { print $2, $3 }' "$DATA_DIR/employees.tsv")"
    if [[ "$sample" != "Alice Engineering" ]]; then
        die "最小示例输出不符合预期: $sample"
    fi

    printf '最小示例: %s\n' "$sample"
    printf '检查通过。可以开始阅读 docs/setup.md 或直接运行 bash scripts/verify.sh。\n'
}

main "$@"
