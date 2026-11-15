## 模式与动作

awk 的规则由“模式 + 动作”组成。模式决定**哪些记录**进入动作，动作决定**对这些记录做什么**。上一篇已经用过 `NR > 1`、`/Engineering/` 这样的简单模式；这一篇把模式的选择方式系统化，并补上改变流程的 `next`、`nextfile` 和 `exit`。

### 模式的种类

| 模式 | 例子 | 匹配条件 |
| --- | --- | --- |
| 表达式 | `NR > 1`、`$4 > 100000` | 表达式为真 |
| 正则 | `/Engineering/`、`$3 ~ /^Eng/` | 当前记录或指定字段匹配正则 |
| 范围 | `/start/,/end/` | 从匹配 start 的行到匹配 end 的行（含两端） |
| 特殊块 | `BEGIN`、`END`、`BEGINFILE`、`ENDFILE` | 在特定时机执行 |
| 组合 | `NR > 1 && $4 > 100000` | 逻辑组合为真 |

模式可以省略，动作也可以省略：

```awk
/Engineering/          # 匹配时打印 $0
{ print $2 }           # 每条记录都执行
/Engineering/ { }      # 匹配时什么也不做
```

最后一种写法看起来没用，但配合 `next` 可以表达“跳过某些记录”。

### 表达式模式

表达式模式最直接：结果为真就执行动作。

```shell
$ awk -F '\t' 'NR > 1 && $4 > 100000 { print $2, $4 }' examples/data/employees.tsv
Alice 120000
Carol 135000
Frank 110000
Lisa 128000
```

`NR > 1` 排除表头，`$4 > 100000` 筛选薪资。两个条件用 `&&` 连接，都成立才执行。

取偶数行：

```shell
$ awk 'NR % 2 == 0 { print NR, $0 }' examples/data/numbers.txt
2 1
4 1
6 9
8 6
10 3
```

`NR % 2 == 0` 是普通算术表达式，结果为真时打印。

### 真与假

awk 的真假判断和 JavaScript 不同，字符串 `"0"` 是**真**，因为它是非空字符串：

```shell
$ awk 'BEGIN {
  if ("0") print "string 0: true"; else print "string 0: false"
  if ("") print "empty: true"; else print "empty: false"
  if (0) print "number 0: true"; else print "number 0: false"
}'
string 0: true
empty: false
number 0: false
```

但从输入读进来的字段可能是“数字字符串”，布尔判断会按数字处理：

```shell
$ printf '0\n' | awk '{ if ($1) print "field true"; else print "field false"; if ($1 == 0) print "equals zero" }'
field false
equals zero
```

判断规则可以简单记成：

- 数字 0、空字符串、未初始化变量为假。
- 其他数字和非空字符串为真。
- 从输入读到的、看起来像数字的字段按数字判断；字面量 `"0"` 仍是字符串，所以为真。

如果不确定，显式比较，不要依赖隐式真假：

```awk
$4 + 0 > 0
length($0) > 0
$3 != ""
```

### 正则模式

`/regex/` 对 `$0` 匹配：

```shell
$ awk '/Engineering/' examples/data/employees.tsv
1	Alice	Engineering	120000	Beijing
3	Carol	Engineering	135000	Shenzhen
6	Frank	Engineering	110000	Beijing
12	Lisa	Engineering	128000	Shenzhen
```

对指定字段匹配用 `~`，不匹配用 `!~`：

```shell
$ awk -F '\t' '$3 ~ /^Eng/ { print $2, $3 }' examples/data/employees.tsv
Alice Engineering
Carol Engineering
Frank Engineering
Lisa Engineering

$ awk -F '\t' 'NR > 1 && $3 !~ /Engineering/ { print $2, $3 }' examples/data/employees.tsv
Bob Sales
Dave Support
Eve Sales
Grace Support
Heidi Marketing
Ivan Sales
Judy Marketing
Ken Support
```

`/regex/` 是 `/regex/` 作用于 `$0` 的简写，等价于 `$0 ~ /regex/`。正则的完整语法、锚点、字符类和捕获在[正则表达式](regex.md)里展开。

### 范围模式

范围模式用逗号分隔两个模式：

```awk
start, end { action }
```

它从**第一次匹配 start 的记录**开始执行动作，到**第一次匹配 end 的记录**（含这条）结束，然后等待下一次 start。两个端点都可以是正则或表达式。

```shell
$ awk -F ',' '/2026-01-05/,/2026-01-07/' examples/data/sales.csv
2026-01-05,North,Keyboard,3,49.90
2026-01-05,South,Mouse,10,19.90
2026-01-06,North,Monitor,2,189.00
2026-01-06,East,Keyboard,5,49.90
2026-01-07,West,Mouse,8,19.90
```

这条命令从第一条含 `2026-01-05` 的记录开始，到第一条含 `2026-01-07` 的记录结束。`2026-01-07` 还有一条 `South,Monitor`，它**没有**被包含，因为范围在第一次匹配 end 时就结束了。

把它和显式比较对比：

```shell
$ awk -F ',' 'NR > 1 && $1 >= "2026-01-05" && $1 <= "2026-01-07"' examples/data/sales.csv
2026-01-05,North,Keyboard,3,49.90
2026-01-05,South,Mouse,10,19.90
2026-01-06,North,Monitor,2,189.00
2026-01-06,East,Keyboard,5,49.90
2026-01-07,West,Mouse,8,19.90
2026-01-07,South,Monitor,1,189.00
```

两条命令的输出不同：范围模式在第一个 end 处停止，显式比较会包含所有满足日期条件的记录。**范围模式适合“从标记到标记”的文本块，不适合按值筛选一整个区间**。

范围模式还有两个边界：

- 如果 end 永远不匹配，范围会一直持续到文件末尾。
- 同一个范围规则可以在一个文件里多次触发，每次 start 都会重新开始。

### 组合模式

`&&`、`||`、`!` 和括号可以组合条件：

```shell
$ awk -F '\t' 'NR > 1 && ($3 == "Sales" || $4 > 130000) { print $2, $3, $4 }' examples/data/employees.tsv
Carol Engineering 135000
Bob Sales 90000
Eve Sales 95000
Ivan Sales 92000
```

`&&` 的优先级高于 `||`，复杂条件建议加括号。`!` 是逻辑非：

```shell
awk -F '\t' 'NR > 1 && !($3 == "Engineering") { print $2 }' examples/data/employees.tsv
```

### BEGIN、END 与文件级钩子

`BEGIN` 和 `END` 在[工作模型](how-awk-works.md)里已经出现，这里只补边界：

- `BEGIN` 在读取任何记录之前执行，可以设置 `FS`、`OFS`、变量，打印表头。
- `END` 在所有记录处理完后执行，即使中间用了 `exit` 也会执行。
- 如果程序只有 `BEGIN`，awk 不读取输入。

GNU awk 还提供两个文件级钩子：

```shell
$ awk 'BEGINFILE { print "begin", FILENAME } ENDFILE { print "end", FILENAME, FNR }' examples/data/team-a.tsv examples/data/team-b.tsv
begin examples/data/team-a.tsv
end examples/data/team-a.tsv 2
begin examples/data/team-b.tsv
end examples/data/team-b.tsv 2
```

- `BEGINFILE` 在每个文件开始处理前执行。
- `ENDFILE` 在每个文件处理完后执行；即使文件为空，或者用了 `nextfile` 提前离开，也会执行。
- 这两个块是 **GNU** 扩展，POSIX awk 不支持。

### next、nextfile 与 exit

这三个语句都会改变默认流程，但作用范围不同：

| 语句 | 作用 | 后续影响 |
| --- | --- | --- |
| `next` | 跳过当前记录的剩余规则 | 继续读下一条记录 |
| `nextfile` | 跳过当前文件的剩余记录 | 开始下一个文件；gawk 与较新实现支持，老 POSIX 实现不保证 |
| `exit` | 停止处理所有输入 | 跳到 `END` 块，然后退出 |

`next` 常用于“分流”：

```shell
$ awk -F '\t' '
NR == 1 { next }
$4 > 100000 { print "high", $2; next }
{ print "normal", $2 }
' examples/data/employees.tsv | head -n 6
high Alice
normal Bob
high Carol
normal Dave
normal Eve
high Frank
```

表头被 `next` 跳过；高薪行打印 `high` 后立即 `next`，不会再落入最后的 `normal` 分支。

`nextfile` 可以快速跳过不需要的文件内容：

```shell
$ awk 'FNR == 1 { print FILENAME, $1; nextfile }' examples/data/team-a.tsv examples/data/team-b.tsv
examples/data/team-a.tsv Alice
examples/data/team-b.tsv Carol
```

每个文件只打印第一行，然后跳到下一个文件。

`exit` 会结束主循环，但 `END` 仍会执行：

```shell
$ awk 'BEGIN { print "start" } NR == 3 { exit } END { print "end", NR }' examples/data/employees.tsv
start
end 3
```

`NR` 停在 3，说明只处理了 3 条记录。可以给 `exit` 一个状态码：

```shell
$ awk 'BEGIN { print "before"; exit 3; print "after" } END { print "end" }'
before
end
$ echo $?
3
```

`exit 3` 之后的语句不会执行，`END` 会执行，进程退出码是 3。

两个边界：

- `next` 不能用在 `BEGIN` 或 `END` 里，awk 会报错：`next` used in BEGIN action。
- `exit` 放在 `END` 里会立即结束 `END`，不再执行后续语句。

### 动作里的多条语句

动作块可以包含多条语句，用换行或分号分隔：

```awk
NR > 1 {
    count++
    total += $4
    if ($4 > 100000) high++
}
```

如果动作只有一条 `print`，可以省略花括号；但一旦有多条语句，花括号不能省。缩进和换行不影响语义，只影响可读性。

空动作 `{ }` 是合法的，表示匹配时什么也不做：

```shell
$ awk '{ }' examples/data/team-a.tsv
$ echo $?
0
```

它不会输出任何内容，但会正常读完输入。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 表头也被筛选出来 | 字符串和数字比较按字符串规则，表头可能为真 | 加 `NR > 1` 或 `$4 + 0 > ...` |
| 范围模式多选/少选 | 范围在第一次 end 处停止，不是按值区间 | 用显式比较 `>=`/`<=` |
| `next` 报错 | 用在了 `BEGIN`/`END` | 把 `next` 放到普通规则里 |
| 多文件只处理第一个文件 | 没有 `nextfile` 或文件名参数写错 | 检查 `ARGV`、`FILENAME`，用 `nextfile` 明确跳转 |
| `exit` 后 `END` 没执行 | 在 `END` 里又调用了 `exit` | 避免在 `END` 里提前退出 |
| 正则模式匹配错字段 | `/re/` 默认匹配 `$0` | 用 `$3 ~ /re/` 指定字段 |

### 小结

- 模式可以是表达式、正则、范围、特殊块或它们的组合。
- `/re/` 匹配 `$0`，`$n ~ /re/` 匹配指定字段。
- 范围模式是“从 start 到 end 的文本块”，不是数值区间。
- `next` 跳过当前记录的剩余规则，`nextfile` 跳过当前文件，`exit` 结束主循环但执行 `END`。
- `BEGINFILE`/`ENDFILE` 是 GNU 扩展，适合按文件初始化和汇总。
- 条件复杂时加括号，涉及表头时显式排除。

### 练习

- 打印 `examples/data/access.log` 中状态码为 500 的行。
- 打印 `examples/data/employees.tsv` 中薪资在 90000 到 120000 之间（含边界）的员工。
- 用范围模式打印 `examples/data/sales.csv` 中从 `2026-01-08` 到 `2026-01-10` 的记录，并解释为什么最后一天的记录可能不全。
- 用 `next` 跳过表头，并分别统计 Engineering 和非 Engineering 的人数。
- 用 `nextfile` 只处理 `team-a.tsv` 和 `team-b.tsv` 的第一行，打印文件名和姓名。
- 写一个 `BEGIN`/`END` 程序，打印开始提示、记录总数和结束提示。

<details>
<summary>参考答案</summary>

500 请求：

```shell
awk '$9 == 500 { print }' examples/data/access.log
```

薪资区间：

```shell
awk -F '\t' 'NR > 1 && $4 >= 90000 && $4 <= 120000 { print $2, $4 }' examples/data/employees.tsv
```

日期范围：

```shell
awk -F ',' '/2026-01-08/,/2026-01-10/' examples/data/sales.csv
```

范围在第一条 `2026-01-10` 记录处停止，所以 `2026-01-10` 后面的同一天记录不会包含。需要完整日期区间时用显式比较。

分流统计：

```shell
awk -F '\t' '
NR == 1 { next }
$3 == "Engineering" { eng++; next }
{ other++ }
END { print "Engineering", eng; print "Other", other }
' examples/data/employees.tsv
```

`nextfile`：

```shell
awk 'FNR == 1 { print FILENAME, $1; nextfile }' examples/data/team-a.tsv examples/data/team-b.tsv
```

开始与结束提示：

```shell
awk 'BEGIN { print "start" } { n++ } END { print "records", n }' examples/data/team-a.tsv
```

</details>
