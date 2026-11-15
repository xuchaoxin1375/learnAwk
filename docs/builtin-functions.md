## 内置函数

awk 自带一批字符串、数学和时间函数。它们让很多任务不需要外部命令：截取字段、清理文本、格式化数字、生成日期都能在 awk 里完成。这一篇按用途分组介绍常用函数，重点讲返回值、边界和容易混淆的地方。

### 字符串函数

| 函数 | 作用 | 返回 |
| --- | --- | --- |
| `length(s)` | 字符串长度 | 数字；省略参数时为 `$0` 的长度 |
| `substr(s, start, len)` | 从 start 开始取 len 个字符 | 子串；len 可省略 |
| `index(s, t)` | t 在 s 中第一次出现的位置 | 1 开始的数字；找不到为 0 |
| `split(s, a, sep)` | 按 sep 拆分 s | 字段数；结果在 a 中 |
| `sub(re, repl, target)` | 替换第一个匹配 | 替换次数 |
| `gsub(re, repl, target)` | 替换所有匹配 | 替换次数 |
| `match(s, re)` | 查找第一个匹配 | 起始位置；RSTART/RLENGTH 被设置 |
| `tolower(s)`、`toupper(s)` | 转小写、大写 | 新字符串 |
| `sprintf(fmt, ...)` | 按格式生成字符串 | 字符串，不输出 |
| `gensub(re, repl, how, s)` | 替换并支持反向引用（GNU） | 新字符串 |

#### length、substr、index

```shell
$ awk 'BEGIN {
  s = "hello world"
  print length(s)
  print substr(s, 1, 5)
  print substr(s, 7)
  print index(s, "world")
  print index(s, "xyz")
}'
11
hello
world
7
0
```

`substr` 的下标从 1 开始，`substr(s, 7)` 从第 7 个字符取到末尾。起始位置超过字符串长度时返回空字符串：

```shell
$ awk 'BEGIN { print "[" substr("abc", 5) "]" }'
[]
```

`index` 找不到时返回 0，不会报错。需要“包含”判断时，`index(s, t) > 0` 比正则更直接。

#### tolower、toupper

```shell
$ awk 'BEGIN { print tolower("Hello WORLD"); print toupper("Hello world") }'
hello world
HELLO WORLD
```

它们受 locale 影响。处理非 ASCII 文本时，确认 locale 支持相应字符的大小写转换。确定性脚本可以显式设置 `LC_ALL=C`，但那样只会转换 ASCII。

#### split

```shell
$ awk 'BEGIN { n = split("a:b:c", p, ":"); print n, p[1], p[3] }'
3 a c
```

`split` 的第三个参数可以是字符串或正则。省略时使用 `FS`。它在[关联数组](arrays.md)里已经用于日期解析，这里只补充返回值：拆分结果为空时返回 0，数组元素不会被创建。

#### sub、gsub

```shell
$ awk 'BEGIN { s = "a-b-c"; n = sub(/-/, "+", s); print s, n; n = gsub(/-/, "+", s); print s, n }'
a+b-c 1
a+b+c 1
```

- `sub` 只替换第一个匹配。
- `gsub` 替换所有匹配。
- 第三个参数省略时，默认修改 `$0`。
- 返回值是替换次数，不是新字符串。

替换文本中的 `&` 表示整个匹配：

```shell
$ awk 'BEGIN { s = "abc"; sub(/b/, "[&]", s); print s }'
a[b]c
```

要写字面 `&`，用 `\&`：

```shell
$ awk 'BEGIN { s = "abc"; sub(/b/, "[\\&]", s); print s }'
a[&]c
```

**修改 `$0` 会重新拆分字段**。如果先按冒号拆字段，再用 `gsub` 替换冒号，后续字段访问会按 `FS` 重新拆分：

```shell
$ printf 'a:b:c\n' | awk -F ':' '{ gsub(/:/, "-"); print $0; print NF }'
a-b-c
1
```

原来的 3 个字段变成了 1 个，因为 `$0` 被修改后，awk 按 `FS=":"` 重新拆分，而新的 `$0` 里已经没有冒号。需要保留字段时，先处理字段或把结果存到变量，不要直接改 `$0`。

#### match

```shell
$ awk 'BEGIN { s = "date=2026-01-05"; print match(s, /[0-9]{4}-[0-9]{2}-[0-9]{2}/), RSTART, RLENGTH }'
6 6 10
```

`match` 返回起始位置，并设置 `RSTART` 和 `RLENGTH`。找不到时返回 0，`RSTART` 为 0，`RLENGTH` 为 -1：

```shell
$ awk 'BEGIN { print match("abc", /z/), RSTART, RLENGTH }'
0 0 -1
```

GNU awk 支持第三个参数，把捕获组放进数组：

```shell
$ echo '2026-01-05' | awk '{ match($0, /([0-9]{4})-([0-9]{2})-([0-9]{2})/, m); print m[0], m[1], m[2], m[3] }'
2026-01-05 2026 01 05
```

`m[0]` 是整个匹配，`m[1]` 起是括号组。POSIX awk 只支持两个参数，需要捕获时用 `substr` 配合 `RSTART`/`RLENGTH`，或者换工具。

#### sprintf

`sprintf` 按格式生成字符串，不直接输出：

```shell
$ awk 'BEGIN { s = sprintf("%05d", 42); print s, length(s) }'
00042 5
```

常见用途：

- 给编号补零：`sprintf("%05d", id)`。
- 生成固定宽度报表：`sprintf("%-10s %8.2f", name, amount)`。
- 拼接文件名：`sprintf("out-%03d.csv", n)`。
- 把数字转成固定小数位后再比较或输出。

`sprintf` 的格式规则和 `printf` 相同，完整表格在[格式化输出](printf-output.md)里。

#### gensub

`gensub` 是 **GNU** 扩展，返回替换后的新字符串，不修改原字符串：

```shell
$ awk 'BEGIN { print gensub(/([a-z]+)-([a-z]+)/, "\\2-\\1", 1, "foo-bar") }'
bar-foo
```

第三个参数是 `1` 表示只替换第一个匹配，`"g"` 表示替换全部，`"G"` 也表示全部。替换文本里的 `\1`、`\2` 引用捕获组，在 awk 字符串里写成 `"\\1"`。需要原地修改时，把返回值赋回去：

```awk
s = gensub(/re/, "repl", "g", s)
```

### 数学函数

| 函数 | 作用 |
| --- | --- |
| `int(x)` | 向零截断取整 |
| `sqrt(x)` | 平方根 |
| `exp(x)` | e 的 x 次方 |
| `log(x)` | 自然对数 |
| `sin(x)`、`cos(x)` | 正弦、余弦（弧度） |
| `atan2(y, x)` | y/x 的反正切 |
| `rand()` | 0 到 1 之间的伪随机数 |
| `srand(seed)` | 设置随机种子，返回旧种子 |

```shell
$ awk 'BEGIN { print int(3.9), int(-3.9), sqrt(16), 2 ^ 3 }'
3 -3 4 8
```

`int` 是向零截断，不是四舍五入。四舍五入可以写 `int(x + 0.5)`（正数），负数要单独处理。

随机数：

```shell
$ awk 'BEGIN { srand(1); print rand(); print rand(); srand(1); print rand() }'
0.924046
0.593909
0.924046
```

同一个种子产生同一串伪随机数，适合测试。`rand()` 不是密码学安全的随机数，不要用于安全场景。

### 时间函数

GNU awk 提供三个时间函数：

| 函数 | 作用 |
| --- | --- |
| `systime()` | 当前时间戳（秒） |
| `strftime(format, timestamp)` | 按格式输出时间 |
| `mktime("YYYY MM DD HH MM SS")` | 把时间转成时间戳（GNU） |

用 `TZ=UTC` 让结果可复现：

```shell
$ TZ=UTC awk 'BEGIN { print strftime("%Y-%m-%d %H:%M:%S", 0); print mktime("2026 01 05 00 00 00") }'
1970-01-01 00:00:00
1767571200
```

`strftime` 的格式和 C 的 `strftime` 类似，常用占位符：

| 占位符 | 含义 |
| --- | --- |
| `%Y` | 四位年份 |
| `%m` | 两位月份 |
| `%d` | 两位日期 |
| `%H`、`%M`、`%S` | 时、分、秒 |
| `%s` | Unix 时间戳（部分实现支持） |
| `%F` | `%Y-%m-%d`（部分实现支持） |

`mktime` 的参数用空格分隔，月份和日期从 1 开始。时间戳依赖时区，跨时区处理时显式设置 `TZ`。

### GNU 扩展与其他

**strtonum** 把字符串转成数字，支持十六进制和八进制：

```shell
$ awk 'BEGIN { print strtonum("42"), strtonum("0x1f"), strtonum("077") }'
42 31 63
```

**isarray** 和 **typeof** 用于检查类型：

```shell
$ awk 'BEGIN { a["x"] = 1; print isarray(a), isarray(1); print typeof(a), typeof(1), typeof("x") }'
1 0
array number string
```

**位运算**：`and`、`or`、`xor`、`compl`、`lshift`、`rshift` 是 GNU 扩展：

```shell
$ awk 'BEGIN { print and(6, 3), or(6, 3), xor(6, 3), lshift(1, 3), rshift(8, 2) }'
2 7 5 8 2
```

这些函数适合权限位、掩码和底层格式处理。普通文本处理很少用到。

**length 数组**：GNU awk 的 `length(array)` 返回元素个数，POSIX awk 不支持。

### 函数与副作用

大多数内置函数返回新值，不修改参数：`length`、`substr`、`index`、`tolower`、`toupper`、`sprintf`、`gensub`、数学和时间函数。

会修改参数的函数：

- `sub`、`gsub` 修改第三个参数；省略时修改 `$0`。
- `split` 修改第二个参数（数组）。
- `match` 修改 `RSTART`/`RLENGTH`，GNU 版本还修改第三个参数数组。
- `srand` 修改随机数种子。

需要保留原值时，先复制到变量，或使用不修改参数的版本（如 `gensub`）。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| `substr` 结果少一个字符 | 下标从 0 开始想错了 | awk 从 1 开始 |
| `index` 返回 0 被当成位置 0 | 0 表示“没找到” | 用 `> 0` 判断存在 |
| `gsub` 后字段数变了 | 修改 `$0` 触发重新拆分 | 处理字段或保存到变量 |
| `sub` 的 `&` 输出了原匹配 | `&` 在替换文本里是特殊符号 | 字面 `&` 写 `\&` |
| `gensub` 报错 | 用了 POSIX awk | 确认是 GNU awk，或用 `sub`/`gsub` |
| `match` 捕获数组为空 | 用了两参数版本 | 用 GNU 三参数版本 |
| `rand()` 每次一样 | 没有 `srand()`，或固定了种子 | 需要变化时调用 `srand()` |
| `mktime` 返回 -1 | 日期格式不对或日期不存在 | 用 `"YYYY MM DD HH MM SS"`，检查月份/日期 |
| UTF-8 长度不对 | locale 按字节 | 设置 `LC_ALL=C.UTF-8` |

### 小结

- `length`、`substr`、`index` 处理长度和位置，下标从 1 开始。
- `split` 把字符串拆成数组，返回字段数。
- `sub`/`gsub` 替换并返回次数，默认修改 `$0`；修改 `$0` 会重新拆分字段。
- `match` 设置 `RSTART`/`RLENGTH`，GNU 版本支持捕获组。
- `sprintf` 生成格式化字符串，不输出。
- `int` 向零截断，`rand`/`srand` 用于伪随机数。
- `strftime`/`mktime` 处理时间，`TZ` 决定时区。
- `gensub`、`strtonum`、`isarray`、`typeof`、位运算是 GNU 扩展。

### 练习

- 从 `examples/data/poem.txt` 中取出每行的前 10 个字符。
- 统计每个单词的长度，输出最长的单词。
- 把 `examples/data/employees.tsv` 的姓名转成大写，薪资格式化成两位小数。
- 用 `split` 把 `2026-01-05` 拆成三个字段，并输出 `05/01/2026`。
- 用 `match` 提取 `access.log` 中的状态码，打印 `RSTART` 和 `RLENGTH`。
- 用 `sprintf` 生成 `report-001.csv` 到 `report-005.csv` 这样的文件名。
- 用 `strftime` 输出当前日期，格式为 `YYYY-MM-DD`。

<details>
<summary>参考答案</summary>

前 10 个字符：

```shell
awk '{ print substr($0, 1, 10) }' examples/data/poem.txt
```

最长单词：

```shell
awk '{
  for (i = 1; i <= NF; i++) {
    w = $i
    gsub(/[^A-Za-z]/, "", w)
    if (length(w) > max) { max = length(w); best = w }
  }
}
END { print best, max }' examples/data/poem.txt
```

姓名大写、薪资两位小数：

```shell
awk -F '\t' 'NR > 1 { printf "%s %.2f\n", toupper($2), $4 }' examples/data/employees.tsv
```

日期重排：

```shell
echo '2026-01-05' | awk '{ split($0, d, "-"); print d[3] "/" d[2] "/" d[1] }'
```

状态码位置：

```shell
awk '{ match($0, / [0-9]{3} /); print RSTART, RLENGTH, substr($0, RSTART + 1, 3) }' examples/data/access.log
```

`sprintf` 文件名：

```shell
awk 'BEGIN { for (i = 1; i <= 5; i++) print sprintf("report-%03d.csv", i) }'
```

当前日期：

```shell
awk 'BEGIN { print strftime("%Y-%m-%d", systime()) }'
```

</details>
