## getline 与输入输出

主循环负责读“主输入”，但实际任务经常需要额外的输入：从一个配置文件查表、读取另一个文件的某一行、执行命令并捕获输出。`getline` 就是 awk 的“第二条输入通道”。它灵活，也容易把 `NR`、`$0` 和字段搞乱；这一篇把六种形式分开讲清楚。

### 六种形式

`getline` 有两种来源（主输入、文件/命令）和两种落点（`$0`、变量），组合成六种形式：

| 形式 | 设置 `$0`/`NF` | 设置 `NR`/`FNR` | 典型用途 |
| --- | --- | --- | --- |
| `getline` | 是 | 是 | 从主输入预读下一条记录 |
| `getline var` | 否 | 是 | 预读下一条记录到变量 |
| `getline < file` | 是 | 否 | 从文件读下一条记录到 `$0` |
| `getline var < file` | 否 | 否 | 从文件读一行到变量 |
| <code>cmd &#124; getline</code> | 是 | 否 | 把命令输出的下一行读到 `$0` |
| <code>cmd &#124; getline var</code> | 否 | 否 | 把命令输出的下一行读到变量 |

返回值统一是：

- `1`：读取成功。
- `0`：到达文件末尾或命令没有更多输出。
- `-1`：出错，例如文件不存在、权限不足。

**必须检查 `> 0`，不能只写 `while (getline ...)`**，因为 `-1` 在 awk 里是真，错误会被当成成功，可能导致死循环。

### 从主输入预读

`getline` 不带参数时，读下一条主输入记录到 `$0`，同时更新 `NF`、`NR`、`FNR`：

```shell
$ printf 'a\nb\nc\n' | awk '{ print "main", $0; if (getline > 0) print "extra", $0; print "NR", NR }'
main a
extra b
NR 2
main c
NR 3
```

处理 `a` 时，`getline` 读走了 `b`，所以主循环下一次直接读 `c`。`b` 只以 `extra` 的形式出现一次。

`getline var` 把读到的记录放进变量，不改变 `$0`/`NF`，但仍然增加 `NR`/`FNR`：

```shell
$ printf 'a\nb\n' | awk '{ getline x; print "main", $0, "var", x, "NR", NR }'
main a var b NR 2
```

`$0` 还是 `a`，`x` 是 `b`，`NR` 已经变成 2。

预读会跳过主循环对某些记录的处理，写统计时要特别小心。多数情况下，先想清楚“这条记录是否还需要进入后续规则”，再决定用不用 `getline`。

### 从文件读取

`getline < file` 把文件的下一行读到 `$0`，更新 `NF`，但**不改变 `NR`/`FNR`**：

```shell
$ printf 'x\ny\n' | awk '{ getline < "examples/data/team-a.tsv"; print "main", $0, "NR", NR, "NF", NF }'
main Alice	Engineering	120000 NR 1 NF 3
main Bob	Sales	90000 NR 2 NF 3
```

主输入只有 `x`、`y` 两行，但输出显示的是文件里的内容。`NR` 仍然是主输入的记录号，所以第一行是 1，第二行是 2。

`getline var < file` 只把内容放进变量，不影响 `$0`/`NF`/`NR`：

```shell
$ printf 'x\ny\n' | awk '{ getline v < "examples/data/team-a.tsv"; print "main", $0, "var", v, "NR", NR, "NF", NF }'
main x var Alice	Engineering	120000 NR 1 NF 1
main y var Bob	Sales	90000 NR 2 NF 1
```

这个形式最适合“读一行查表/读配置”，因为它不破坏当前记录的字段。

### 从命令读取

`cmd | getline` 执行 shell 命令，把输出的下一行读到 `$0`，更新 `NF`，不改变 `NR`/`FNR`：

```shell
$ awk 'BEGIN { "echo hello world" | getline; print "[" $0 "]", NF, NR; close("echo hello world") }'
[hello world] 2 0
```

`cmd | getline var` 把输出读到变量：

```shell
$ awk 'BEGIN { "echo hello" | getline x; print "[" x "]"; close("echo hello") }'
[hello]
```

读取多行要循环：

```shell
$ awk 'BEGIN { while (("echo 1; echo 2; echo 3" | getline line) > 0) print line; close("echo 1; echo 2; echo 3") }'
1
2
3
```

`close(command)` 关闭管道，返回值是命令的退出状态：

```shell
$ awk 'BEGIN { "exit 3" | getline x; print "close", close("exit 3") }'
close 3
```

`cmd | getline` 依赖 shell，命令字符串会被 shell 解释。**不要把未经验证的用户输入拼进命令**，否则会有命令注入风险。

### close 与重复读取

文件或管道在第一次使用后保持打开，后续 `getline` 从上次位置继续。需要从头读取或重新执行命令时，先 `close()`：

```shell
$ awk 'BEGIN {
  getline a < "examples/data/team-a.tsv"
  close("examples/data/team-a.tsv")
  getline b < "examples/data/team-a.tsv"
  print a
  print b
  close("examples/data/team-a.tsv")
}'
Alice	Engineering	120000
Alice	Engineering	120000
```

不 `close` 时，第二次 `getline` 会读到第二行，而不是第一行。这个行为常被误认为“文件被缓存了”。

### 读到文件末尾

```shell
$ awk 'BEGIN {
  r = getline x < "examples/data/team-a.tsv"; print r
  r = getline y < "examples/data/team-a.tsv"; print r
  r = getline z < "examples/data/team-a.tsv"; print r
  close("examples/data/team-a.tsv")
}'
1
1
0
```

`team-a.tsv` 有两行，第三次读取返回 0。如果文件不存在，返回 -1，并设置 `ERRNO`（GNU）：

```shell
$ awk 'BEGIN { r = getline x < "/no/such/file"; print r, ERRNO }'
-1 No such file or directory
```

`ERRNO` 是 **GNU** 扩展，错误文本依赖系统和 locale。脚本里不要依赖具体文本，按返回值判断即可。

### ARGV、ARGC 与 ARGIND

`ARGV` 是命令行参数数组，`ARGC` 是参数个数，`ARGV[0]` 通常是 `awk`：

```shell
$ awk 'BEGIN { for (i = 0; i < ARGC; i++) print i, ARGV[i] }' examples/data/team-a.tsv examples/data/team-b.tsv
0 awk
1 examples/data/team-a.tsv
2 examples/data/team-b.tsv
```

`ARGIND` 是当前文件在 `ARGV` 中的下标（GNU 扩展）：

```shell
$ awk '{ print ARGIND, FILENAME, $1 }' examples/data/team-a.tsv examples/data/team-b.tsv
1 examples/data/team-a.tsv Alice
1 examples/data/team-a.tsv Bob
2 examples/data/team-b.tsv Carol
2 examples/data/team-b.tsv Dave
```

修改 `ARGV` 可以跳过文件，但要在主循环开始前做。初学阶段少用这种技巧，直接给对文件名更清楚。

### system

`system(command)` 执行命令，返回退出状态；命令输出直接到 awk 的标准输出，不会被捕获：

```shell
$ awk 'BEGIN { status = system("echo from-shell"); print "status", status }'
from-shell
status 0

$ awk 'BEGIN { status = system("exit 3"); print "status", status }'
status 3
```

需要捕获输出用 `cmd | getline`；需要执行副作用（创建文件、调用外部工具）用 `system`。两者都经过 shell，都有注入风险。

### 实战：读配置

下面的程序在 `BEGIN` 里读取 `config.ini`，按节打印键值：

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
    print section, key, val
  }
  close("examples/data/config.ini")
}
'
server host 127.0.0.1
server port 8080
client retries 3
client timeout 30
```

这段程序展示了几个组合：

- `getline line < file` 逐行读取文件。
- `^[[:space:]]*[;#]` 跳过注释，`^[[:space:]]*$` 跳过空行。
- `^\[` 进入新节，`gsub` 去掉方括号。
- `split(line, kv, "=")` 拆键值，再 `gsub` 去掉两端空格。

配置格式千差万别，这个解析器只适用于“简单的 INI，值里没有等号”的情况。复杂配置用专用解析器。

### 实战：用 getline 做查表

把库存文件读进数组，再处理订单：

```shell
$ awk -F '\t' '
BEGIN {
  while ((getline line < "examples/data/inventory.tsv") > 0) {
    split(line, f, "\t")
    if (f[1] == "sku") continue
    stock[f[1]] = f[4]
  }
  close("examples/data/inventory.tsv")
}
FNR > 1 { print $1, $2, $3, ($2 in stock ? stock[$2] : "MISSING") }
' examples/data/orders.tsv
1001 A-100 3 42
1002 B-200 10 75
1003 C-300 1 12
1004 A-101 5 18
1005 B-200 2 75
1006 E-500 4 MISSING
1007 A-100 7 42
1008 D-400 6 55
```

如果两个文件都是普通文件，用 `NR == FNR` 的两文件模式更简单：

```shell
awk -F '\t' 'NR == FNR { stock[$1] = $4; next } FNR > 1 { ... }' inventory.tsv orders.tsv
```

`getline` 的优势在于：

- 可以在 `BEGIN` 里读查表，主输入只保留一个文件。
- 可以读取命令输出或非文件来源。
- 可以精确控制读取位置和关闭时机。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 死循环 | `while (getline ...)` 把 -1 当成真 | 写 `> 0` |
| `NR` 不对 | 用文件/管道 `getline` 却以为会更新 `NR` | 文件/管道形式不更新 `NR` |
| 字段被覆盖 | 用了 `getline` 而不是 `getline var` | 需要保留当前记录时用变量形式 |
| 重复读取从头开始失败 | 没有 `close` | 读完或重新读前 `close(file)` |
| 命令没有输出 | 命令还在运行，或没有 `close` | `close(command)` 等待结束 |
| `ERRNO` 为空 | 用了非 GNU awk | 只按返回值判断 |
| 配置文件值被截断 | `split` 按 `=` 拆，值里还有 `=` | 用 `index` 找第一个等号，或换解析器 |
| 命令注入 | 把用户输入拼进 `system` 或 <code>cmd &#124; getline</code> | 固定命令，参数走文件或环境变量，严格校验 |

### 小结

- `getline` 有六种形式，区别在于来源和落点。
- 主输入形式更新 `NR`/`FNR`，文件和命令形式不更新。
- 不带变量的形式会覆盖 `$0`/`NF`；需要保留当前记录时用 `getline var`。
- 返回值 1/0/-1，循环条件写 `> 0`。
- `close()` 关闭文件或管道，管道关闭时返回命令退出状态。
- `ARGV`/`ARGC`/`ARGIND` 用于处理文件参数和当前文件。
- `system()` 执行命令但不捕获输出；`cmd | getline` 捕获输出。
- 命令字符串经过 shell，未验证输入会带来注入风险。

### 练习

- 用 `getline var < file` 读取 `examples/data/team-a.tsv` 的两行，打印到标准输出。
- 用 `getline` 从主输入预读一行，观察 `NR` 和 `$0` 的变化。
- 用 `cmd | getline` 捕获 `date +%Y-%m-%d` 的输出并打印。
- 用 `while ((getline line < file) > 0)` 统计 `examples/data/poem.txt` 的行数。
- 用 `system()` 执行 `echo hello`，检查退出状态。
- 用 `getline` 在 `BEGIN` 里读取 `inventory.tsv`，然后处理 `orders.tsv`，输出缺失的 SKU。
- 解释为什么 `while (getline line < file)` 在文件不存在时可能死循环。

<details>
<summary>参考答案</summary>

读取两行：

```shell
awk 'BEGIN {
  while ((getline line < "examples/data/team-a.tsv") > 0) print line
  close("examples/data/team-a.tsv")
}'
```

预读：

```shell
printf 'a\nb\nc\n' | awk '{ print "main", $0, NR; if (getline > 0) print "extra", $0, NR }'
```

捕获日期：

```shell
awk 'BEGIN { "date +%Y-%m-%d" | getline d; print d; close("date +%Y-%m-%d") }'
```

统计行数：

```shell
awk 'BEGIN { n = 0; while ((getline line < "examples/data/poem.txt") > 0) n++; close("examples/data/poem.txt"); print n }'
```

`system`：

```shell
awk 'BEGIN { status = system("echo hello"); print "status", status }'
```

缺失 SKU：

```shell
awk -F '\t' '
BEGIN {
  while ((getline line < "examples/data/inventory.tsv") > 0) {
    split(line, f, "\t")
    if (f[1] != "sku") stock[f[1]] = 1
  }
  close("examples/data/inventory.tsv")
}
FNR > 1 && !($2 in stock) { print $1, $2 }
' examples/data/orders.tsv
```

文件不存在时 `getline` 返回 -1，而 `-1` 在 awk 里为真，`while (getline ...)` 会一直成立；必须写 `> 0`。

</details>
