## 格式化输出

`print` 适合快速输出，`printf` 适合**可控格式**：对齐的表格、固定小数位、补零编号、CSV 行、写入多个文件。这一篇讲 `printf` 的格式串、输出重定向和文件句柄，最后用一个小报表把内容串起来。

### print 与 printf

```awk
print $1, $2          # 逗号用 OFS 连接，末尾加 ORS
printf "%s %s\n", $1, $2   # 完全按格式串输出
```

区别：

- `print` 自动使用 `OFS` 和 `ORS`，`printf` 不使用，换行要自己写 `\n`。
- `print` 的数字输出受 `OFMT` 影响，`printf` 由格式串决定。
- `printf` 不自动加空格或换行，格式串写什么就输出什么。
- `printf` 的参数不够会报错，`print` 没有这个问题。

```shell
$ awk 'BEGIN { printf "a"; printf "b\n" }'
ab
```

### 格式转换

| 转换 | 含义 | 例子 | 输出 |
| --- | --- | --- | --- |
| `%s` | 字符串 | `printf "%s", "abc"` | `abc` |
| `%d`、`%i` | 十进制整数 | `printf "%d", 42` | `42` |
| `%f` | 定点小数 | `printf "%f", 3.14159` | `3.141590` |
| `%e`、`%E` | 科学计数法 | `printf "%e", 31415.9` | `3.141590e+04` |
| `%g`、`%G` | 自动选择 `%f` 或 `%e` | `printf "%g", 0.000123` | `0.000123` |
| `%x`、`%X` | 十六进制 | `printf "%x", 255` | `ff` |
| `%o` | 八进制 | `printf "%o", 8` | `10` |
| `%c` | 字符 | `printf "%c", 65` | `A` |
| `%%` | 字面百分号 | `printf "100%%"` | `100%` |

```shell
$ awk 'BEGIN {
  printf "|%s|%d|%f|%e|%g|%x|%o|%c|%%|\n", "abc", 42, 3.14159, 31415.9, 0.000123, 255, 8, 65
}'
|abc|42|3.141590|3.141590e+04|0.000123|ff|10|A|%|
```

`%c` 传数字时按字符编码输出；传字符串时输出第一个字符。

### 宽度、精度与标志

格式串可以在 `%` 和转换字符之间加宽度、精度和标志：

```shell
$ awk 'BEGIN {
  printf "|%10s|%-10s|%05d|%+d|% .2f|%10.2f|%.3s|\n", "right", "left", 42, 42, 3.14159, 3.14159, "abcdef"
}'
|     right|left      |00042|+42| 3.14|      3.14|abc|
```

- `%10s`：右对齐，宽度 10。
- `%-10s`：左对齐，宽度 10。
- `%05d`：宽度 5，左边补零。
- `%+d`：正数显示 `+`。
- `% .2f`：正数前留空格，保留 2 位小数。
- `%10.2f`：总宽度 10，保留 2 位小数。
- `%.3s`：只取字符串前 3 个字符。

宽度和精度可以用 `*` 动态传入：

```shell
$ awk 'BEGIN { printf "|%*.*f|\n", 10, 2, 3.14159 }'
|      3.14|
```

两个 `*` 依次从参数里取宽度 10 和精度 2。

### printf 的参数

`printf` 是语句，没有可用的返回值；需要生成字符串时用 `sprintf`。格式串里的转换数量必须和参数数量匹配：

```shell
$ awk 'BEGIN { printf "%s %d %.2f\n", "x" }'
awk: cmd. line:1: fatal: not enough arguments to satisfy format string
...
```

参数多余时，多余的会被忽略；参数不足时，GNU awk 直接报错。写报表时先用固定字段数验证。

### 输出到文件

`print` 和 `printf` 都支持重定向：

```awk
print $0 > "out/report.txt"      # 创建或截断
print $0 >> "out/report.txt"     # 追加
print $0 | "sort"                # 管道
```

`>` 在 awk 里不是 shell 的覆盖重定向，而是“把这条输出写到文件”。第一次打开时截断，之后保持打开并追加。`>>` 显式追加。

按部门写不同文件：

```shell
$ mkdir -p out
$ awk -F '\t' 'NR > 1 { print $2, $4 > ("out/dept-" $3 ".txt") }' examples/data/employees.tsv
$ ls out | sort
dept-Engineering.txt
dept-Marketing.txt
dept-Sales.txt
dept-Support.txt
$ head -n 2 out/dept-Engineering.txt
Alice 120000
Carol 135000
```

文件名是表达式时，**必须加括号**：

```awk
print $2 > ("out/dept-" $3 ".txt")
```

写成 `print $2 > "out/dept-" $3 ".txt"` 会产生歧义，awk 可能把 `>` 解释成比较，而不是重定向。

### close 与文件句柄

awk 会记住打开的文件和管道，直到程序结束或显式 `close()`：

```awk
close("out/dept-Sales.txt")
close("sort")
```

需要 `close` 的典型场景：

- 同一个文件名要重新读取或重新写入。
- 循环里打开大量文件，避免句柄耗尽。
- 管道写入后要等待命令结束、拿到完整输出。
- 需要在程序结束前确保数据落盘。

`fflush()` 刷新缓冲区，但不关闭文件：

```awk
fflush("out/report.txt")
```

### 管道输出

```shell
$ awk -F '\t' 'NR > 1 { print $2, $4 | "sort -k2,2nr" }' examples/data/employees.tsv | head -n 3
Carol 135000
Lisa 128000
Alice 120000
```

awk 把 `print` 的结果写进 `sort` 的标准输入，`sort` 的输出回到终端。注意管道里的 `sort` 是 awk 启动的子进程，不是 shell 的管道；`close("sort")` 会关闭它并等待结束。

如果管道命令失败，awk 不一定能立刻发现。需要严格检查时，用 `getline` 或 `system()` 并检查返回值，见[getline 与输入输出](getline-io.md)。

### 固定宽度报表

把字段对齐：

```shell
$ awk -F '\t' '
BEGIN { printf "%-8s %-12s %10s\n", "NAME", "DEPT", "SALARY" }
NR > 1 { printf "%-8s %-12s %10d\n", $2, $3, $4 }
' examples/data/employees.tsv | head -n 6
NAME     DEPT             SALARY
Alice    Engineering      120000
Bob      Sales             90000
Carol    Engineering      135000
Dave     Support           70000
Eve      Sales             95000
```

- `%-8s` 左对齐姓名，宽度 8。
- `%-12s` 左对齐部门，宽度 12。
- `%10d` 右对齐薪资，宽度 10。

表头和数据使用同一组宽度，列才能对齐。姓名超过 8 个字符时列会错位；需要处理长文本时，先截断或动态计算宽度。

### CSV 与 TSV 输出

简单 CSV 可以直接用逗号拼接：

```shell
$ awk -F '\t' 'NR > 1 { printf "%s,%s,%d\n", $2, $3, $4 }' examples/data/employees.tsv | head -n 3
Alice,Engineering,120000
Bob,Sales,90000
Carol,Engineering,135000
```

如果字段本身含逗号、引号或换行，需要按 CSV 规则转义。awk 没有内置的 CSV 编码函数；字段简单时手动处理，复杂时用 Python 的 `csv` 模块。GNU awk 5.3 的 `--csv` 负责**解析**，不负责**生成**时的全部转义。

TSV 输出用制表符：

```shell
awk -F '\t' 'BEGIN { OFS = "\t" } { print $2, $3 }' examples/data/employees.tsv
```

### 输出到标准错误

需要把诊断信息和数据分开时，可以写到标准错误。GNU awk 和大多数 Unix awk 支持：

```awk
print "warning: bad row " NR > "/dev/stderr"
```

这个写法依赖 `/dev/stderr`，Windows 原生环境不一定有。跨平台脚本可以把错误信息写到单独的文件，或通过管道交给 `cat 1>&2`：

```awk
print "warning: bad row " NR | "cat 1>&2"
```

管道方式依赖 shell，仍然不是纯 awk 方案。教学示例默认输出到标准输出；需要严格区分流时，优先在 shell 层重定向。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 输出全部粘在一起 | `printf` 不会自动换行 | 格式串末尾加 `\n` |
| 文件被覆盖 | 用了 `>`，而且每次运行都重新打开 | 用 `>>`，或在程序内控制打开次数 |
| 文件名变成比较表达式 | `>` 后是拼接表达式，没加括号 | 写 `> ("out/" $3 ".txt")` |
| 管道没有输出 | 没有 `close`，命令还没结束 | 在 `END` 或写完时 `close("sort")` |
| 打开太多文件 | 循环里为每行打开新文件，没关闭 | 在循环里 `close`，或减少文件数 |
| `%d` 输出小数 | 格式和值类型不匹配 | 用 `%f` 或先 `int()` |
| 百分号报错 | 格式串里写了裸 `%` | 写 `%%` |
| 表头和数据不对齐 | 宽度不一致或字符串超宽 | 统一宽度，必要时截断 |

### 小结

- `print` 用 `OFS`/`ORS`，`printf` 完全按格式串。
- `%s`、`%d`、`%f`、`%e`、`%g`、`%x`、`%o`、`%c`、`%%` 是最常用的转换。
- 宽度、精度和 `-`、`0`、`+` 标志控制对齐和填充。
- `>` 创建/截断，`>>` 追加，`|` 写管道；文件名表达式要加括号。
- `close()` 关闭文件和管道，`fflush()` 只刷新缓冲。
- 报表用固定宽度；CSV 生成要注意字段转义。
- 诊断信息尽量走标准错误，数据走标准输出。

### 练习

- 用 `printf` 输出一个三列报表：姓名、部门、薪资，姓名左对齐 8 位，部门左对齐 12 位，薪资右对齐 10 位。
- 把 `examples/data/employees.tsv` 按部门写到 `out/` 下的不同文件，每个文件一行一个员工。
- 用 `printf` 生成 5 个文件名 `report-001.csv` 到 `report-005.csv`。
- 把 `examples/data/sales.csv` 的每行格式化成 `地区: 产品 数量 x 单价`。
- 用管道把薪资从高到低排序，并只取前 3 行。
- 解释 `print > "out.txt"` 和 `print >> "out.txt"` 的区别，以及为什么文件名表达式要加括号。

<details>
<summary>参考答案</summary>

三列报表：

```shell
awk -F '\t' 'BEGIN { printf "%-8s %-12s %10s\n", "NAME", "DEPT", "SALARY" } NR > 1 { printf "%-8s %-12s %10d\n", $2, $3, $4 }' examples/data/employees.tsv
```

按部门写文件：

```shell
mkdir -p out
awk -F '\t' 'NR > 1 { print $2, $4 > ("out/dept-" $3 ".txt") }' examples/data/employees.tsv
```

生成文件名：

```shell
awk 'BEGIN { for (i = 1; i <= 5; i++) printf "report-%03d.csv\n", i }'
```

销售行：

```shell
awk -F ',' 'NR > 1 { printf "%s: %s %d x %.2f\n", $2, $3, $4, $5 }' examples/data/sales.csv
```

排序取前三：

```shell
awk -F '\t' 'NR > 1 { print $2, $4 | "sort -k2,2nr" }' examples/data/employees.tsv | head -n 3
```

`>` 第一次打开时截断，之后写入同一文件；`>>` 追加。文件名是拼接表达式时，不加括号会让 `>` 的解析产生歧义，可能被当成比较运算符。

</details>
