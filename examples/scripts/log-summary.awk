#!/usr/bin/env -S gawk -f
# 汇总 access.log 的状态码数量、字节数和总请求数。
# 用法: gawk -f examples/scripts/log-summary.awk examples/data/access.log

{
    status[$9]++
    bytes[$9] += $10
    total++
    total_bytes += $10
}

END {
    PROCINFO["sorted_in"] = "@ind_num_asc"
    print "status", "count", "bytes"
    for (code in status) {
        printf "%s\t%d\t%d\n", code, status[code], bytes[code]
    }
    printf "total\t%d\t%d\n", total, total_bytes
}
