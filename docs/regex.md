## awk 的正则表达式

awk 的很多能力都建立在正则表达式上：`/pattern/`、`~`、`FS`、`split()`、`sub()`、`gsub()` 都使用同一套正则语法。这一篇讲清楚 awk 用的正则方言、怎么写、怎么读结果，以及最容易踩的转义陷阱。

awk 使用 **POSIX 扩展正则表达式**(Extended Regular Expression, ERE)。和基础正则相比，`+`、`?`、`|`、`()`、`{m,n}` 不需要反斜杠就是元字符。GNU awk 还在此基础上加了一些扩展，例如 `\y`、`\w`、`IGNORECASE` 和 `gensub()`。

### 两种写法：正则字面量与字符串

静态正则用斜杠包起来：

```awk
/Engineering/
$3 ~ /^Eng/
```

需要动态拼接时，用字符串：

```shell
$ awk -v pat='^Eng' -F '\t' '$3 ~ pat { print $2 }' examples/data/employees.tsv
Alice
Carol
Frank
Lisa
```

`pat` 是字符串变量，`$3 ~ pat` 把它当作正则解释。

两种写法的转义规则不同：

- 正则字面量 `/\./` 里，反斜杠直接交给正则引擎，`\.` 表示字面点号。
- 字符串 `"\\."` 先由 awk 的字符串转义处理，`\\` 变成一个反斜杠，正则引擎再看到 `\.`。
- 在 shell 里还要再经过一层引号处理。用单引号包住 awk 程序，通常最省心。

```shell
$ printf 'a.b\naxb\n' | awk '/a\.b/ { print "literal dot", $0 }'
literal dot a.b
```

只有 `a.b` 匹配；`axb` 不匹配，因为 `\.` 不是通配符。

### 元字符速查

| 写法 | 含义 | 例子 |
| --- | --- | --- |
| `.` | 任意一个字符 | `a.c` 匹配 `abc`、`a-c` |
| `*` | 前一项出现 0 次或多次 | `ab*c` 匹配 `ac`、`abc`、`abbc` |
| `+` | 前一项出现 1 次或多次 | `ab+c` 不匹配 `ac` |
| `?` | 前一项出现 0 次或 1 次 | `ab?c` 匹配 `ac`、`abc` |
| `{m,n}` | 前一项出现 m 到 n 次 | `[0-9]{2,4}` |
| `[...]` | 字符集合 | `[abc]`、`[0-9]` |
| `[^...]` | 排除集合 | `[^0-9]` |
| `^` | 记录或字符串的开头 | `^2026` |
| `$` | 记录或字符串的结尾 | `bash$` |
| `(...)` | 分组 | `(ab)+` |
| <code>&#124;</code> | 或 | <code>cat&#124;dog</code> |
| `\` | 转义下一个元字符 | `\.`、`\+` |

`|` 在表格里容易和 Markdown 表格分隔符冲突，实际写正则时直接写 `Sales|Support`，不要加反斜杠。

### 锚点

`^` 和 `$` 锚定整条记录（或 `match()` 处理的整个字符串），不是每一行内部：

```shell
$ printf 'api/users\nv1/api\n' | awk '/^api/ { print $0 }'
api/users
```

`/^api/` 只匹配以 `api` 开头的记录。`/api$/` 只匹配以 `api` 结尾的记录。默认 `$0` 不含记录分隔符，所以 `$` 匹配的是记录内容的末尾。

在 `[ ]` 里，`^` 表示排除，不是锚点：

```shell
$ printf 'a1 B2\n' | awk '/[[:digit:]]/ { print "digit", $0 }'
digit a1 B2
```

### 字符类

POSIX 字符类写在 `[[:name:]]` 里：

| 类 | 含义 |
| --- | --- |
| `[[:alnum:]]` | 字母和数字 |
| `[[:alpha:]]` | 字母 |
| `[[:blank:]]` | 空格和制表符 |
| `[[:digit:]]` | 数字 |
| `[[:lower:]]`、`[[:upper:]]` | 小写、大写字母 |
| `[[:space:]]` | 空白字符 |
| `[[:punct:]]` | 标点 |
| `[[:xdigit:]]` | 十六进制数字 |

例子：

```shell
$ printf 'a1\nab12\nabc123\n' | awk '/^[a-z]{2,3}[0-9]+$/ { print $0 }'
ab12
abc123
```

`^[a-z]{2,3}[0-9]+$` 要求整条记录由 2 到 3 个小写字母加至少一个数字组成。

`\d` 不是 POSIX ERE 的写法。要匹配数字，用 `[0-9]` 或 `[[:digit:]]`。GNU awk 可能把未知转义当作字面字符，结果往往不是你想要的意思。

### 分组与选择

括号用于分组，竖线表示“或”：

```shell
$ awk -F '\t' '$3 ~ /^(Sales|Support)$/ { print $2, $3 }' examples/data/employees.tsv
Bob Sales
Dave Support
Eve Sales
Grace Support
Ivan Sales
Ken Support
```

`^` 和 `$` 把匹配限制在整个字段，避免 `Sales` 匹配到 `SalesOps` 这样的值。

### 转义与斜杠

正则字面量用 `/` 包围，所以匹配字面斜杠要写 `\/`：

```shell
$ awk '$7 ~ /^\/api\// { print $1, $7, $9 }' examples/data/access.log
203.0.113.10 /api/orders 500
192.0.2.55 /api/orders 201
192.0.2.55 /api/orders 200
198.51.100.24 /api/users 500
192.0.2.55 /api/users 200
203.0.113.10 /api/orders 201
192.0.2.55 /api/orders 500
198.51.100.24 /api/users 200
203.0.113.77 /api/orders 201
198.51.100.24 /api/orders 200
203.0.113.10 /api/users 500
```

`$7` 是请求路径，`/^\/api\//` 表示“以 `/api/` 开头”。

常见转义对照：

| 想匹配 | 正则字面量 | 字符串写法 |
| --- | --- | --- |
| 点号 `.` | `/\./` | `"\\."` |
| 斜杠 `/` | `/\//` | `"\\/"` 或 `"/"` |
| 反斜杠 `\` | `/\\/` | `"\\\\"` |
| 左括号 `(` | `/\(/` | `"\\("` |
| 加号 `+` | `/\+/` | `"\\+"` |

字符串写法需要多一层转义，因为 awk 先处理字符串转义，再把结果交给正则引擎。**能写成字面量时就写字面量**，可以少一层错误。

### 匹配函数与 RSTART/RLENGTH

`match(s, re)` 在字符串 `s` 中找第一个匹配，返回起始位置（1 开始），找不到返回 0。匹配位置和长度同时写入 `RSTART` 和 `RLENGTH`：

```shell
$ echo 'date=2026-01-05;' | awk '{ match($0, /[0-9]{4}-[0-9]{2}-[0-9]{2}/); print RSTART, RLENGTH, substr($0, RSTART, RLENGTH) }'
6 10 2026-01-05
```

`date=` 占 5 个字符，所以匹配从第 6 个字符开始，长度 10。

GNU awk 的 `match()` 支持第三个参数，把捕获组放进数组：

```shell
$ echo '2026-01-05' | awk '{ if (match($0, /([0-9]{4})-([0-9]{2})-([0-9]{2})/, m)) print m[1], m[2], m[3] }'
2026 01 05
```

`m[0]` 是整个匹配，`m[1]` 到 `m[3]` 是三个括号组。这是 **GNU** 扩展，POSIX awk 只支持两个参数。

### 替换：sub、gsub 与 gensub

`sub(re, repl)` 替换第一个匹配，`gsub(re, repl)` 替换所有匹配，返回替换次数：

```shell
$ echo '2026-01-05' | awk '{ gsub(/-/, "/"); print }'
2026/01/05

$ echo 'a-b-c' | awk '{ n = gsub(/-/, "+"); print $0, n }'
a+b+c 2
```

`sub` 和 `gsub` 默认修改 `$0`，也可以把目标作为第三个参数：

```shell
$ echo 'a-b-c' | awk '{ sub(/-/, "+", $0); print }'
a+b-c
```

替换文本里的 `&` 表示整个匹配：

```shell
$ echo 'abc' | awk '{ sub(/b/, "[&]"); print }'
a[b]c
```

要写字面 `&`，用 `\&`。`gensub()` 是 **GNU** 扩展，支持反向引用和选择替换第几个匹配：

```shell
$ echo '2026-01-05' | awk '{ print gensub(/([0-9]{4})-([0-9]{2})-([0-9]{2})/, "\\3/\\2/\\1", 1) }'
05/01/2026
```

`gensub` 的第三个参数是 `1` 表示只替换第一个匹配，`"g"` 表示替换全部。替换文本里的 `\1`、`\2` 引用捕获组；在 awk 字符串里要写成 `"\\1"`。

### 大小写与 GNU 扩展

GNU awk 的 `IGNORECASE` 可以让正则匹配忽略大小写：

```shell
$ awk -F '\t' 'BEGIN { IGNORECASE = 1 } /engineering/ { print $2 }' examples/data/employees.tsv
Alice
Carol
Frank
Lisa
```

`IGNORECASE` 影响正则匹配、`index()`、`split()` 等依赖大小写的操作，但对字符串比较 `==` 的影响要看版本和上下文。需要可移植时，显式用 `tolower()` 或 `toupper()`。

GNU awk 还支持这些常用扩展：

- `\y`：单词边界。`/\ycat\y/` 匹配独立的 `cat`，不匹配 `category`。
- `\w`、`\W`：单词字符和非单词字符。
- `\s`、`\S`：空白和非空白。
- `\<`、`\>`：单词开头和结尾。
- `\B`：非单词边界。

```shell
$ echo 'cat category' | awk '{ gsub(/\ycat\y/, "CAT"); print }'
CAT category
```

这些写法在 POSIX awk、mawk 和 BSD awk 上不一定可用。脚本要跨实现时，用 `[[:<:]]`/`[[:>:]]` 也不一定行，最稳的是用字符类显式构造边界，或者换用支持这些扩展的工具。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 点号匹配了任意字符 | `.` 是通配符，不是字面点 | 写 `\.` 或字符串 `"\\."` |
| `\d` 不工作 | awk 的 ERE 不支持 `\d` | 用 `[0-9]` 或 `[[:digit:]]` |
| 动态正则报错或匹配不到 | 字符串转义层数不对 | 用 `-v` 传值，先打印 `pat` 看实际内容 |
| 匹配到了子串 | 没有加 `^` 和 `$` | 按需要锚定整个字段 |
| `.*` 吃掉了太多内容 | 正则默认贪婪，没有懒惰量词 | 用排除字符类，如 `[^"]*` |
| `/` 导致语法错误 | 正则字面量里的斜杠没有转义 | 写 `\/` |
| `IGNORECASE` 在别的 awk 上无效 | 这是 GNU 扩展 | 用 `tolower()` 或换实现 |
| `match` 的捕获数组为空 | 用了 POSIX awk，不支持第三个参数 | 用 `substr`/`split`，或确认是 GNU awk |

### 小结

- awk 使用 POSIX ERE，`+`、`?`、`|`、`()`、`{m,n}` 是元字符。
- 静态正则用 `/.../`，动态正则用字符串变量；字符串要多一层转义。
- `/re/` 匹配 `$0`，`$n ~ /re/` 匹配指定字段，`!~` 取反。
- `match()` 提供 `RSTART`/`RLENGTH`，GNU awk 还能捕获分组。
- `sub`/`gsub` 替换，`gensub` 支持反向引用（GNU）。
- 没有懒惰量词，`.*` 默认贪婪；需要精确边界时用字符类和锚点。
- `IGNORECASE`、`\y`、`\w` 等是 GNU 扩展，跨实现前先确认。

### 练习

- 从 `examples/data/employees.tsv` 中找出所有邮箱式或 `Eng` 开头的部门名，解释为什么这里用 `^` 很重要。
- 从 `examples/data/access.log` 中找出所有 `POST` 请求。
- 用 `match()` 提取 `access.log` 中的日期，打印 `RSTART` 和 `RLENGTH`。
- 把 `2026-01-05` 转成 `05/01/2026`，分别用 `gsub` 和 `gensub` 实现。
- 用 `split()` 按逗号拆分 `a,b,c`，打印字段数和第二个字段。
- 解释 `"\\."` 和 `/\./` 的区别，以及为什么在 shell 单引号里写 `'\\.'` 和 `'\.'` 可能得到不同结果。

<details>
<summary>参考答案</summary>

部门名以 `Eng` 开头：

```shell
awk -F '\t' '$3 ~ /^Eng/ { print $2, $3 }' examples/data/employees.tsv
```

如果不加 `^`，`Eng` 也会匹配到 `EngineeringOps` 这类值。当前数据里没有这种值，但规则应该写清楚。

POST 请求：

```shell
awk '$6 ~ /^"POST/ { print $1, $7, $9 }' examples/data/access.log
```

`$6` 是 `"POST`，`$7` 是路径，`$9` 是状态码。

日期位置：

```shell
awk '{ match($0, /[0-9]{2}\/[A-Za-z]{3}\/[0-9]{4}/); print RSTART, RLENGTH, substr($0, RSTART, RLENGTH) }' examples/data/access.log
```

第一行输出 `RSTART=...`，具体值取决于日志行。`substr` 会得到 `12/Mar/2026` 这样的日期。

日期重排：

```shell
echo '2026-01-05' | awk '{ gsub(/-/, "/"); print }'
echo '2026-01-05' | awk '{ print gensub(/([0-9]{4})-([0-9]{2})-([0-9]{2})/, "\\3/\\2/\\1", 1) }'
```

`gsub` 只是把分隔符换掉，得到 `2026/01/05`；`gensub` 用捕获组重排，得到 `05/01/2026`。

拆分：

```shell
echo 'a,b,c' | awk '{ n = split($0, part, ","); print n, part[2] }'
```

输出 `3 b`。

`"\\."` 是字符串写法，awk 先把它变成 `\.`，正则引擎再解释为字面点；`/\./` 是正则字面量，反斜杠直接交给正则引擎。shell 单引号里 `'\\.'` 传给 awk 两个反斜杠加一个点，`'\.'` 传给 awk 一个反斜杠加一个点；前者在 `-F` 等选项里更稳，后者在正则字面量里更直接。拿不准时先打印变量内容或用 `--lint` 检查。

</details>
