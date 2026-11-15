## 排错与常见陷阱

awk 的错误信息通常指向程序或输入，但根因可能在 shell 引号、locale、字段分隔符或文件编码。这一篇按“症状 → 原因 → 诊断 → 修复”组织，遇到问题时先查这里，再回到对应章节补概念。

### 先做四件事

遇到不按预期工作的命令，按这个顺序缩小范围：

- **确认实现和版本**：`gawk --version` 或 `awk --version`，输出里是否含 `GNU Awk`。
- **用最小输入复现**：把文件换成一两行 `printf` 数据，排除数据和路径因素。
- **打印中间变量**：在程序里输出 `NR`、`NF`、`FS`、`$0`、`$1`，看 awk 实际看到什么。
- **用 `--lint` 和 `--posix` 各跑一次**：前者找可疑写法，后者检查可移植性。

```shell
printf 'a,b\n' | awk -F ',' '{ print NR, NF, "[" $0 "]", "[" $1 "]" }'
```

如果最小输入正常，问题多半在文件、编码、多文件或数据处理逻辑；如果最小输入也不正常，问题在程序本身。

### 引号与 shell 展开

**症状**：命令没有按预期输出，或者 shell 提示继续输入。

**原因**：awk 程序没有用单引号包住，`$1` 被 shell 展开；或者单引号没有闭合。

```shell
# 错误：双引号让 shell 展开 $1
awk "{ print $1 }" examples/data/employees.tsv
```

在 bash 里 `$1` 是位置参数，通常是空，awk 看到的程序变成 `{ print  }`。

**修复**：用单引号包住程序。

```shell
awk '{ print $1 }' examples/data/employees.tsv
```

如果程序里需要 shell 变量，明确拼接，而不是依赖双引号：

```shell
threshold=100000
awk -v limit="$threshold" -F '\t' '$4 > limit { print $2 }' examples/data/employees.tsv
```

**症状**：终端出现 `>` 提示符，命令不执行。

**原因**：单引号或双引号没有配对。

**修复**：按 `Ctrl+C` 取消，检查引号数量。复杂程序写成 `.awk` 文件，用 `-f` 运行，能避免大部分 shell 引号问题。

### 找不到文件或权限不足

**症状**：

```shell
awk: fatal: cannot open file `/no/such/file' for reading: No such file or directory
```

**原因**：路径拼错、文件不在当前目录、没有读权限，或者把选项当成了文件名。

**诊断**：

```shell
pwd
ls -l examples/data/employees.tsv
```

**修复**：用绝对路径或确认工作目录；文件名以 `-` 开头时用 `--` 结束选项：

```shell
awk '{ print }' -- -weird-name.txt
```

从标准输入读时用 `-`：

```shell
printf 'a b\n' | awk '{ print $2 }' -
```

### 语法错误：缺括号、缺引号

**症状**：

```shell
$ awk 'BEGIN { if (1) { print "x" }'
awk: cmd. line:1: BEGIN { if (1) { print "x" }
awk: cmd. line:1:                             ^ unexpected newline or end of string
```

**原因**：花括号、圆括号或引号没有配对。

**修复**：把程序写成多行，按缩进对齐，再检查括号。`gawk --lint` 也会给出位置提示。

### FS 设置太晚

**症状**：按逗号或冒号拆分，但 `$1` 是整行，`NF` 是 1。

```shell
$ printf 'a:b\n' | awk '{ FS = ":"; print NF, $1 }'
1 a:b
```

**原因**：记录读入时已经按旧的 `FS` 拆分，动作里再改 `FS` 只影响下一条记录。

**修复**：用 `-F` 或 `BEGIN`：

```shell
printf 'a:b\n' | awk -F ':' '{ print NF, $1 }'
printf 'a:b\n' | awk 'BEGIN { FS = ":" } { print NF, $1 }'
```

### 表头被当成数据

**症状**：筛选 `$4 > 100000` 时，表头 `name salary` 也出现了。

**原因**：表头的 `$4` 是字符串 `salary`，和数字比较时按字符串规则，可能为真。

**修复**：加 `NR > 1` 或 `FNR > 1`，或者强制数字比较：

```shell
awk -F '\t' 'NR > 1 && $4 > 100000 { print $2 }' examples/data/employees.tsv
awk -F '\t' 'NR > 1 && $4 + 0 > 100000 { print $2 }' examples/data/employees.tsv
```

多文件都带表头时用 `FNR > 1`，不要用 `NR > 1`。

### NR 与 FNR 混用

**症状**：处理多个文件时，第二个文件的表头没有被跳过，或者统计数从 1 开始而不是累计。

**原因**：`NR` 跨文件累计，`FNR` 每个文件重置。

**诊断**：

```shell
awk -F '\t' '{ print FILENAME, FNR, NR, $1 }' examples/data/team-a.tsv examples/data/team-b.tsv
```

**修复**：跳过每个文件的表头用 `FNR > 1`；统计总数用 `NR` 或自己的计数器。

### $NF 与 $(NF-1)

**症状**：想取倒数第二个字段，结果得到数字减 1。

```shell
$ printf 'a b c\n' | awk '{ print $NF - 1 }'
0
```

**原因**：`$NF - 1` 是“最后一个字段的值减 1”，不是“倒数第二个字段”。

**修复**：加括号：

```shell
printf 'a b c\n' | awk '{ print $(NF - 1) }'
```

输出 `b`。

### OFS 没有生效

**症状**：设置了 `OFS="|"`，但 `print` 还是原来的分隔符。

**原因**：没有修改任何字段，`$0` 没有重建；`OFS` 只在重建记录或 `print a, b` 时使用。

**修复**：

```shell
# 修改字段触发重建
awk -F '\t' 'BEGIN { OFS = "|" } { $1 = $1; print }' examples/data/employees.tsv

# 或者显式用逗号输出
awk -F '\t' 'BEGIN { OFS = "|" } { print $1, $2 }' examples/data/employees.tsv
```

`$1 = $1` 是一个常见技巧：给字段赋原值，强制重建 `$0`。

### 修改 $0 后字段变了

**症状**：用 `gsub` 修改 `$0` 后，`NF` 变化，`$2` 变空。

**原因**：修改 `$0` 会按 `FS` 重新拆分字段。

```shell
$ printf 'a:b:c\n' | awk -F ':' '{ gsub(/:/, "-"); print NF, $2 }'
1
```

**修复**：先处理字段，或把结果存到变量；不要在需要保留字段时直接改 `$0`：

```shell
printf 'a:b:c\n' | awk -F ':' '{ out = $0; gsub(/:/, "-", out); print out; print $2 }'
```

### 正则斜杠与反斜杠

**症状**：`/api/` 报语法错误，或者 `\.` 匹配了任意字符。

**原因**：正则字面量用 `/` 包围，字面斜杠要写 `\/`；点号要写 `\.`；动态正则的字符串要多一层转义。

**修复**：

```shell
awk '$7 ~ /^\/api\// { print $7 }' examples/data/access.log
printf 'a.b\n' | awk '/a\.b/ { print }'
```

动态正则先用 `-v` 传入并打印确认：

```shell
awk -v pat='^Eng' -F '\t' '$3 ~ pat { print $2 }' examples/data/employees.tsv
```

`\d`、`\b` 这类 Perl 写法不是 POSIX ERE 的标准；用 `[0-9]`、`[[:digit:]]` 或 GNU 的 `\y`，并确认目标实现支持。

### 字符串和数字比较

**症状**：`$4 > 100000` 对某些行结果不对，或者 `"10" > 9` 为假。

**原因**：普通字符串和数字比较时按字符串规则；输入字段是 `strnum` 时按数值。表头、配置值、手工拼接的字符串可能不是 `strnum`。

**修复**：强制转换，或显式比较：

```shell
awk -F '\t' 'NR > 1 && $4 + 0 > 100000 { print $2 }' examples/data/employees.tsv
```

需要字符串比较时，拼接空字符串：

```shell
printf '010\n' | awk '{ if ($1 "" == "010") print "leading zero kept" }'
```

### 数组顺序每次不同

**症状**：`for (k in a)` 的输出顺序不稳定，测试偶尔失败。

**原因**：关联数组的遍历顺序未定义。

**修复**：用 `sort`、`PROCINFO["sorted_in"]` 或 `asorti`：

```shell
awk '{ count[$1]++ } END { for (ip in count) print count[ip], ip }' examples/data/access.log | sort -k1,1nr -k2,2
```

```shell
awk '{ count[$9]++ } END { PROCINFO["sorted_in"] = "@ind_num_asc"; for (s in count) print s, count[s] }' examples/data/access.log
```

第二种是 GNU 扩展。

### printf 没有换行或参数不够

**症状**：输出全部粘在一行，或者报：

```shell
awk: cmd. line:1: fatal: not enough arguments to satisfy format string
```

**原因**：`printf` 不自动换行；格式串的转换数量多于参数。

**修复**：格式串末尾加 `\n`，并检查参数个数：

```shell
awk 'BEGIN { printf "%s %d\n", "x", 1 }'
```

需要输出字面百分号时写 `%%`。

### 输出重定向的歧义

**症状**：`print $1 > "out.txt"` 没有写文件，或者 `print $1 > $2` 行为奇怪。

**原因**：`>` 在 awk 里既可能是重定向，也可能是比较，取决于上下文。文件名是表达式时更容易歧义。

**修复**：文件名表达式加括号，比较加括号：

```awk
print $1 > ("out/" $2 ".txt")
if ($1 > $2) print "greater"
```

### getline 死循环

**症状**：读不存在的文件时程序卡住。

**原因**：`while (getline line < file)` 把 -1 当成真。

**修复**：

```awk
while ((getline line < file) > 0) {
    print line
}
close(file)
```

文件/管道 `getline` 不更新 `NR`/`FNR`；需要保留当前记录时用 `getline var`。

### 管道和 system 的安全

**症状**：命令在 shell 里能跑，放进 awk 后结果不对，或者有注入风险。

**原因**：`system()` 和 `cmd | getline` 把字符串交给 shell 解释；引号、空格、分号、`$()` 都会生效。

**修复**：不要把未验证输入拼进命令；需要动态参数时，先严格校验，或改用文件/环境变量。捕获命令输出后检查返回值和 `close()` 状态：

```awk
cmd = "date +%Y-%m-%d"
if ((cmd | getline d) > 0) print d
close(cmd)
```

### UTF-8 长度不对

**症状**：`length("北京")` 返回 6，而不是 2。

**原因**：locale 按字节处理。

**修复**：

```shell
LC_ALL=C.UTF-8 awk 'BEGIN { print length("北京") }'
```

macOS 没有 `C.UTF-8` 时用 `LC_ALL=en_US.UTF-8`。只需要字节时用 `LC_ALL=C` 或 `gawk -b`。

### CRLF 与不可见字符

**症状**：字段末尾多了 `\r`，或者比较字符串时总是不相等。

**原因**：Windows 换行是 CRLF，某些平台上 `$0` 末尾会保留 `\r`。

**诊断**：

```shell
printf 'a\r\n' | awk '{ print length($0) }'
printf 'a\r\n' | awk '{ print "[" $0 "]" }' | od -c
```

**修复**：在读入时清理：

```awk
{ sub(/\r$/, "") }
```

或者统一文件的换行。仓库的 `.gitattributes` 已声明 LF，避免脚本和示例数据带 CRLF。

### 小数点和 locale

**症状**：`printf "%.2f"` 输出逗号，或者从 CSV 读到的 `3,14` 被当成两个字段。

**原因**：GNU awk 默认按点号解析和输出数字；显式使用 `-N`/`--use-lc-numeric` 后，才跟随 `LC_NUMERIC` 的小数点。加上这个选项且 locale 使用逗号时，`3.14` 会输出成 `3,14`，`3,14` 也可能被解析成两个值。

**修复**：数据处理时不要加 `-N`，或固定 `LC_ALL=C`：

```shell
LC_ALL=C awk -F ',' '{ printf "%.2f\n", $2 }' data.csv
```

需要按本地格式展示时，再在最后一步切换 locale，并明确使用 `-N`。

### GNU 扩展在别的 awk 上失败

**症状**：

```shell
gawk: cmd. line:1: fatal: function `gensub' not defined
```

或者 `asort`、`length(array)`、`BEGINFILE` 报错。

**原因**：用了 GNU 扩展，但运行的是 POSIX awk、mawk 或 BSD awk。

**修复**：

- 安装 GNU awk，脚本显式用 `gawk`。
- 用 `--posix` 测试，改成 POSIX 写法：
  - `gensub` → `sub`/`gsub` + `match`/`substr`。
  - `asort`/`asorti` → 输出到 `sort`。
  - `length(array)` → 循环计数。
  - `delete array` → 逐个 `delete a[k]`。
  - `BEGINFILE`/`ENDFILE` → 用 `FNR` 和文件名判断。

### 安全地原地修改

标准 awk 没有 `-i`。GNU awk 提供 `-i inplace` 扩展，但默认更推荐临时文件：

```shell
tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT
awk '{ sub(/foo/, "bar"); print }' input.txt > "$tmp" && mv "$tmp" input.txt
```

这样只有 awk 成功时才替换原文件；失败时原文件不变。需要备份时：

```shell
cp input.txt input.txt.bak
```

GNU awk 的原地扩展：

```shell
gawk -i inplace -v INPLACE_SUFFIX=.bak '{ sub(/foo/, "bar"); print }' input.txt
```

`INPLACE_SUFFIX=.bak` 会保留备份。`-i inplace` 依赖 gawk 的扩展模块，不是 POSIX 行为。

### 错误信息速查

| 错误信息 | 常见原因 | 处理 |
| --- | --- | --- |
| `unexpected newline or end of string` | 括号/引号没配对 | 检查程序结构，用 `--lint` |
| `cannot open file ... for reading` | 路径错、权限、选项当成文件 | 检查路径，用 `--` 结束选项 |
| `division by zero attempted` | 分母为 0 | 计算前判断分母 |
| `not enough arguments to satisfy format string` | `printf` 参数不足 | 对齐格式串和参数 |
| `function 'gensub' not defined` | 非 GNU awk 或 `--posix` | 换实现或改写法 |
| `multidimensional arrays are a gawk extension` | 用了 `a[i][j]` 且 `--posix` | 去掉 `--posix` 或改 `a[i,j]` |
| `reference to uninitialized variable` | 变量没初始化 | 在 `BEGIN` 初始化 |
| `next used in BEGIN action` | `next` 用在 `BEGIN`/`END` | 移到普通规则 |
| `getline` 返回 -1 | 文件不存在/权限 | 检查 `> 0` 和 `ERRNO` |

### 恢复与求助

- 修改前备份：`cp file file.bak`。
- 用临时文件 + `mv`，失败不覆盖原文件。
- 覆盖后先找备份、版本库历史、编辑器本地历史；不要在原文件上继续试错。
- 问题可复现时，准备最小输入、完整命令、`gawk --version`、locale 和错误信息，再去搜索或提问。
- 教程示例失败时，先运行 `bash scripts/verify.sh`，确认环境和数据完整。

### 小结

- 先确认 awk 实现和版本，再用最小输入复现。
- 引号、`FS` 时机、`NR`/`FNR`、表头和类型比较是最常见的根因。
- 数组顺序不确定，输出前用 `sort` 或 `PROCINFO`。
- `printf` 管格式，`print` 管 `OFS`/`ORS`；重定向文件名要加括号。
- `getline` 循环必须写 `> 0`，文件/管道形式不更新 `NR`。
- UTF-8、locale、CRLF 是跨平台脚本的常见坑。
- 原地修改优先用临时文件；`gawk -i inplace` 是扩展，不是标准。

### 练习

- 运行 `awk "{ print $1 }" examples/data/employees.tsv`，解释输出为什么不对，再改成正确写法。
- 用最小输入复现 `FS` 设置太晚的问题，并修复。
- 构造一个表头被误筛选的例子，用 `NR > 1` 和 `$4 + 0` 两种方式修复。
- 用 `--lint` 检查一个未初始化变量，修掉警告。
- 用临时文件安全地把 `examples/data/team-a.tsv` 的姓名转成大写，保留备份。
- 解释 `while (getline line < file)` 在文件不存在时为什么会死循环。

<details>
<summary>参考答案</summary>

双引号版本：

```shell
awk "{ print $1 }" examples/data/employees.tsv
```

shell 把 `$1` 展开为空，awk 收到 `{ print  }`，输出整行。正确写法是单引号：

```shell
awk '{ print $1 }' examples/data/employees.tsv
```

`FS` 太晚：

```shell
printf 'a:b\n' | awk '{ FS = ":"; print $1 }'
```

第一条记录已经按默认空白拆分。修复：

```shell
printf 'a:b\n' | awk 'BEGIN { FS = ":" } { print $1 }'
```

表头：

```shell
awk -F '\t' 'NR > 1 && $4 > 100000 { print $2 }' examples/data/employees.tsv
```

`--lint`：

```shell
gawk --lint 'BEGIN { print x + 1 }'
```

警告 `reference to uninitialized variable 'x'`，加 `x = 0`。

安全修改（在临时目录里做，不碰仓库数据）：

```shell
tmpdir=$(mktemp -d)
trap 'rm -rf "$tmpdir"' EXIT
cp examples/data/team-a.tsv "$tmpdir/team.tsv"
awk -F '\t' 'BEGIN { OFS = "\t" } { print toupper($1), $2, $3 }' "$tmpdir/team.tsv" > "$tmpdir/out.tsv" && mv "$tmpdir/out.tsv" "$tmpdir/team.tsv"
cat "$tmpdir/team.tsv"
```

这样练习不会改掉仓库里的示例数据；真实文件也按同样的“临时文件 + `mv`”流程处理。

`getline` 文件不存在返回 -1，`-1` 在 awk 里为真，循环继续；必须写 `while ((getline line < file) > 0)`。

</details>
