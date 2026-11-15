#!/usr/bin/env -S gawk -f
# 计算 employees.tsv 的薪资总和。
# 用法: gawk -f examples/scripts/salary-sum.awk examples/data/employees.tsv

BEGIN { FS = "\t" }

NR == 1 { next }

{ total += $4 }

END { printf "total=%d\n", total }
