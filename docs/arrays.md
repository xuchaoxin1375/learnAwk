## 关联数组

awk 只有一种数组：**关联数组**(associative array)。它用字符串键映射到值，不需要预先声明大小，也不能用数字下标按位置访问。这个设计非常适合计数、分组、查表和去重，是 awk 从“单行命令”变成“数据处理工具”的关键。

### 创建与访问

```awk
count["Engineering"] = 1
count["Sales"]++
print count["Engineering"]
```

数组元素在第一次赋值时创建。读取一个不存在的键不会报错，会得到空字符串/0：

```shell
$ awk 'BEGIN { print "[" a["missing"] "]"; print a["missing"] + 0 }'
[]
0
```

键可以是字符串、数字或变量：

```shell
$ awk -F '\t' 'NR > 1 { count[$3]++ } END { print count["Engineering"] }' examples/data/employees.tsv
4
```

`$3` 是部门名，作为键；`count[$3]++` 把该部门计数加一。

键在内部按字符串保存，所以数字 `1` 和字符串 `"1"` 是同一个键：

```shell
$ awk 'BEGIN { a[1] = "one"; a["1"] = "ONE"; print length(a), a[1] }'
1 ONE
```

第二次赋值覆盖了第一次。需要把数字和字符串当成不同键时，加前缀区分，例如 `"id:" id` 和 `"name:" name`。

### 判断键是否存在

不要用“值是否为真”判断键是否存在，因为值可能是 0 或空字符串：

```shell
$ awk 'BEGIN {
  a["x"] = 0
  if ("x" in a) print "exists"
  if (!("y" in a)) print "missing"
  if (!a["x"]) print "value false"
}'
exists
missing
value false
```

`"x" in a` 判断键是否存在；`!a["x"]` 判断的是值是否为假。两者含义不同。

删除键：

```shell
$ awk 'BEGIN {
  a["x"] = 1; a["y"] = 2
  print length(a)
  delete a["x"]
  print length(a)
  delete a
  print length(a)
}'
2
1
0
```

`delete a["x"]` 删除单个键；`delete a` 清空整个数组（GNU 扩展）。`length(a)` 返回数组元素个数，也是 GNU 扩展；POSIX awk 需要用循环计数。

### 遍历数组

`for (key in array)` 遍历所有键：

```shell
$ awk -F '\t' '
NR > 1 { count[$3]++ }
END {
  for (d in count) print d, count[d]
}
' examples/data/employees.tsv | sort
Engineering 4
Marketing 2
Sales 3
Support 3
```

去掉 `| sort` 后，输出的顺序可能不同。**`for (k in a)` 的遍历顺序是不确定的**，它可能按哈希顺序、插入顺序或实现相关的顺序输出，不能依赖。需要稳定顺序时，用下面三种方式之一：

- 管道交给 `sort`。
- GNU awk 设置 `PROCINFO["sorted_in"]`。
- GNU awk 用 `asort()`/`asorti()` 排序后按数组下标输出。

用 `sort` 最简单，也最可移植：

```shell
$ awk -F '\t' 'NR > 1 { count[$3]++ } END { for (d in count) print d, count[d] }' examples/data/employees.tsv | sort
Engineering 4
Marketing 2
Sales 3
Support 3
```

GNU awk 可以在 `END` 里设置 `PROCINFO["sorted_in"]`：

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

常用排序值：

| 值 | 含义 |
| --- | --- |
| `@ind_str_asc` | 按键的字符串升序 |
| `@ind_str_desc` | 按键的字符串降序 |
| `@ind_num_asc` | 按键的数值升序 |
| `@ind_num_desc` | 按键的数值降序 |
| `@val_str_asc` | 按值的字符串升序 |
| `@val_num_asc` | 按值的数值升序 |
| `@val_num_desc` | 按值的数值降序 |

`PROCINFO["sorted_in"]` 会影响之后所有的 `for (k in a)` 循环；设成空字符串可以恢复默认顺序：

```awk
PROCINFO["sorted_in"] = ""
```

这是 **GNU** 扩展，mawk 和 BSD awk 不支持。

### 计数与分组

最常见的模式是“一个键对应一个计数和一个累加值”：

```shell
$ awk -F '\t' '
NR > 1 {
  count[$3]++
  sum[$3] += $4
}
END {
  for (d in count) printf "%s %d %.2f\n", d, count[d], sum[d] / count[d]
}
' examples/data/employees.tsv | sort
Engineering 4 123250.00
Marketing 2 93500.00
Sales 3 92333.33
Support 3 70000.00
```

拆开看：

- `count[$3]++`：按部门计数。
- `sum[$3] += $4`：按部门累加薪资。
- `sum[d] / count[d]`：平均值。`count[d]` 一定是正数，因为 `d` 来自已经出现的键。

这种“键 + 多个聚合值”的写法可以用多个平行数组，也可以用多维数组或数组的数组。

### split：把字符串拆成数组

`split(string, array, separator)` 按分隔符拆分字符串，返回字段数：

```shell
$ awk 'BEGIN { n = split("2026-01-05", d, "-"); print n, d[1], d[2], d[3] }'
3 2026 01 05
```

`separator` 可以是字符串或正则。GNU awk 还支持第四个参数，把实际匹配到的分隔符存进另一个数组：

```shell
$ awk 'BEGIN { n = split("a,b;c", part, /[,;]/, sep); print n, part[2], sep[1], sep[2] }'
3 b , ;
```

`split` 在解析日期、路径、配置值时很常用。它把结果数组的下标从 1 开始编号，`part[0]` 通常不用。

### 多维键

awk 没有真正的多维数组，但可以用 `a[i, j]` 语法构造复合键。awk 会把 `i` 和 `j` 用 `SUBSEP` 连接成一个字符串作为键：

```shell
$ awk -F ',' '
NR > 1 { revenue[$2, $3] += $4 * $5 }
END {
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for (k in revenue) {
    split(k, p, SUBSEP)
    printf "%s\t%s\t%.2f\n", p[1], p[2], revenue[k]
  }
}
' examples/data/sales.csv
East	Keyboard	449.10
East	Monitor	189.00
East	Mouse	179.10
North	Keyboard	299.40
North	Monitor	756.00
North	Mouse	238.80
South	Keyboard	299.40
South	Monitor	945.00
South	Mouse	298.50
West	Keyboard	349.30
West	Monitor	567.00
West	Mouse	378.10
```

`$2` 是地区，`$3` 是产品，`revenue[$2, $3]` 按“地区 + 产品”聚合。遍历时用 `split(k, p, SUBSEP)` 把复合键拆回两部分。

`SUBSEP` 默认是一个不可打印的控制字符（八进制 034）。如果键本身可能包含这个字符，需要换一个不会冲突的分隔符，或者改用数组的数组。

GNU awk 支持真正的数组的数组：

```shell
$ awk -F ',' '
NR > 1 { revenue[$2][$3] += $4 * $5 }
END {
  PROCINFO["sorted_in"] = "@ind_str_asc"
  for (r in revenue)
    for (p in revenue[r])
      printf "%s\t%s\t%.2f\n", r, p, revenue[r][p]
}
' examples/data/sales.csv | head -n 8
East	Keyboard	449.10
East	Monitor	189.00
East	Mouse	179.10
North	Keyboard	299.40
North	Monitor	756.00
North	Mouse	238.80
South	Keyboard	299.40
South	Monitor	945.00
```

`revenue[$2][$3]` 比 `revenue[$2, $3]` 更直观，但它是 **GNU** 扩展，旧版 awk 不支持。

### 去重

“第一次出现时打印”是 awk 的经典技巧：

```shell
$ printf 'a\nb\na\nc\nb\n' | awk '!seen[$0]++'
a
b
c
```

拆解 `!seen[$0]++`：

- `seen[$0]` 第一次读取时是 0。
- `!0` 为真，执行默认动作 `print $0`。
- 后缀 `++` 把 `seen[$0]` 增加到 1。
- 第二次遇到相同的行，`seen[$0]` 是 1，`!1` 为假，不打印。

这个模式保留**第一次出现**的顺序；如果要保留最后一次，需要反向读取或记录行号。

### 排序数组

GNU awk 的 `asort()` 按值排序，`asorti()` 按键排序：

```shell
$ awk -F '\t' '
NR > 1 { sum[$3] += $4 }
END {
  n = asorti(sum, sorted)
  for (i = 1; i <= n; i++) printf "%s\t%d\n", sorted[i], sum[sorted[i]]
}
' examples/data/employees.tsv
Engineering	493000
Marketing	187000
Sales	277000
Support	210000
```

`asorti(sum, sorted)` 把 `sum` 的键按字符串升序放进 `sorted`，返回元素个数。`asort(sum, sorted)` 则按值排序：

```shell
$ awk 'BEGIN { a["x"] = 3; a["y"] = 1; a["z"] = 2; n = asort(a); for (i = 1; i <= n; i++) print i, a[i] }'
1 1
2 2
3 3
```

`asort` 会把排序后的值放进下标 1 到 n，原来的键丢失。需要同时保留键和值时用 `asorti`。

`asort`/`asorti` 是 **GNU** 扩展。POSIX awk 需要把键或值写到临时文件，再用 `sort` 处理。

### 数组与函数

数组作为函数参数时按引用传递：

```awk
function add_count(arr, key) {
    arr[key]++
}
```

调用 `add_count(count, "Sales")` 会修改外部的 `count`。标量参数按值传递，修改不会回传。这是 awk 函数参数的一个重要区别，写工具函数时要记住。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 输出顺序每次不同 | `for (k in a)` 顺序未定义 | 用 `sort`、`PROCINFO["sorted_in"]` 或 `asorti` |
| 键存在但判断失败 | 用 `if (a[k])` 判断存在性，值为 0/空 | 用 `if (k in a)` |
| 数字键和字符串键被当成同一个键 | 数组下标会转成字符串，`a[1]` 与 `a["1"]` 相同 | 加前缀区分，或统一用字符串键 |
| 多维键拆不开 | 键里包含 `SUBSEP` | 换分隔符，或改用数组的数组 |
| `delete a` 报错 | 用了 POSIX awk | 逐个 `delete a[k]`，或确认是 GNU awk |
| `length(a)` 报错 | POSIX awk 不支持数组长度 | 用循环计数 |
| 去重后顺序变了 | `for (k in a)` 输出，不是原输入顺序 | 遍历原输入，用 `seen` 判断 |

### 小结

- awk 的数组是关联数组，键是字符串，值可以是字符串或数字。
- 用 `key in array` 判断存在性，用 `delete` 删除。
- `for (k in a)` 顺序不确定；需要稳定顺序时用 `sort`、`PROCINFO` 或 `asorti`。
- `split()` 把字符串拆成数组，常用于日期、路径和配置。
- `a[i, j]` 用 `SUBSEP` 构造复合键，GNU awk 支持 `a[i][j]`。
- `!seen[$0]++` 是保留首次出现顺序的去重模式。
- 数组传参按引用，标量传参按值。

### 练习

- 统计 `examples/data/access.log` 中每个状态码的数量，按状态码升序输出。
- 统计每个 IP 的请求数，按请求数降序输出前 3 名。
- 用 `split()` 从 `examples/data/sales.csv` 的日期中提取月份，统计每月销售额。
- 用多维数组统计每个地区、每个产品的销售额。
- 用 `!seen[$0]++` 对 `examples/data/poem.txt` 去重（按整行）。
- 用 `asorti()` 按部门薪资总和排序，输出部门名和总和。

<details>
<summary>参考答案</summary>

状态码统计：

```shell
awk '{ count[$9]++ } END { PROCINFO["sorted_in"] = "@ind_num_asc"; for (s in count) print s, count[s] }' examples/data/access.log
```

Top IP：

```shell
awk '{ count[$1]++ } END { for (ip in count) print ip, count[ip] }' examples/data/access.log | sort -k2,2nr -k1,1 | head -n 3
```

月份销售额：

```shell
awk -F ',' 'NR > 1 { split($1, d, "-"); sum[d[1] "-" d[2]] += $4 * $5 } END { for (m in sum) printf "%s\t%.2f\n", m, sum[m] }' examples/data/sales.csv | sort
```

地区 × 产品：

```shell
awk -F ',' 'NR > 1 { revenue[$2, $3] += $4 * $5 } END { for (k in revenue) { split(k, p, SUBSEP); printf "%s\t%s\t%.2f\n", p[1], p[2], revenue[k] } }' examples/data/sales.csv | sort
```

整行去重：

```shell
awk '!seen[$0]++' examples/data/poem.txt
```

按部门总和排序：

```shell
awk -F '\t' 'NR > 1 { sum[$3] += $4 } END { n = asorti(sum, sorted); for (i = 1; i <= n; i++) printf "%s\t%d\n", sorted[i], sum[sorted[i]] }' examples/data/employees.tsv
```

</details>
