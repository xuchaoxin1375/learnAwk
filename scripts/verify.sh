#!/usr/bin/env bash
# shellcheck disable=SC2016  # 大量单引号内是 awk 程序，$1 等不应由 shell 展开
set -euo pipefail

# =============================================================================
# 脚本名称: verify.sh
# 功能描述: 验证教程中的核心 awk 行为，不修改仓库文件
# 用法:     bash scripts/verify.sh [--help]
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly SCRIPT_DIR
REPO_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
readonly REPO_DIR
readonly DATA_DIR="$REPO_DIR/examples/data"
readonly SCRIPT_DATA_DIR="$REPO_DIR/examples/scripts"

TMP_DIR="$(mktemp -d)"
readonly TMP_DIR
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0

usage() {
    cat <<EOF
用法: bash scripts/verify.sh

验证教程中的核心行为:
  - 字段、记录、模式、正则
  - 数组、函数、printf、getline
  - GNU 扩展与脚本输出
  - UTF-8 locale 下的字符长度

不会修改仓库文件，临时文件放在系统临时目录并在退出时删除。

选项:
  -h, --help    显示本帮助
EOF
}

pass() {
    PASS=$((PASS + 1))
    printf 'ok   %s\n' "$1"
}

fail() {
    FAIL=$((FAIL + 1))
    printf 'FAIL %s\n' "$1" >&2
    printf '  expected: %s\n' "$2" >&2
    printf '  actual:   %s\n' "$3" >&2
}

check() {
    local name="$1"
    local expected="$2"
    local actual="$3"
    if [[ "$actual" == "$expected" ]]; then
        pass "$name"
    else
        fail "$name" "$expected" "$actual"
    fi
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
    awk_bin="$(find_awk)" || {
        printf 'ERROR: 找不到 gawk 或 awk\n' >&2
        exit 1
    }
    if ! "$awk_bin" --version 2>&1 | grep -q 'GNU Awk'; then
        printf 'ERROR: %s 不是 GNU Awk，无法验证本教程的 GNU 扩展\n' "$awk_bin" >&2
        exit 1
    fi

    cd "$REPO_DIR"
    export LC_ALL=C

    check "basic trace" "1 3 Alice 120000" \
        "$(printf 'Alice Engineering 120000\n' | "$awk_bin" '{ print NR, NF, $1, $NF }')"

    check "field count" "5" \
        "$("$awk_bin" -F '\t' 'NR == 2 { print NF }' "$DATA_DIR/employees.tsv")"

    check "last field" "Beijing" \
        "$("$awk_bin" -F '\t' 'NR == 2 { print $NF }' "$DATA_DIR/employees.tsv")"

    check "header skip" "12" \
        "$("$awk_bin" -F '\t' 'NR > 1 { n++ } END { print n }' "$DATA_DIR/employees.tsv")"

    check "department count" $'Engineering 4\nMarketing 2\nSales 3\nSupport 3' \
        "$("$awk_bin" -F '\t' 'NR > 1 { count[$3]++ } END { for (d in count) print d, count[d] }' "$DATA_DIR/employees.tsv" | sort)"

    check "average salary" "97250.00" \
        "$("$awk_bin" -F '\t' 'NR > 1 { sum += $4; n++ } END { printf "%.2f\n", sum / n }' "$DATA_DIR/employees.tsv")"

    check "max salary" "Carol 135000" \
        "$("$awk_bin" -F '\t' 'NR > 1 && $4 > max { max = $4; name = $2 } END { print name, max }' "$DATA_DIR/employees.tsv")"

    check "OFS rebuild" "1|X|Engineering|120000|Beijing" \
        "$(printf '1\tAlice\tEngineering\t120000\tBeijing\n' | "$awk_bin" -F '\t' 'BEGIN { OFS = "|" } { $2 = "X"; print }')"

    check "NF truncate" "a b" \
        "$(printf 'a b c\n' | "$awk_bin" '{ NF = 2; print }')"

    check "default whitespace" "3" \
        "$(printf '  Alice   Engineering   120000  \n' | "$awk_bin" '{ print NF }')"

    check "FS too late" "a:b" \
        "$(printf 'a:b\n' | "$awk_bin" '{ FS = ":"; print $1 }')"

    check "FS in BEGIN" "a" \
        "$(printf 'a:b\n' | "$awk_bin" 'BEGIN { FS = ":" } { print $1 }')"

    check "single-char FS literal" "3 b" \
        "$(printf 'a.b.c\n' | "$awk_bin" -F '.' '{ print NF, $2 }')"

    check "NR and FNR" $'examples/data/team-a.tsv 1 1 Alice\nexamples/data/team-a.tsv 2 2 Bob\nexamples/data/team-b.tsv 1 3 Carol\nexamples/data/team-b.tsv 2 4 Dave' \
        "$("$awk_bin" -F '\t' '{ print FILENAME, FNR, NR, $1 }' examples/data/team-a.tsv examples/data/team-b.tsv)"

    check "RS semicolon" "3" \
        "$(printf 'a;b;c' | "$awk_bin" 'BEGIN { RS = ";" } END { print NR }')"

    check "RT last record" "[c] []" \
        "$(printf 'a;b;c' | "$awk_bin" 'BEGIN { RS = ";" } END { print "[" $0 "]", "[" RT "]" }')"

    check "paragraph mode" "3" \
        "$("$awk_bin" 'BEGIN { RS = "" } END { print NR }' "$DATA_DIR/paragraphs.txt")"

    check "500 count" "4" \
        "$("$awk_bin" '$9 == 500 { n++ } END { print n }' "$DATA_DIR/access.log")"

    check "range 01-05..01-07" "5" \
        "$("$awk_bin" -F ',' '/2026-01-05/,/2026-01-07/ { n++ } END { print n }' "$DATA_DIR/sales.csv")"

    check "date compare" "6" \
        "$("$awk_bin" -F ',' 'NR > 1 && $1 >= "2026-01-05" && $1 <= "2026-01-07" { n++ } END { print n }' "$DATA_DIR/sales.csv")"

    check "next first line" "high Alice" \
        "$("$awk_bin" -F '\t' 'NR == 1 { next } $4 > 100000 { print "high", $2; next } { print "normal", $2 }' "$DATA_DIR/employees.tsv" | head -n 1)"

    check "nextfile first lines" $'examples/data/team-a.tsv Alice\nexamples/data/team-b.tsv Carol' \
        "$("$awk_bin" 'FNR == 1 { print FILENAME, $1; nextfile }' examples/data/team-a.tsv examples/data/team-b.tsv)"

    check "exit keeps END" "end 3" \
        "$("$awk_bin" 'NR == 3 { exit } END { print "end", NR }' "$DATA_DIR/employees.tsv")"

    check "status 200 count" "12" \
        "$("$awk_bin" '$9 == 200 { n++ } END { print n }' "$DATA_DIR/access.log")"

    check "department average" $'Engineering\t4\t123250.00\nMarketing\t2\t93500.00\nSales\t3\t92333.33\nSupport\t3\t70000.00' \
        "$("$awk_bin" -F '\t' 'NR > 1 { count[$3]++; sum[$3] += $4 } END { PROCINFO["sorted_in"] = "@ind_str_asc"; for (d in count) printf "%s\t%d\t%.2f\n", d, count[d], sum[d] / count[d] }' "$DATA_DIR/employees.tsv")"

    check "sorted status" $'200 12\n201 3\n304 2\n404 3\n500 4' \
        "$("$awk_bin" '{ count[$9]++ } END { PROCINFO["sorted_in"] = "@ind_num_asc"; for (s in count) print s, count[s] }' "$DATA_DIR/access.log")"

    check "split date" "3 2026 01 05" \
        "$("$awk_bin" 'BEGIN { n = split("2026-01-05", d, "-"); print n, d[1], d[2], d[3] }')"

    check "asorti first" "Engineering 493000" \
        "$("$awk_bin" -F '\t' 'NR > 1 { sum[$3] += $4 } END { n = asorti(sum, a); print a[1], sum[a[1]] }' "$DATA_DIR/employees.tsv")"

    check "dedupe" $'a\nb' \
        "$(printf 'a\nb\na\n' | "$awk_bin" '!seen[$0]++')"

    check "multidim" "449.10" \
        "$("$awk_bin" -F ',' 'NR > 1 { rev[$2, $3] += $4 * $5 } END { printf "%.2f\n", rev["East", "Keyboard"] }' "$DATA_DIR/sales.csv")"

    check "substr and index" $'hello\n7' \
        "$("$awk_bin" 'BEGIN { print substr("hello world", 1, 5); print index("hello world", "world") }')"

    check "gsub count" "2 a+b+c" \
        "$(printf 'a-b-c\n' | "$awk_bin" '{ n = gsub(/-/, "+"); print n, $0 }')"

    check "match positions" "6 10" \
        "$(printf 'date=2026-01-05;\n' | "$awk_bin" '{ match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); print RSTART, RLENGTH }')"

    check "sprintf pad" "00042" \
        "$("$awk_bin" 'BEGIN { print sprintf("%05d", 42) }')"

    check "strtonum" "42 31 63" \
        "$("$awk_bin" 'BEGIN { print strtonum("42"), strtonum("0x1f"), strtonum("077") }')"

    check "printf format" "|abc|42|3.14|" \
        "$("$awk_bin" 'BEGIN { printf "|%s|%d|%.2f|\n", "abc", 42, 3.14159 }')"

    rm -rf "$TMP_DIR/out"
    mkdir -p "$TMP_DIR/out"
    "$awk_bin" -F '\t' -v outdir="$TMP_DIR/out" 'NR > 1 { print $2, $4 > (outdir "/dept-" $3 ".txt") }' "$DATA_DIR/employees.tsv"
    check "per-department file" "Alice 120000" \
        "$(head -n 1 "$TMP_DIR/out/dept-Engineering.txt")"

    check "getline file count" "2" \
        "$("$awk_bin" 'BEGIN { while ((getline line < "examples/data/team-a.tsv") > 0) n++; close("examples/data/team-a.tsv"); print n }')"

    check "cmd getline count" "3" \
        "$("$awk_bin" 'BEGIN { while (("echo 1; echo 2; echo 3" | getline line) > 0) n++; close("echo 1; echo 2; echo 3"); print n }')"

    check "ARGV file" "examples/data/team-a.tsv" \
        "$("$awk_bin" 'BEGIN { print ARGV[1] }' examples/data/team-a.tsv)"

    check "system status" "3" \
        "$("$awk_bin" 'BEGIN { status = system("exit 3"); print status }')"

    check "FIELDWIDTHS" $'Alice,Engineering,120000\nBob,Sales,90000\nCarol,Engineering,135000' \
        "$("$awk_bin" 'BEGIN { FIELDWIDTHS = "8 12 *" } { for (i = 1; i <= NF; i++) gsub(/^ +| +$/, "", $i); printf "%s,%s,%s\n", $1, $2, $3 }' "$DATA_DIR/fixed-width.txt")"

    check "salary-sum script" "total=1167000" \
        "$("$awk_bin" -f "$SCRIPT_DATA_DIR/salary-sum.awk" "$DATA_DIR/employees.tsv")"

    check "dept-report header" $'dept\tcount\ttotal\tavg' \
        "$("$awk_bin" -f "$SCRIPT_DATA_DIR/dept-report.awk" "$DATA_DIR/employees.tsv" | head -n 1)"

    check "join missing sku" $'1006\tE-500\t4\tMISSING' \
        "$("$awk_bin" -f "$SCRIPT_DATA_DIR/join.awk" "$DATA_DIR/inventory.tsv" "$DATA_DIR/orders.tsv" | awk '$1 == 1006')"

    check "wordfreq top" $'the\t3' \
        "$("$awk_bin" -f "$SCRIPT_DATA_DIR/wordfreq.awk" "$DATA_DIR/poem.txt" | sort -k2,2nr -k1,1 | head -n 1)"

    if "$awk_bin" --csv 'BEGIN { exit 0 }' >/dev/null 2>&1; then
        check "csv mode" $'2 Alice Likes commas, semicolons, and quotes\n2 Bob Says "hello"\n2 Carol plain' \
            "$("$awk_bin" --csv 'NR > 1 { print NF, $1, $2 }' "$DATA_DIR/messy.csv")"
    else
        printf 'skip csv mode (gawk --csv 不可用)\n'
    fi

    if "$awk_bin" --posix 'BEGIN { gensub(/a/, "b", "g", "aaa") }' >/dev/null 2>&1; then
        fail "posix rejects gensub" "non-zero" "zero"
    else
        pass "posix rejects gensub"
    fi

    if "$awk_bin" 'BEGIN { printf "%s %d\n", "x" }' >/dev/null 2>&1; then
        fail "printf missing args" "non-zero" "zero"
    else
        pass "printf missing args"
    fi

    check "C byte length" "5" \
        "$(LC_ALL=C "$awk_bin" 'BEGIN { print length("café") }')"

    local utf8_locale=""
    local loc
    for loc in C.UTF-8 C.utf8 en_US.UTF-8; do
        if LC_ALL="$loc" "$awk_bin" 'BEGIN { exit (length("café") == 4 ? 0 : 1) }' >/dev/null 2>&1; then
            utf8_locale="$loc"
            break
        fi
    done
    if [[ -n "$utf8_locale" ]]; then
        check "UTF-8 length" "4 2" \
            "$(LC_ALL="$utf8_locale" "$awk_bin" 'BEGIN { print length("café"), length("北京") }')"
    else
        printf 'skip UTF-8 length (没有可用的 UTF-8 locale)\n'
    fi

    printf '\n通过 %d 项，失败 %d 项\n' "$PASS" "$FAIL"
    if [[ "$FAIL" -ne 0 ]]; then
        exit 1
    fi
}

main "$@"
