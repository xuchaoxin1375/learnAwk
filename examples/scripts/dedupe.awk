#!/usr/bin/env -S gawk -f
# 按整行去重，保留第一次出现的顺序。
# 用法: gawk -f examples/scripts/dedupe.awk examples/data/poem.txt

!seen[$0]++
