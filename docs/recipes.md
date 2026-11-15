## 实战案例

这一篇把前面的语法放进真实任务：日志、销售、连接、去重、报表和数据校验。每个案例都可以单独运行，命令默认在仓库根目录执行。先看问题和输出，再看解释；需要改数据时，复制一份再改，不要直接覆盖 `examples/data/`。

### 日志状态码与错误率

数据：`examples/data/access.log`，常见日志格式，`$9` 是状态码。

按状态码计数：

```shell
$ awk '{ count[$9]++ } END { for (s in count) print s, count[s] }' examples/data/access.log | sort -n
200 12
201 3
304 2
404 3
500 4
```

计算 4xx/5xx 的比例：

```shell
$ awk '
{ total++; if ($9 >= 400) errors++ }
END { printf "%d/%d %.2f%%\n", errors, total, errors * 100 / total }
' examples/data/access.log
7/24 29.17%
```

`total` 统计所有请求，`errors` 统计状态码大于等于 400 的请求。`%.2f%%` 里的 `%%` 输出一个字面百分号。

变体：

- 只看 5xx：`$9 >= 500`。
- 按小时统计：需要先从 `$4` 提取小时，日志格式变化时要改字段号。
- 排除静态资源：`$7 !~ /\.(css|js|png)$/`。

### Top IP

```shell
$ awk '{ count[$1]++ } END { for (ip in count) print count[ip], ip }' examples/data/access.log | sort -k1,1nr -k2,2 | head -n 3
7 203.0.113.10
6 192.0.2.55
6 198.51.100.24
```

先把计数和 IP 一起打印，再用 `sort` 按计数降序、IP 升序排列。**不要依赖 `for (ip in count)` 的顺序**，它不保证按计数排序。

如果只想看大于 5 次的 IP：

```shell
awk '{ count[$1]++ } END { for (ip in count) if (count[ip] > 5) print count[ip], ip }' examples/data/access.log | sort -k1,1nr
```

### 5xx 请求集中在哪些路径

```shell
$ awk '$9 >= 500 { count[$7]++ } END { for (p in count) print count[p], p }' examples/data/access.log | sort -k1,1nr -k2,2
2 /api/orders
2 /api/users
```

`$7` 是请求路径。这个结果说明 5xx 集中在订单和用户接口，下一步应该查这两个接口的错误日志，而不是继续看静态资源。

### 按地区统计销售额

数据：`examples/data/sales.csv`，字段是日期、地区、产品、数量、单价。

```shell
$ awk -F ',' 'NR > 1 { sum[$2] += $4 * $5 } END { for (r in sum) printf "%s\t%.2f\n", r, sum[r] }' examples/data/sales.csv | sort
East	817.20
North	1294.20
South	1542.90
West	1294.40
```

`NR > 1` 跳过表头，`$4 * $5` 是每行销售额，`sum[$2]` 按地区累加。输出用 `printf` 固定两位小数，再交给 `sort` 保证顺序。

按产品统计：

```shell
$ awk -F ',' 'NR > 1 { sum[$3] += $4 * $5 } END { for (p in sum) printf "%.2f\t%s\n", sum[p], p }' examples/data/sales.csv | sort -k1,1nr | head -n 3
2457.00	Monitor
1397.20	Keyboard
1094.50	Mouse
```

这里把金额放在第一列，方便 `sort -k1,1nr` 按金额降序。

### 按月汇总

```shell
$ awk -F ',' '
NR > 1 {
  split($1, d, "-")
  month = d[1] "-" d[2]
  sum[month] += $4 * $5
}
END { for (m in sum) printf "%s\t%.2f\n", m, sum[m] }
' examples/data/sales.csv | sort
2026-01	4948.70
```

`split($1, d, "-")` 把 `2026-01-05` 拆成 `2026`、`01`、`05`，再用前两段拼出月份。数据只有一个月，所以只有一行；换成多个月的数据，模式不用改。

### 连接库存与订单

数据：

- `examples/data/inventory.tsv`：`sku`、`name`、`warehouse`、`stock`。
- `examples/data/orders.tsv`：`order_id`、`sku`、`qty`。

```shell
$ awk -F '\t' '
NR == FNR {
  if (FNR > 1) stock[$1] = $4
  next
}
FNR > 1 {
  print $1, $2, $3, ($2 in stock ? stock[$2] : "MISSING")
}
' examples/data/inventory.tsv examples/data/orders.tsv
1001 A-100 3 42
1002 B-200 10 75
1003 C-300 1 12
1004 A-101 5 18
1005 B-200 2 75
1006 E-500 4 MISSING
1007 A-100 7 42
1008 D-400 6 55
```

关键点：

- `NR == FNR` 表示“还在读第一个文件”。第一个文件是库存，先把 `sku -> stock` 存进数组，然后 `next` 跳过后续规则。
- 第二个文件是订单，`FNR > 1` 跳过表头，`$2 in stock` 判断 SKU 是否存在。
- `E-500` 不在库存里，输出 `MISSING`，这是左连接的行为。

如果两个文件的顺序反了，`NR == FNR` 仍然按第一个文件建表，结果会错。**连接脚本必须在注释或用法里写清文件顺序**。

### 去重并保留顺序

```shell
$ awk '!seen[$1]++ { print $1 }' examples/data/access.log
203.0.113.10
198.51.100.24
192.0.2.55
203.0.113.77
```

`!seen[$1]++` 只打印第一次出现的 IP，保留输入顺序。整行去重把 `$1` 换成 `$0`：

```shell
awk '!seen[$0]++' examples/data/poem.txt
```

需要统计每个重复项出现次数时，用 `count[$1]++`，不要用 `!seen`。

### 词频统计

```shell
$ awk '
{
  for (i = 1; i <= NF; i++) {
    w = tolower($i)
    gsub(/[^a-z0-9]/, "", w)
    if (w != "") freq[w]++
  }
}
END { for (w in freq) print freq[w], w }
' examples/data/poem.txt | sort -k1,1nr -k2,2 | head -n 5
3 the
2 five
2 jump
2 my
2 quick
```

这个命令做了三件事：

- `tolower` 统一大小写。
- `gsub(/[^a-z0-9]/, "", w)` 去掉标点，只保留字母和数字。
- `freq[w]++` 统计词频。

这里去掉了单引号，所以 `don't` 会变成 `dont`。需要保留缩写时，在 `.awk` 文件里写 `[^A-Za-z0-9']`，避免 shell 引号嵌套；**词频统计依赖分词规则**，中文、连字符、缩写需要不同的正则。

### 解析带引号的 CSV

GNU awk 5.3 的 `--csv` 可以直接解析：

```shell
$ gawk --csv 'NR > 1 { print NF, $1, $2 }' examples/data/messy.csv
2 Alice Likes commas, semicolons, and quotes
2 Bob Says "hello"
2 Carol plain
```

`--csv` 会去掉外层引号，并处理双引号转义。它不会验证列数、类型或编码，复杂 CSV 仍然建议用 Python 的 `csv` 模块。

如果只是简单 CSV（字段里没有逗号和引号），用 `-F ','` 就够：

```shell
awk -F ',' 'NR > 1 { print $1, $3 }' examples/data/sales.csv
```

不要用 `-F ','` 处理 `messy.csv`：第二行会被拆成 4 个字段，而不是 2 个。

### 固定宽度转 CSV

`examples/data/fixed-width.txt` 的列按位置对齐：

```shell
$ awk 'BEGIN { FIELDWIDTHS = "8 12 *" } {
  for (i = 1; i <= NF; i++) gsub(/^ +| +$/, "", $i)
  printf "%s,%s,%s\n", $1, $2, $3
}' examples/data/fixed-width.txt
Alice,Engineering,120000
Bob,Sales,90000
Carol,Engineering,135000
```

`FIELDWIDTHS` 按字符位置切分，字段里会保留填充空格，所以先用 `gsub` 去掉两端空格。固定宽度格式变化时，宽度值也要跟着改。

### 配置转环境变量

把简单 INI 转成 `KEY=VALUE`：

```shell
$ awk '
BEGIN {
  while ((getline line < "examples/data/config.ini") > 0) {
    if (line ~ /^[[:space:]]*[;#]/ || line ~ /^[[:space:]]*$/) continue
    if (line ~ /^\[/) {
      section = line
      gsub(/^\[|\]$/, "", section)
      continue
    }
    split(line, kv, "=")
    key = kv[1]; val = kv[2]
    gsub(/^[ \t]+|[ \t]+$/, "", key)
    gsub(/^[ \t]+|[ \t]+$/, "", val)
    printf "%s_%s=%s\n", toupper(section), toupper(key), val
  }
  close("examples/data/config.ini")
}
'
SERVER_HOST=127.0.0.1
SERVER_PORT=8080
CLIENT_RETRIES=3
CLIENT_TIMEOUT=30
```

这个输出可以交给 `source` 或 `env` 使用，但要先确认值里没有空格、引号和 shell 元字符。**不要直接 `eval` 未经验证的配置**。

### 校验数据质量

检查每行的字段数、数量是否为整数、单价格式是否正确：

```shell
$ awk -F ',' '
NR > 1 {
  if (NF != 5) { print "bad fields", NR; bad++ }
  if ($4 !~ /^[0-9]+$/) { print "bad units", NR; bad++ }
  if ($5 !~ /^[0-9]+\.[0-9]{2}$/) { print "bad price", NR; bad++ }
}
END { printf "rows=%d bad=%d\n", NR - 1, bad + 0 }
' examples/data/sales.csv
rows=18 bad=0
```

`bad + 0` 把未初始化的 `bad` 变成 0，保证没有错误时也能打印数字。校验脚本应该返回非零退出码，方便 CI 判断：

```awk
END { if (bad) exit 1 }
```

awk 的 `exit 1` 会设置进程退出码，`END` 仍会执行；把汇总打印放在 `exit` 之前。

### 选择正确的工具

这些案例展示了 awk 的强项：**逐行、按字段、聚合、轻量报表**。遇到下面情况，停下来换工具：

- CSV 有复杂引号、换行、编码：Python `csv`。
- JSON/YAML/XML：`jq`、`yq` 或 Python。
- 需要连接多个大文件、排序后归并：数据库或 `sort` + `join`。
- 需要复杂状态机、错误重试、日志级别：Python/Go。
- 需要长期维护和单元测试：通用语言更合适。

### 小结

- 日志统计的核心是“字段号 + 关联数组 + `sort`”。
- 连接两个文件用 `NR == FNR` 建表，用 `in` 判断键是否存在。
- 去重用 `!seen[$0]++`，保留首次出现顺序。
- 词频要明确分词和大小写规则。
- CSV 解析优先 `--csv` 或 Python，不要用 `-F ','` 硬拆带引号的数据。
- 数据校验要检查字段数、类型和边界，并用退出码表达结果。
- 报表输出用 `printf` 固定宽度和小数位。

### 练习

- 统计 `access.log` 中每个路径的请求数，输出前 5 名。
- 统计 `sales.csv` 中每个地区的平均订单金额。
- 用 `join.awk` 找出订单中缺失的 SKU，并计算缺失订单的总数量。
- 把 `employees.tsv` 转成 JSON Lines，每行一个对象（注意字符串转义）。
- 写一个校验脚本，检查 `employees.tsv` 的 `id` 是否唯一、薪资是否为正整数。
- 解释为什么 `awk -F ','` 不适合直接解析 `messy.csv`。

<details>
<summary>参考答案</summary>

路径请求数：

```shell
awk '{ count[$7]++ } END { for (p in count) print count[p], p }' examples/data/access.log | sort -k1,1nr -k2,2 | head -n 5
```

地区平均订单金额：

```shell
awk -F ',' 'NR > 1 { sum[$2] += $4 * $5; n[$2]++ } END { for (r in sum) printf "%s\t%.2f\n", r, sum[r] / n[r] }' examples/data/sales.csv | sort
```

缺失 SKU 总数量：

```shell
awk -F '\t' 'NR == FNR { if (FNR > 1) stock[$1] = 1; next } FNR > 1 && !($2 in stock) { qty += $3; print $2, $3 } END { print "missing qty", qty }' examples/data/inventory.tsv examples/data/orders.tsv
```

JSON Lines 需要转义引号和反斜杠；简单字段可以：

```shell
awk -F '\t' 'NR > 1 { printf "{\"id\":%d,\"name\":\"%s\",\"dept\":\"%s\",\"salary\":%d}\n", $1, $2, $3, $4 }' examples/data/employees.tsv
```

真实数据要先处理 `"`、`\` 和控制字符，复杂场景用 Python。

唯一性和薪资校验：

```shell
awk -F '\t' 'NR > 1 { if (seen[$1]++) { print "duplicate id", $1; bad++ } if ($4 !~ /^[0-9]+$/ || $4 <= 0) { print "bad salary", $1; bad++ } } END { print "bad", bad + 0 }' examples/data/employees.tsv
```

`messy.csv` 的字段里有逗号，`-F ','` 会把一个字段拆成多个；`--csv` 才知道引号内的逗号不是分隔符。

</details>
