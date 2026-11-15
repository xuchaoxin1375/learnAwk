#!/usr/bin/env -S gawk -f
# 按地区汇总销售额，输出固定宽度报表。
# 用法: gawk -f examples/scripts/sales-report.awk examples/data/sales.csv

BEGIN { FS = "," }

function money(value) {
    return sprintf("%.2f", value)
}

NR == 1 { next }

{
    revenue[$2] += $4 * $5
    lines[$2]++
    total += $4 * $5
}

END {
    PROCINFO["sorted_in"] = "@ind_str_asc"
    printf "%-8s %10s %6s\n", "REGION", "REVENUE", "LINES"
    for (region in revenue) {
        printf "%-8s %10s %6d\n", region, money(revenue[region]), lines[region]
    }
    printf "%-8s %10s %6d\n", "TOTAL", money(total), NR - 1
}
