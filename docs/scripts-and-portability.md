## 脚本化与可移植性

把 awk 程序写进文件、加 shebang、处理多个文件和版本差异，才算从“会写单行命令”走到“能交付脚本”。这一篇讲脚本的写法、GNU 扩展的边界、性能取舍和调试手段。

### 从 -f 开始

短程序可以写在命令行，长程序写成 `.awk` 文件：

```awk
# examples/scripts/salary-sum.awk
BEGIN { FS = "\t" }

NR == 1 { next }

{ total += $4 }

END { printf "total=%d\n", total }
```

运行：

```shell
gawk -f examples/scripts/salary-sum.awk examples/data/employees.tsv
```

`-f` 可以出现多次，awk 会按顺序合并：

```shell
gawk -f lib.awk -f main.awk input.txt
```

GNU awk 还支持 `@include "file.awk"`，在程序里包含另一个文件。它不是 POSIX 语法，路径相对于当前工作目录或 `AWKPATH`。

### shebang 与可执行脚本

把脚本做成可执行文件：

```awk
#!/usr/bin/env -S gawk -f
BEGIN { print "hello" }
```

然后：

```shell
chmod +x examples/scripts/hello.awk
./examples/scripts/hello.awk
```

`#!/usr/bin/env -S gawk -f` 的含义是：用 `env` 找到 `gawk`，`-S` 让 `env` 把后面的 `gawk -f` 拆成“命令 + 参数”，再把脚本路径交给 `gawk -f`。它依赖 `gawk` 在 PATH 中。

不要写成 `#!/usr/bin/env gawk -f`。很多系统的 `env` 会把 `gawk -f` 当成一个完整的命令名，报 `No such file or directory`；Git Bash 就属于这种情况。需要更保守的写法时，用绝对路径：

```awk
#!/usr/bin/gawk -f
```

或者干脆不依赖 shebang，始终用 `gawk -f script.awk` 运行。

shebang 的跨平台边界：

- Windows 原生不识别 shebang，Git Bash 和 WSL 可以。
- `env -S` 需要较新的 coreutils 或 BSD env；老系统没有时用绝对路径或 `gawk -f`。
- 只安装了 GNU awk 但命令名是 `awk` 的系统，可以写 `#!/usr/bin/awk -f`，前提是 `awk` 确实是 GNU 实现。
- 文件必须用 LF 换行；CRLF 会让 shebang 变成 `gawk\r`，报“找不到解释器”。

仓库的 `.gitattributes` 已经声明 `* text=auto eol=lf`，避免 Windows 下误提交 CRLF。

### 脚本结构

一个可维护的 awk 脚本通常按这个顺序组织：

```awk
#!/usr/bin/env -S gawk -f
# 一句话说明脚本用途
# 用法: gawk -f script.awk <输入>

BEGIN {
    FS = "\t"
    OFS = "\t"
}

# 跳过表头
FNR == 1 { next }

# 数据行
{
    count[$3]++
    sum[$3] += $4
}

END {
    for (dept in count) {
        printf "%s\t%d\t%.2f\n", dept, count[dept], sum[dept] / count[dept]
    }
}
```

约定：

- 文件头写用途、用法、输入格式和依赖。
- `BEGIN` 放初始化，`END` 放汇总，中间放数据处理。
- 函数放在规则之前或之后都可以，但集中放在一起更好读。
- 注释解释“为什么”，不要逐行翻译代码。
- 变量名用英文，避免和内置变量重名。

### 传入参数

`-v` 在 `BEGIN` 前设置变量：

```shell
gawk -v limit=100000 -F '\t' '$4 > limit { print $2 }' examples/data/employees.tsv
```

`-F` 设置 `FS`，等价于在 `BEGIN` 里写 `FS="..."`。`-v` 会处理转义，例如 `-v sep='\t'` 得到制表符。

`--` 表示选项结束，后面即使以 `-` 开头也当作文件名：

```shell
gawk '{ print }' -- -weird-name.txt
```

需要读取标准输入时用 `-`：

```shell
printf 'a b\n' | gawk '{ print $2 }' -
```

### GNU 扩展与 POSIX

GNU awk 在 POSIX 之上加了很多功能。写可移植脚本时，先判断目标环境：

| 功能 | gawk | POSIX/mawk/BSD |
| --- | --- | --- |
| `gensub()` | 支持 | 不保证 |
| `asort()`、`asorti()` | 支持 | 不保证 |
| `length(array)` | 支持 | 不保证 |
| `delete array` | 支持 | 不保证 |
| 数组的数组 `a[i][j]` | 支持 | 不保证 |
| `FPAT`、`FIELDWIDTHS` | 支持 | 不保证 |
| `BEGINFILE`、`ENDFILE` | 支持 | 不保证 |
| `nextfile` | 支持 | 老实现不保证 |
| `PROCINFO`、`IGNORECASE` | 支持 | 不保证 |
| `\y`、`\w`、`\s` | 支持 | 不保证 |
| `--csv` | 5.3+ | 不支持 |
| `@include`、`@load` | 支持 | 不支持 |
| <code>&#124;&amp;</code> 协进程 | 支持 | 不支持 |

`--posix` 会关闭不兼容的扩展：

```shell
$ gawk --posix 'BEGIN { print gensub(/a/, "b", "g", "aaa") }'
gawk: cmd. line:1: warning: regexp constant for parameter #1 yields boolean value
gawk: cmd. line:1: fatal: function `gensub' not defined
```

数组的数组也会被拒绝：

```shell
$ gawk --posix 'BEGIN { a[1][2] = 3; print a[1][2] }'
gawk: cmd. line:1: fatal: multidimensional arrays are a gawk extension
```

`--traditional` 也会关闭一部分 GNU 扩展，但保留的集合和 `--posix` 不完全相同。需要严格 POSIX 行为时用 `--posix`；需要“gawk 但不启用某些扩展”时查手册。环境变量 `POSIXLY_CORRECT` 也会影响 gawk 的行为。

**可移植写法建议**：

- 用 `sub`/`gsub` 代替 `gensub`。
- 用外部 `sort` 代替 `asort`/`asorti`。
- 用 `for (k in a) n++` 代替 `length(a)`。
- 用 `delete a[k]` 代替 `delete a`。
- 用 `split(k, p, SUBSEP)` 代替数组的数组。
- 用 `FNR` 和显式文件处理代替 `BEGINFILE`/`ENDFILE`。
- 用 `LC_ALL=C` 固定字符和排序行为。

### 性能

awk 通常比逐行 shell 循环快很多，但写法仍会影响性能：

- **避免每行调用外部命令**：`system()` 和 `cmd | getline` 都会启动进程，放在主循环里可能比 awk 本身慢几个数量级。
- **用单字符 FS**：`FS=","` 比复杂正则快；字段多、文件大时差异明显。
- **减少字符串拼接**：在循环里不断 `s = s $0` 会反复分配；用 `printf` 直接输出，或收集到数组后一次输出。
- **用 `LC_ALL=C` 处理 ASCII**：字符处理更快，行为更确定；处理 UTF-8 文本时再切回 UTF-8 locale。
- **用 `-b` 强制字节**：只处理字节、不关心字符时，GNU awk 的 `-b` 可以避免多字节开销。
- **用 `nextfile` 跳过不需要的文件内容**：比读完后判断更快。
- **谨慎使用大数组**：awk 把数组放在内存里，几十 GB 的输入不要指望单机 awk 全部聚合。
- **比较 mawk**：mawk 在简单规则上可能更快，但 GNU 扩展少；先用真实数据 benchmark，不要凭感觉换实现。

一个简单的计时方式（下面是本机示例，实际时间会不同）：

```shell
$ time gawk -F ',' 'NR > 1 { sum += $4 * $5 } END { print sum }' examples/data/sales.csv
4948.7

real    0m0.017s
user    0m0.015s
sys     0m0.015s
```

小文件的时间主要来自进程启动，不能代表大文件性能。做性能判断时用真实规模的数据。

### 调试

GNU awk 提供几个实用选项：

| 选项 | 作用 |
| --- | --- |
| `--lint` | 对可疑写法给出警告 |
| `--debug` | 进入交互式调试器（需要终端） |
| `--profile[=file]` | 生成执行剖面，默认 `awkprof.out` |
| `--dump-variables[=file]` | 结束时转储全局变量，默认 `awkvars.out` |
| `--version` | 版本信息 |

`--lint` 能发现未初始化变量：

```shell
$ gawk --lint 'BEGIN { print x + 1 }'
gawk: cmd. line:1: warning: reference to uninitialized variable `x'
1
```

它不会发现所有逻辑错误，但能拦住一类常见问题。

程序里的临时诊断可以写到标准错误：

```awk
print "debug: NR=" NR ", NF=" NF > "/dev/stderr"
```

跨平台时 `/dev/stderr` 不一定可用，可以写到临时文件，或在 shell 层把 stdout/stderr 分开。

交互式调试适合复杂脚本：

```shell
gawk --debug -f examples/scripts/join.awk examples/data/inventory.tsv examples/data/orders.tsv
```

调试器命令和 GDB 类似，初学阶段优先用 `--lint`、打印变量和缩小输入。

### 测试脚本

仓库的 `scripts/verify.sh` 会验证教程中的核心行为：

```shell
bash scripts/verify.sh
```

它使用临时目录，不会修改仓库文件。修改示例或脚本后先跑它。

如果脚本要支持 POSIX awk，再加一层检查：

```shell
gawk --posix -f examples/scripts/salary-sum.awk examples/data/employees.tsv
```

`salary-sum.awk` 只用了 POSIX 语法，应该能通过；用了 `PROCINFO` 的脚本会失败，这是预期的。

### 什么时候换 Python

awk 适合“逐行、按字段、聚合”的任务。遇到下面情况，换 Python 更省时间：

- CSV 有引号、转义、换行，需要严格解析。
- JSON、YAML、XML 等嵌套结构。
- 需要复杂数据结构、类、异常处理和单元测试。
- 需要随机访问、数据库、网络请求。
- 脚本超过几百行，逻辑开始难以维护。
- 需要团队协作和长期维护，Python 的生态和可读性更合适。

awk 不是“更差的 Python”，它有明确的适用边界。把边界内的任务写好，比强行用 awk 做所有事更有价值。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| shebang 报找不到解释器 | CRLF 或 `gawk` 不在 PATH | 用 LF，安装 gawk，或改 shebang |
| `-f` 脚本不执行 | 文件名写错，或 `-f` 后跟了输入文件 | 检查 `gawk -f script.awk input` 的参数顺序 |
| `--posix` 下函数未定义 | 用了 GNU 扩展 | 换 POSIX 写法，或去掉 `--posix` |
| 脚本在 mawk 上结果不同 | 数组顺序、`length(array)`、`gensub` 等差异 | 用 POSIX 子集，或显式要求 gawk |
| 性能突然变差 | 每行调用 `system()` 或管道 | 把外部命令移出主循环 |
| `--profile` 生成文件污染仓库 | 默认写到当前目录 | 指定输出路径或加入 `.gitignore` |
| 调试输出混进数据 | 用了 stdout | 诊断写 stderr 或单独文件 |

### 小结

- 长程序用 `-f` 写成文件，加 shebang 和可执行权限。
- 脚本按“文件头、BEGIN、规则、函数、END”组织，注释解释意图。
- `-v` 传变量，`-F` 设分隔符，`--` 结束选项。
- GNU 扩展提高效率，但会降低可移植性；用 `--posix` 检查边界。
- 性能瓶颈通常在主循环里的外部命令和字符串拼接，不在 awk 本身。
- `--lint`、`--debug`、`--profile` 是主要的调试工具。
- 复杂 CSV、嵌套结构、长期维护的脚本，优先用 Python。

### 练习

- 把 `salary-sum.awk` 改成可执行脚本，加 shebang，直接运行。
- 写一个脚本，用 `-v` 接收部门名，只统计该部门的平均薪资。
- 用 `gawk --posix` 运行一个用了 `gensub` 的脚本，观察报错并改成 `gsub`。
- 用 `--lint` 检查一个引用未初始化变量的脚本，修掉警告。
- 用 `time` 比较单字符 `FS` 和正则 `FS` 处理同一份数据的差异（数据量小时差异可能不明显）。
- 列出你当前项目里适合 awk 和适合 Python 的任务各一个，说明判断依据。

<details>
<summary>参考答案</summary>

可执行脚本：

```awk
#!/usr/bin/env -S gawk -f
BEGIN { FS = "\t" }
NR > 1 { total += $4 }
END { printf "total=%d\n", total }
```

```shell
chmod +x salary-sum.awk
./salary-sum.awk examples/data/employees.tsv
```

按部门统计：

```shell
gawk -v dept=Engineering -F '\t' '
NR > 1 && $3 == dept { n++; sum += $4 }
END { if (n) printf "%s %.2f\n", dept, sum / n; else print "no data" }
' examples/data/employees.tsv
```

`--posix` 与 `gensub`：

```shell
gawk --posix 'BEGIN { print gensub(/a/, "b", "g", "aaa") }'
```

会报 `function 'gensub' not defined`。改成：

```shell
gawk 'BEGIN { s = "aaa"; gsub(/a/, "b", s); print s }'
```

`--lint`：

```shell
gawk --lint 'BEGIN { print total + 1 }'
```

会提示 `total` 未初始化；在 `BEGIN` 里写 `total = 0`。

性能比较要用真实规模的数据，小文件主要测的是启动开销。单字符 `FS` 通常更快，但差异是否明显取决于字段数和文件大小。

适合 awk：日志按状态码计数、TSV 按列筛选。适合 Python：带引号和换行的 CSV、JSON API 响应处理。

</details>
