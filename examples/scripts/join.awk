#!/usr/bin/env -S gawk -f
# 把 inventory.tsv 的库存数量连接到 orders.tsv。
# 用法: gawk -f examples/scripts/join.awk examples/data/inventory.tsv examples/data/orders.tsv

BEGIN { FS = OFS = "\t" }

NR == FNR {
    if (FNR > 1) stock[$1] = $4
    next
}

FNR > 1 {
    stock_qty = ($2 in stock) ? stock[$2] : "MISSING"
    print $1, $2, $3, stock_qty
}
