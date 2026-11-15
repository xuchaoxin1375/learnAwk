## 字段与记录

上一篇把 awk 的主循环讲清楚了：读一条记录，拆成字段，执行规则。这一篇控制“怎么读”和“怎么拆”。同样的数据，`FS` 设错、`OFS` 没设、`NR` 和 `FNR` 混用，结果就会完全不同。

先记住三个对象：

- **记录**(record)：awk 一次读入的单位，默认是一行，放在 `$0`。
- **字段**(field)：记录按分隔符拆开后的列，放在 `$1`、`$2` 直到 `$NF`。
- **分隔符**：拆记录用 `RS`，拆字段用 `FS`，输出记录用 `ORS`，输出字段用 `OFS`。

### 字段寻址

`$0` 是整条记录，`$1` 是第一个字段。`NF` 是当前记录的字段数，所以 `$NF` 是最后一个字段：

```shell
$ awk -F '\t' 'NR == 2 { print NF, $1, $NF, $(NF - 1) }' examples/data/employees.tsv
5 1 Beijing 120000
```

- `NF` 是 5。
- `$1` 是 `1`。
- `$NF` 等价于 `$5`，是 `Beijing`。
- `$(NF - 1)` 等价于 `$4`，是 `120000`。括号不能省：`$NF - 1` 表示“最后一个字段减 1”，不是“倒数第二个字段”。

字段数可以是 0。空行是一条记录，但 `NF` 为 0，此时 `$1` 是空字符串，`$NF` 也是空字符串。

### 默认的字段分隔

不设置 `FS` 时，awk 按**空白**拆字段：空格、制表符、换行都算分隔符，连续空白只算一个，行首和行尾的空白会被忽略。

```shell
$ printf '  Alice   Engineering   120000  \n' | awk '{ print NF; print "[" $1 "]"; print "[" $NF "]" }'
3
[Alice]
[120000]
```

这条规则只适用于默认的 `FS=" "`。一旦把 `FS` 设成单个字符，行为就变成严格的字面分隔：

```shell
$ printf 'a::c\n' | awk -F ':' '{ print NF; print "[" $2 "]" }'
3
[]
```

两个冒号之间是空字段，`NF` 仍然是 3。

### 设置 FS

三种常见方式：

```shell
awk -F '\t' '{ print $2 }' examples/data/employees.tsv
```

```shell
awk 'BEGIN { FS = "\t" } { print $2 }' examples/data/employees.tsv
```

```shell
awk -v FS='\t' '{ print $2 }' examples/data/employees.tsv
```

`-F` 最简洁，适合命令行；`BEGIN { FS = ... }` 适合脚本文件；`-v FS=...` 适合需要从外部传入分隔符的场景。三者在读取第一条记录之前生效。

**时机很重要**。在普通动作里设置 `FS`，对当前记录已经太晚：

```shell
$ printf 'a:b\n' | awk '{ FS = ":"; print $1 }'
a:b

$ printf 'a:b\n' | awk 'BEGIN { FS = ":" } { print $1 }'
a
```

第一条命令读入 `a:b` 时已经按默认空白拆分，整行只有一个字段；之后设置 `FS` 只影响下一条记录。第二条在 `BEGIN` 里设置，读第一条记录时已经生效。

### FS 是字符还是正则

- `FS=" "` 是默认值，表示“连续的空白”。
- `FS=":"`、`FS="\t"`、`FS=","` 是单个字符，按字面拆分。
- 其他情况按正则表达式处理，例如 `FS="[,;]"` 表示逗号或分号。

```shell
$ printf 'a, b;c\n' | awk -F '[,;] *' '{ print NF, $2 }'
3 b
```

`FS="[,;] *"` 匹配一个逗号或分号，后面可以跟零个或多个空格。拆出来的第二个字段是 `b`，前后的空格被分隔符吃掉了。

单字符 `FS` 有一个容易误解的地方：**除了空格，单字符按字面拆分，不按正则**。所以 `-F '.'` 是按点号拆，不是按“任意字符”拆：

```shell
$ printf 'a.b.c\n' | awk -F '.' '{ print NF, $2 }'
3 b
```

只有当 `FS` 多于一个字符时，才按正则解释，元字符需要转义。例如按“点号加空格”拆分：

```shell
$ printf 'a. b. c\n' | awk -F '\\. ' '{ print NF, $2 }'
3 b
```

这里 `FS` 是两个字符的正则 `\. `，`\.` 表示字面点号，空格表示后面的空格。写成 `-F '. '` 也能匹配点号加空格，因为 `.` 在正则里是通配符，可能匹配到超出预期的字符；显式转义更稳。

### OFS 与字段重建

`OFS` 是输出字段分隔符，默认是一个空格。它只在**重建记录**时起作用：

```shell
$ awk -F '\t' 'BEGIN { OFS = "," } NR > 1 { $5 = "China"; print }' examples/data/employees.tsv | head -n 2
1,Alice,Engineering,120000,China
2,Bob,Sales,90000,China
```

给 `$5` 赋值后，awk 用 `OFS` 把 5 个字段重新连接成 `$0`，所以输出变成逗号分隔。如果没有修改任何字段，`print` 直接输出原来的 `$0`，`OFS` 不会改变它：

```shell
$ awk -F '\t' 'BEGIN { OFS = "," } NR == 2 { print }' examples/data/employees.tsv
1	Alice	Engineering	120000	Beijing
```

这条记录仍然是制表符分隔，因为 `$0` 没有重建。

`print $1, $2` 里的逗号会使用 `OFS`；`print $1 $2` 是字符串拼接，不使用 `OFS`：

```shell
$ printf 'Alice 120000\n' | awk 'BEGIN { OFS = "|" } { print $1, $2; print $1 $2 }'
Alice|120000
Alice120000
```

### 修改 $0 与修改字段

这两种操作的重建方向不同：

- 给 `$2` 赋值：用 `OFS` 把字段重新拼成 `$0`。
- 给 `$0` 赋值：用 `FS` 把新记录重新拆成字段。

```shell
$ printf 'a b c\n' | awk -F ':' '{ $0 = "x:y"; print NF, $1 }'
2 x
```

`$0` 被替换成 `x:y`，awk 按 `FS=":"` 重新拆分，得到两个字段。

### 增加、删除和截断字段

给 `NF` 赋值会改变字段数量，并重建 `$0`：

```shell
$ printf 'a b c\n' | awk '{ NF = 2; print; print NF }'
a b
2
```

```shell
$ printf 'a b\n' | awk '{ NF = 4; print "[" $0 "]"; print NF; print "[" $3 "]" }'
[a b  ]
4
[]
```

把 `NF` 改大时，新增的字段是空字符串，`$0` 里会多出相应的分隔符。把 `NF` 改小会丢弃后面的字段。这个技巧常用于“只保留前几列”，但要注意它会重建 `$0`，原来的空白可能被 `OFS` 规范化。

### NR、FNR 与 FILENAME

- `NR` 是**累计记录号**，从 1 开始，跨文件不重置。
- `FNR` 是**当前文件的记录号**，每读一个新文件就从 1 重新开始。
- `FILENAME` 是当前文件名；在 `BEGIN` 里还没有文件，通常是空字符串。

用两个小文件观察：

```shell
$ awk -F '\t' '{ print FILENAME, FNR, NR, $1 }' examples/data/team-a.tsv examples/data/team-b.tsv
examples/data/team-a.tsv 1 1 Alice
examples/data/team-a.tsv 2 2 Bob
examples/data/team-b.tsv 1 3 Carol
examples/data/team-b.tsv 2 4 Dave
```

`FNR` 在第二个文件回到 1，`NR` 继续增加到 4。

这个区别直接影响“跳过表头”的写法：

- 单个文件：`NR > 1` 可以跳过表头。
- 多个都带表头的文件：用 `FNR > 1`，否则第二个文件的表头不会被跳过。

```shell
$ awk -F '\t' 'FNR == 1 { print FILENAME, $1 }' examples/data/team-a.tsv examples/data/team-b.tsv
examples/data/team-a.tsv Alice
examples/data/team-b.tsv Carol
```

GNU awk 还提供 `ARGIND`，表示当前文件在 `ARGV` 中的位置。需要按文件名做不同处理时，`FILENAME` 和 `ARGIND` 都很有用。

### RS 与 ORS

`RS` 是记录分隔符，默认是换行。把它改成单个字符：

```shell
$ printf 'a;b;c' | awk 'BEGIN { RS = ";" } { print NR, "[" $0 "]" }'
1 [a]
2 [b]
3 [c]
```

最后一个 `c` 后面没有分号，仍然是一条记录。GNU awk 还提供 `RT`，保存实际匹配到的记录分隔符：

```shell
$ printf 'a;b;c' | awk 'BEGIN { RS = ";" } { print NR, "[" $0 "]", "[" RT "]" }'
1 [a] [;]
2 [b] [;]
3 [c] []
```

最后一条记录的 `RT` 是空字符串，因为输入末尾没有分隔符。

`ORS` 控制输出记录的分隔符：

```shell
$ printf 'a\nb\n' | awk 'BEGIN { ORS = ";" } { print }'
a;b;
```

注意最后也会输出一个 `;`，因为 `print` 在每条记录后都追加 `ORS`。

### 段落模式

`RS=""` 是 awk 的特殊模式：用空行分隔记录，连续的空行算一个分隔符。它适合处理“一段一段”的文本：

```shell
$ awk 'BEGIN { RS = "" } { print NR, NF, $1 }' examples/data/paragraphs.txt
1 20 Awk
2 19 Fields
3 22 Arrays
```

`examples/data/paragraphs.txt` 有 3 段，所以输出 3 条记录。每条记录内部的换行会被当作字段分隔符，`NF` 是这段文字的单词数（包含标点，所以不是严格的词数统计）。

段落模式有几个容易忽略的规则：

- 记录开头和结尾的空行会被忽略。
- 记录内部的空行不会出现，因为空行就是记录分隔符。
- 在段落模式下，换行始终可以作为字段分隔符，即使 `FS` 被设成其他字符。
- `RS=""` 只适用于 POSIX 的段落模式；正则形式的 `RS` 是 GNU 扩展。

### GNU 扩展：FIELDWIDTHS、FPAT 与 --csv

固定宽度数据没有明显的分隔符，靠列位置切分。GNU awk 的 `FIELDWIDTHS` 可以按宽度拆：

```shell
$ awk 'BEGIN { FIELDWIDTHS = "8 12 *" } { print "[" $1 "]", "[" $2 "]", $3 }' examples/data/fixed-width.txt
[Alice   ] [Engineering ] 120000
[Bob     ] [Sales       ] 90000
[Carol   ] [Engineering ] 135000
```

`8 12 *` 表示前 8 个字符、接着 12 个字符、剩下全部。字段里保留了填充空格，需要时用 `gsub(/^ +| +$/, "", $1)` 去掉。设置 `FIELDWIDTHS` 后，`FS` 不再生效；反过来设置 `FS` 或 `FPAT` 会清除 `FIELDWIDTHS`。

`FPAT` 不是“分隔符”，而是“字段长什么样”。它适合字段内部含分隔符的简单 CSV：

```shell
$ awk 'BEGIN { FPAT = "([^,]+)|(\"[^\"]+\")" } { print NF, "[" $2 "]" }' examples/data/messy.csv
2 [note]
2 ["Likes commas, semicolons, and quotes"]
2 ["Says ""hello"""]
2 [plain]
```

这个正则能识别“不含逗号的字段”或“双引号包起来的字段”，但它不认识 CSV 的双引号转义规则，`"Says ""hello"""` 这种写法仍然会出错。

GNU awk 5.3 起提供 `--csv` 选项，按 CSV 规则解析并去掉外层引号：

```shell
$ gawk --csv 'NR > 1 { print NF, "[" $2 "]" }' examples/data/messy.csv
2 [Likes commas, semicolons, and quotes]
2 [Says "hello"]
2 [plain]
```

`--csv` 只解决 CSV 的分隔和引号问题，不负责验证列数、类型和编码。复杂 CSV 仍然建议用 Python 的 `csv` 模块。GNU awk 5.3 之前没有 `--csv`，只能用 `FPAT` 或换工具。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 第一行字段不对 | `FS` 在动作里设置，当前记录已经拆分完 | 用 `-F` 或 `BEGIN { FS = ... }` |
| 输出没有按 `OFS` 分隔 | 没有修改字段，`$0` 没有重建 | 修改一个字段，或显式拼接输出 |
| 多个文件只跳过第一个表头 | 用了 `NR > 1`，第二个文件的 `NR` 继续增长 | 改用 `FNR > 1` |
| `$NF - 1` 不是倒数第二个字段 | 它表示最后一个字段的值减 1 | 写 `$(NF - 1)` |
| 空行让程序报错 | 空行 `NF=0`，`$1` 是空字符串 | 用 `NF > 0` 过滤，或给默认值 |
| 正则分隔符不生效 | 多字符 `FS` 的元字符没有转义，或 `FS` 设置太晚 | 转义元字符，并确认在 `BEGIN` 或命令行设置 |
| `RS=""` 后字段数很大 | 段落模式把换行也当字段分隔符 | 这是预期行为；按需设置 `FS` |

### 小结

- `NF` 是字段数，`$NF` 是最后一个字段，`$(NF-1)` 是倒数第二个。
- 默认 `FS` 按连续空白拆分；单字符 `FS` 按字面拆分；其他按正则拆分。
- `FS` 必须在读第一条记录前设置，`-F` 和 `BEGIN` 都满足这个条件。
- 修改字段会用 `OFS` 重建 `$0`；修改 `$0` 会用 `FS` 重新拆字段。
- `NR` 跨文件累计，`FNR` 每个文件重置，带表头的多文件处理用 `FNR`。
- `RS` 控制记录，`ORS` 控制输出；`RS=""` 是段落模式。
- `FIELDWIDTHS`、`FPAT`、`--csv` 是 GNU 扩展，使用前确认版本和可移植性。

### 练习

- 打印 `examples/data/passwd.txt` 每行的用户名、家目录和 shell。
- 统计 `examples/data/employees.tsv` 中城市字段的空格分隔情况，解释为什么 `$5` 能直接取到城市。
- 把 `examples/data/employees.tsv` 的字段分隔符改成 `|` 输出，只打印姓名和薪资。
- 用 `FNR` 跳过 `team-a.tsv` 和 `team-b.tsv` 各自的第一行，打印文件名和姓名。
- 用 `RS=";"` 处理 `printf 'a;b;c'`，打印每条记录和 `RT`。
- 用 `FIELDWIDTHS` 读取 `fixed-width.txt`，输出去掉两端空格后的三个字段。

<details>
<summary>参考答案</summary>

用户名、家目录和 shell：

```shell
awk -F ':' '{ print $1, $(NF - 1), $NF }' examples/data/passwd.txt
```

城市能直接取到，是因为默认 `FS` 把连续的制表符当作一个分隔符，行首行尾没有多余空白；`$5` 正好是第五个字段。

改成 `|` 输出：

```shell
awk -F '\t' 'BEGIN { OFS = "|" } NR > 1 { print $2, $4 }' examples/data/employees.tsv
```

跳过两个文件各自的表头：

```shell
awk -F '\t' 'FNR > 1 { print FILENAME, $1 }' examples/data/team-a.tsv examples/data/team-b.tsv
```

分号记录：

```shell
printf 'a;b;c' | awk 'BEGIN { RS = ";" } { print NR, "[" $0 "]", "[" RT "]" }'
```

固定宽度：

```shell
awk 'BEGIN { FIELDWIDTHS = "8 12 *" } {
  for (i = 1; i <= NF; i++) gsub(/^ +| +$/, "", $i)
  print $1, $2, $3
}' examples/data/fixed-width.txt
```

`gsub` 会修改字段并重建 `$0`，对当前输出没有影响，因为我们紧接着打印的是字段。

</details>
