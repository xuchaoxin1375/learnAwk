#!/usr/bin/env -S gawk -f
# 按部门统计人数、薪资总和与平均薪资。
# 用法: gawk -f examples/scripts/dept-report.awk examples/data/employees.tsv

BEGIN {
    FS = "\t"
    OFS = "\t"
    print "dept", "count", "total", "avg"
}

NR == 1 { next }

{
    count[$3]++
    sum[$3] += $4
}

END {
    PROCINFO["sorted_in"] = "@ind_str_asc"
    for (dept in count) {
        printf "%s\t%d\t%d\t%.2f\n", dept, count[dept], sum[dept], sum[dept] / count[dept]
    }
}
