## 综合练习

这个练习模拟一次“运营周报”：销售、库存、日志和团队数据分散在几个文件里，需要用 awk 把它们整理成可读的结论。题目按能力递进，先做基础统计，再做连接和报表，最后写一个可复用的脚本。

### 场景与数据

你在一家小公司做运营分析，周五需要回答：

- 这周卖了多少钱，哪些地区和产品贡献最大？
- 订单里的商品库存够不够，有没有缺失的 SKU？
- 网站这周健康吗，错误率、Top IP 和 5xx 集中在哪些路径？
- 团队薪资结构大致如何？
- 能不能把这些结果做成一个固定格式的周报？

数据：

| 文件 | 内容 |
| --- | --- |
| `examples/data/sales.csv` | 日期、地区、产品、数量、单价 |
| `examples/data/orders.tsv` | 订单号、SKU、数量 |
| `examples/data/inventory.tsv` | SKU、名称、仓库、库存 |
| `examples/data/access.log` | Web 访问日志 |
| `examples/data/employees.tsv` | 员工、部门、薪资、城市 |

所有命令在仓库根目录执行，输出使用 `LC_ALL=C.UTF-8` 时保持一致。

### 销售总览

任务：

- 计算总销售额。
- 按地区汇总销售额和记录条数。
- 找出销售额最高的产品。

验收：

- 总销售额为 `4948.70`。
- 地区报表包含 East、North、South、West，金额之和等于总额。
- 最高产品是 Monitor，销售额 `2457.00`。

### 库存与订单

任务：

- 把 `orders.tsv` 的订单连接到 `inventory.tsv` 的库存。
- 输出每个订单的 SKU、数量和库存；缺失的 SKU 标记 `MISSING`。
- 统计订单总数量，以及缺失订单的数量。

验收：

- 8 条订单全部输出。
- `E-500` 标记为 `MISSING`，数量 4。
- 订单总数量为 38。

### 网站健康度

任务：

- 统计每个状态码的数量。
- 计算 4xx/5xx 的比例。
- 找出请求数最多的 IP。
- 统计 5xx 请求按路径的分布。

验收：

- 状态码计数与日志一致。
- 错误率为 `7/24 29.17%`。
- Top IP 是 `203.0.113.10`，7 次。
- 5xx 路径为 `/api/orders` 和 `/api/users`，各 2 次。

### 团队概览

任务：

- 按部门统计人数和平均薪资。
- 输出按部门名排序。

验收：

- Engineering 4 人，平均 123250.00。
- Marketing 2 人，平均 93500.00。
- Sales 3 人，平均 92333.33。
- Support 3 人，平均 70000.00。

### 可复用周报脚本

任务：

- 写一个 `sales-report.awk`，按地区输出固定宽度报表。
- 表头为 `REGION`、`REVENUE`、`LINES`。
- 金额保留两位小数，最后输出 `TOTAL` 行。
- 报告顺序按地区名升序。

验收：

```shell
gawk -f examples/scripts/sales-report.awk examples/data/sales.csv
```

输出：

```shell
REGION      REVENUE  LINES
East         817.20      4
North       1294.20      5
South       1542.90      5
West        1294.40      4
TOTAL       4948.70     18
```

### 数据校验

任务：

- 检查 `sales.csv` 每行是否有 5 个字段。
- 检查数量是否为非负整数。
- 检查单价是否为两位小数。
- 有错误时以非零退出码结束。

验收：

- 当前数据输出 `rows=18 bad=0`。
- 人为制造一行坏数据时，脚本能指出行号并以非零退出。

### 扩展挑战

- 把地区报表改成同时输出“每行平均销售额”。
- 用 `getline` 在 `BEGIN` 里读取库存，再用另一个 awk 程序处理订单。
- 把 5xx 路径统计和 Top IP 合并成一个日志摘要脚本。
- 用 `--csv` 处理 `messy.csv`，比较 `-F ','`、`FPAT` 和 `--csv` 的结果差异。
- 给周报脚本加 `-v month=2026-01`，只统计指定月份。

### 参考答案

#### 销售总览

```shell
$ awk -F ',' 'NR > 1 { total += $4 * $5 } END { printf "%.2f\n", total }' examples/data/sales.csv
4948.70

$ awk -F ',' '
NR > 1 { revenue[$2] += $4 * $5; lines[$2]++ }
END {
  PROCINFO["sorted_in"] = "@ind_str_asc"
  printf "%-8s %10s %6s\n", "REGION", "REVENUE", "LINES"
  for (r in revenue) printf "%-8s %10.2f %6d\n", r, revenue[r], lines[r]
}
' examples/data/sales.csv
REGION      REVENUE  LINES
East         817.20      4
North       1294.20      5
South       1542.90      5
West        1294.40      4

$ awk -F ',' 'NR > 1 { sum[$3] += $4 * $5 } END { for (p in sum) printf "%.2f\t%s\n", sum[p], p }' examples/data/sales.csv | sort -k1,1nr | head -n 1
2457.00 Monitor
```

`printf "%.2f"` 和 `sort` 的组合可以控制金额和顺序。地区报表用 `PROCINFO["sorted_in"]` 保持表头在数据之前；如果管道接 `sort`，表头会被排到中间。

#### 库存与订单

```shell
$ awk -F '\t' '
NR == FNR { if (FNR > 1) stock[$1] = $4; next }
FNR > 1 { print $1, $2, $3, ($2 in stock ? stock[$2] : "MISSING") }
' examples/data/inventory.tsv examples/data/orders.tsv
1001 A-100 3 42
1002 B-200 10 75
1003 C-300 1 12
1004 A-101 5 18
1005 B-200 2 75
1006 E-500 4 MISSING
1007 A-100 7 42
1008 D-400 6 55

$ awk -F '\t' 'FNR > 1 { qty += $3 } END { print qty }' examples/data/orders.tsv
38

$ awk -F '\t' '
NR == FNR { if (FNR > 1) stock[$1] = 1; next }
FNR > 1 && !($2 in stock) { print $2, $3; qty += $3 }
END { print "missing qty", qty }
' examples/data/inventory.tsv examples/data/orders.tsv
E-500 4
missing qty 4
```

`NR == FNR` 只对第一个文件成立；第一个文件建表，第二个文件查询。缺失 SKU 用 `!($2 in stock)` 判断，不要用 `!stock[$2]`，因为库存值可能是 0。

#### 网站健康度

```shell
$ awk '
{ status[$9]++; if ($9 >= 400) errors++; total++ }
END {
  PROCINFO["sorted_in"] = "@ind_num_asc"
  for (s in status) print s, status[s]
  printf "errors %d/%d %.2f%%\n", errors, total, errors * 100 / total
}
' examples/data/access.log
200 12
201 3
304 2
404 3
500 4
errors 7/24 29.17%

$ awk '{ count[$1]++ } END { for (ip in count) print count[ip], ip }' examples/data/access.log | sort -k1,1nr -k2,2 | head -n 1
7 203.0.113.10

$ awk '$9 >= 500 { count[$7]++ } END { for (p in count) print count[p], p }' examples/data/access.log | sort -k1,1nr -k2,2
2 /api/orders
2 /api/users
```

#### 团队概览

```shell
$ awk -F '\t' '
NR > 1 { count[$3]++; sum[$3] += $4 }
END {
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for (d in count) printf "%s\t%d\t%.2f\n", d, count[d], sum[d] / count[d]
}
' examples/data/employees.tsv
Engineering	4	123250.00
Marketing	2	93500.00
Sales	3	92333.33
Support	3	70000.00
```

#### 周报脚本

```awk
#!/usr/bin/env -S gawk -f
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
```

运行：

```shell
gawk -f examples/scripts/sales-report.awk examples/data/sales.csv
```

#### 数据校验

```shell
$ awk -F ',' '
NR > 1 {
  if (NF != 5) { print "bad fields", NR; bad++ }
  if ($4 !~ /^[0-9]+$/) { print "bad units", NR; bad++ }
  if ($5 !~ /^[0-9]+\.[0-9]{2}$/) { print "bad price", NR; bad++ }
}
END {
  printf "rows=%d bad=%d\n", NR - 1, bad + 0
  if (bad) exit 1
}
' examples/data/sales.csv
rows=18 bad=0
```

要测试失败路径，复制一份数据，插入一行坏数据：

```shell
cp examples/data/sales.csv /tmp/bad-sales.csv
printf '2026-01-14,North,Keyboard,-1,49.90\n' >> /tmp/bad-sales.csv
awk -F ',' '
NR > 1 {
  if (NF != 5) { print "bad fields", NR; bad++ }
  if ($4 !~ /^[0-9]+$/) { print "bad units", NR; bad++ }
  if ($5 !~ /^[0-9]+\.[0-9]{2}$/) { print "bad price", NR; bad++ }
}
END {
  printf "rows=%d bad=%d\n", NR - 1, bad + 0
  if (bad) exit 1
}
' /tmp/bad-sales.csv
```

实际脚本应该把文件路径作为参数，不要写死。

### 完成标准

- 每个任务都能从仓库根目录直接运行。
- 输出中的数字与验收标准一致。
- 连接和去重不会依赖数组遍历顺序。
- 报表有表头、对齐和总计。
- 校验脚本用退出码表达成功或失败。
- 能解释每个 `NR == FNR`、`in`、`PROCINFO` 的作用。

如果某一步失败，回到[排错与常见陷阱](troubleshooting.md)，用最小输入复现，再检查字段号、`FS`、表头和类型比较。
