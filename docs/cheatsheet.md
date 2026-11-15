## 速查表

这一页是学完后的查阅入口，不替代教程正文。语法和行为细节见对应章节。

### 调用形式

```shell
awk 'program' file...
awk -F '\t' 'program' file...
awk -v limit=100 'program' file...
awk -f script.awk file...
printf '...' | awk 'program'
```

| 选项 | 作用 |
| --- | --- |
| `-F sep` | 设置 `FS` |
| `-v var=value` | 在 `BEGIN` 前设置变量 |
| `-f file` | 从文件读取程序，可重复 |
| `--` | 结束选项，后面的 `-` 开头参数当文件名 |
| `--posix` | 关闭 GNU 扩展 |
| `--lint` | 可疑写法警告 |
| `--csv` | CSV 模式（gawk 5.3+） |
| `-b` | 按字节处理（gawk） |

### 程序结构

```awk
BEGIN { ... }                 # 读输入前
pattern { action }            # 每条匹配记录
pattern                        # 匹配时打印 $0
{ action }                     # 每条记录
END { ... }                    # 所有记录后
function name(args) { ... }    # 函数
```

### 模式

| 模式 | 含义 |
| --- | --- |
| `NR > 1` | 表达式为真 |
| `/regex/` | `$0` 匹配 |
| `$3 ~ /regex/` | 字段匹配 |
| `$3 !~ /regex/` | 字段不匹配 |
| `/start/,/end/` | 范围，含两端 |
| `BEGIN`、`END` | 特殊时机 |
| `BEGINFILE`、`ENDFILE` | 文件级钩子（gawk） |

### 特殊变量

| 变量 | 含义 |
| --- | --- |
| `$0` | 整条记录 |
| `$1`…`$NF` | 字段 |
| `NF` | 字段数 |
| `NR` | 累计记录号 |
| `FNR` | 当前文件记录号 |
| `FS` | 输入字段分隔符 |
| `OFS` | 输出字段分隔符 |
| `RS` | 输入记录分隔符 |
| `ORS` | 输出记录分隔符 |
| `FILENAME` | 当前文件名 |
| `ARGIND` | 当前文件在 `ARGV` 的下标（gawk） |
| `RSTART`、`RLENGTH` | `match()` 的位置和长度 |
| `SUBSEP` | 多维键分隔符 |
| `ENVIRON` | 环境变量数组 |
| `PROCINFO` | 运行时信息（gawk） |
| `CONVFMT`、`OFMT` | 数字转字符串、`print` 数字格式 |

### 运算符

| 运算符 | 含义 |
| --- | --- |
| `+ - * / % ^` | 算术；`**` 是 gawk 扩展 |
| 相邻表达式 | 字符串拼接 |
| `~`、`!~` | 正则匹配、不匹配 |
| `== != < <= > >=` | 比较 |
| <code>&amp;&amp;</code>、<code>&#124;&#124;</code>、<code>!</code> | 逻辑 |
| `? :` | 三元 |
| `in` | 数组键存在 |
| `++`、`--` | 自增、自减 |
| `= += -= *= /= %= ^=` | 赋值 |

### 字符串函数

| 函数 | 作用 |
| --- | --- |
| `length(s)` | 长度；`length(array)` 是 gawk 扩展 |
| `substr(s, start, len)` | 子串，下标从 1 开始 |
| `index(s, t)` | 位置，找不到为 0 |
| `split(s, a, sep)` | 拆成数组，返回字段数 |
| `sub(re, repl, s)` | 替换第一个，返回次数 |
| `gsub(re, repl, s)` | 替换全部，返回次数 |
| `match(s, re)` | 匹配，设置 `RSTART`/`RLENGTH` |
| `tolower(s)`、`toupper(s)` | 大小写 |
| `sprintf(fmt, ...)` | 生成格式化字符串 |
| `gensub(re, repl, how, s)` | 替换并支持反向引用（gawk） |

### 数学与时间

| 函数 | 作用 |
| --- | --- |
| `int(x)` | 向零截断 |
| `sqrt(x)`、`exp(x)`、`log(x)` | 平方根、指数、对数 |
| `sin(x)`、`cos(x)`、`atan2(y,x)` | 三角函数 |
| `rand()`、`srand(seed)` | 伪随机数 |
| `systime()` | 当前时间戳 |
| `strftime(fmt, ts)` | 格式化时间 |
| `mktime("YYYY MM DD HH MM SS")` | 转时间戳（gawk） |

### 数组

```awk
count[$3]++
if ($3 in count) ...
delete count[$3]
for (k in count) print k, count[k]
split("a:b", part, ":")
sum[$2, $3] += $4 * $5
```

- 遍历顺序不确定；用 `sort`、`PROCINFO["sorted_in"]` 或 `asorti`。
- `a[i][j]` 是 gawk 扩展。
- 数组传参按引用，标量按值。

### printf

| 格式 | 含义 |
| --- | --- |
| `%s` | 字符串 |
| `%d`、`%i` | 整数 |
| `%f` | 定点小数 |
| `%e`、`%E` | 科学计数法 |
| `%g`、`%G` | 自动选择 |
| `%x`、`%X`、`%o` | 十六进制、八进制 |
| `%c` | 字符 |
| `%%` | 字面百分号 |
| `%10s`、`%-10s` | 宽度、左对齐 |
| `%05d` | 补零 |
| `%.2f` | 两位小数 |
| `%*.*f` | 动态宽度和精度 |

### getline

| 形式 | 设置 `$0`/`NF` | 设置 `NR`/`FNR` |
| --- | --- | --- |
| `getline` | 是 | 是 |
| `getline var` | 否 | 是 |
| `getline < file` | 是 | 否 |
| `getline var < file` | 否 | 否 |
| <code>cmd &#124; getline</code> | 是 | 否 |
| <code>cmd &#124; getline var</code> | 否 | 否 |

循环条件写 `> 0`；文件/管道读完后 `close()`。

### 常用单行命令

打印第一列：

```shell
awk '{ print $1 }' file
```

按分隔符取列：

```shell
awk -F '\t' '{ print $2, $4 }' file
```

跳过表头并筛选：

```shell
awk -F '\t' 'NR > 1 && $4 > 100000 { print $2 }' file
```

求和：

```shell
awk '{ sum += $1 } END { print sum }' numbers.txt
```

求平均：

```shell
awk '{ sum += $1 } END { printf "%.2f\n", sum / NR }' numbers.txt
```

计数：

```shell
awk '{ count[$1]++ } END { for (k in count) print k, count[k] }' file | sort
```

去重：

```shell
awk '!seen[$0]++' file
```

按字段去重：

```shell
awk '!seen[$1]++' file
```

替换字段：

```shell
awk -F '\t' 'BEGIN { OFS = "\t" } { $2 = "X"; print }' file
```

按条件替换：

```shell
awk '{ sub(/foo/, "bar") } 1' file
```

词频：

```shell
awk '{ for (i=1; i<=NF; i++) freq[tolower($i)]++ } END { for (w in freq) print freq[w], w }' file | sort -k1,1nr
```

连接两个文件：

```shell
awk -F '\t' 'NR == FNR { map[$1] = $2; next } { print $1, map[$1] }' lookup.tsv data.tsv
```

按行号取行：

```shell
awk 'NR >= 10 && NR <= 20' file
```

按范围取块：

```shell
awk '/BEGIN_MARK/,/END_MARK/' file
```

### GNU 扩展

| 功能 | 说明 |
| --- | --- |
| `gensub()` | 反向引用替换 |
| `asort()`、`asorti()` | 数组排序 |
| `length(array)` | 数组长度 |
| `delete array` | 清空数组 |
| `a[i][j]` | 数组的数组 |
| `FPAT`、`FIELDWIDTHS` | 自定义字段解析 |
| `BEGINFILE`、`ENDFILE` | 文件级钩子 |
| `PROCINFO["sorted_in"]` | 数组遍历排序 |
| `IGNORECASE` | 忽略大小写 |
| `--csv` | CSV 模式 |
| `@include`、`@load` | 包含脚本、加载扩展 |
| <code>&#124;&amp;</code> | 双向协进程 |

### 可移植性提醒

- POSIX awk 不保证 `gensub`、`asort`、`length(array)`、`delete array`、数组的数组。
- `nextfile` 在旧实现上不保证。
- `\y`、`\w`、`\s` 是 GNU 扩展；POSIX 用 `[[:<:]]` 也不一定可移植。
- 数组遍历顺序未定义。
- `-i inplace` 是 gawk 扩展，不是标准。
- 复杂 CSV、JSON、YAML 换 Python、`jq`、`yq`。

### 相关章节

- [工作模型](how-awk-works.md)
- [字段与记录](fields-records.md)
- [模式与动作](patterns-actions.md)
- [正则表达式](regex.md)
- [变量与表达式](expressions-variables.md)
- [控制流与函数](control-flow.md)
- [关联数组](arrays.md)
- [内置函数](builtin-functions.md)
- [格式化输出](printf-output.md)
- [getline 与输入输出](getline-io.md)
- [脚本化与可移植性](scripts-and-portability.md)
- [实战案例](recipes.md)
- [排错与常见陷阱](troubleshooting.md)
