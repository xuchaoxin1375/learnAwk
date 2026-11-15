## 环境与约定

这一篇把运行环境固定下来：确认你用的是 GNU awk，知道示例数据长什么样，能看懂正文里的命令块和终端记录。后面的章节默认这些前置已经满足，不再重复安装和路径说明。

### 读者起点

教程假设你已经能完成下面这些操作：

- 在终端里执行命令，使用管道 `|`、重定向 `>`、`>>` 和命令替换 `$(...)`。
- 用单引号或双引号控制 shell 的展开，知道 `$HOME` 和 `'$HOME'` 的区别。
- 读过基本的正则表达式，知道 `.`、`*`、`[]`、`^`、`$` 的大致含义。
- 能看懂 `grep`、`sort`、`cut`、`head` 这类命令的常见用法。

不需要会 awk，也不需要会 Python 或其他编程语言。

### awk 与 GNU awk

**awk** 是一门处理文本的语言，名字来自三位作者 Aho、Weinberger 和 Kernighan 的姓氏首字母。**GNU awk** 是这门语言的一个实现，命令名通常是 `gawk`，也是本教程讨论的实现。

很多系统会把 `awk` 指向某个实现：

- Linux 上常见 GNU awk 或 mawk。
- macOS 自带 BSD awk，功能比 GNU awk 少。
- Git Bash、MSYS2、WSL 里通常是 GNU awk 或可以安装 GNU awk。

本教程用到 GNU 扩展时会明确标注 **GNU**。只使用 POSIX 子集的写法，在 mawk 和 BSD awk 上通常也能运行，但边界要以各实现的文档为准。

### 确认版本

在仓库根目录执行：

```shell
gawk --version
```

正常输出的前两行类似：

```shell
GNU Awk 5.3.2, API 4.0, PMA Avon 8-g1, (GNU MPFR 4.2.2, GNU MP 6.3.0)
Copyright (C) 1989, 1991-2025 Free Software Foundation.
```

如果 `gawk` 不存在，试：

```shell
awk --version
```

输出里含 `GNU Awk` 就说明 `awk` 已经是 GNU 实现。输出是 `mawk`、`BusyBox` 或报错时，按下面的方式安装。

### 安装 GNU awk

按你的系统选择一种方式：

- **Debian/Ubuntu**：`sudo apt install gawk`
- **Fedora**：`sudo dnf install gawk`
- **Arch Linux**：`sudo pacman -S gawk`
- **macOS**：`brew install gawk`，之后使用 `gawk`；不要依赖系统自带的 BSD awk。
- **Windows**：推荐 Git Bash 或 WSL。Git Bash 通常已经带有 GNU awk；WSL 按 Debian/Ubuntu 的方式安装。
- **从源码安装**：下载 GNU awk 的发布包，按 `README` 执行 `./configure && make && sudo make install`。这条路径适合需要特定版本或嵌入式环境的读者，初学者不必优先选择。

安装后回到仓库根目录，运行：

```shell
bash scripts/check-env.sh
```

它会输出 awk 路径、版本、locale、数据文件检查和一次最小运行。典型的通过输出如下：

```shell
$ bash scripts/check-env.sh
awk 路径: /usr/bin/gawk
版本: GNU Awk 5.3.2, API 4.0, PMA Avon 8-g1, (GNU MPFR 4.2.2, GNU MP 6.3.0)
locale: LC_ALL=<未设置> LANG=<未设置> LC_CTYPE=<未设置>
UTF-8 长度探测: length("café") = 5 (4 为按字符, 5 为按字节)
提示: 当前 locale 下按字节计数。需要字符计数时显式设置 UTF-8 locale，例如 LC_ALL=C.UTF-8。
数据文件: 16 个检查通过
最小示例: Alice Engineering
检查通过。可以开始阅读 docs/setup.md 或直接运行 bash scripts/verify.sh。
```

你的路径、版本和 locale 可能不同，只要最后一行是“检查通过”就可以继续。UTF-8 长度探测为 5 不是错误，它说明当前 shell 没有启用 UTF-8 locale；后面的 **UTF-8 与 locale** 一节会解释。

### 示例数据

所有案例共用 `examples/data/` 下的数据。它们都是虚构的，IP 使用 RFC 5737 的文档保留地址段。

| 文件 | 结构 | 用途 |
| --- | --- | --- |
| `employees.tsv` | 制表符分隔，带表头 | 字段、过滤、分组统计 |
| `scores.tsv` | 制表符分隔，无表头 | 数组、平均值、函数 |
| `sales.csv` | 逗号分隔，带表头 | CSV、算术、分组、报表 |
| `access.log` | 常见日志格式 | 正则、状态码统计、Top IP |
| `poem.txt` | 一行一句 | 字符串函数、词频 |
| `paragraphs.txt` | 空行分隔段落 | `RS=""`、多行记录 |
| `passwd.txt` | 冒号分隔 | `FS=":"`、`$NF` |
| `inventory.tsv` | 制表符分隔，带表头 | 连接、查表 |
| `orders.tsv` | 制表符分隔，带表头 | 连接、缺失键 |
| `numbers.txt` | 每行一个数字 | 求和、最值、直方图 |
| `messy.csv` | 含引号和逗号 | CSV 解析边界 |
| `unicode.txt` | 含非 ASCII 字符 | 字符与字节长度 |
| `config.ini` | 分节键值配置 | `getline`、状态解析 |
| `team-a.tsv`、`team-b.tsv` | 制表符分隔，无表头 | `NR` 与 `FNR` |
| `fixed-width.txt` | 固定列宽 | `FIELDWIDTHS` |

先用 `head` 看一眼：

```shell
$ head -n 3 examples/data/employees.tsv
id	name	dept	salary	city
1	Alice	Engineering	120000	Beijing
2	Bob	Sales	90000	Shanghai
```

上面终端记录里的空白处是制表符，复制到编辑器里不要改成空格。需要看不可见字符时，可以用 `cat -A` 或 `sed -n l`，但本教程不依赖这些工具。

### 运行方式

awk 的典型调用形式是：

```shell
awk '程序' 文件...
```

程序写在单引号里，文件可以有一个或多个。也可以从标准输入读：

```shell
printf 'Alice Engineering 120000\n' | awk '{ print $2 }'
```

常用选项先认识四个：

| 选项 | 作用 | 示例 |
| --- | --- | --- |
| `-F` | 设置字段分隔符 | `awk -F '\t' ...` |
| `-v` | 在程序运行前设置变量 | `awk -v limit=100000 '$4 > limit' ...` |
| `-f` | 从文件读取程序 | `awk -f examples/scripts/dept-report.awk ...` |
| `--posix` | 关闭 GNU 扩展，按 POSIX 行为运行 | `awk --posix ...` |

完整选项在[脚本化与可移植性](scripts-and-portability.md)和[速查表](cheatsheet.md)里汇总。

### 引号与 shell

awk 程序里大量使用 `$1`、`$NF`、`$(NF-1)` 这样的写法。在 bash、zsh、Git Bash 里，用**单引号**包住程序，shell 就不会展开 `$`：

```shell
awk '{ print $1 }' examples/data/employees.tsv
```

如果用了双引号，shell 会先展开 `$1`。在 bash 里 `$1` 通常是当前 shell 的第一个位置参数，未设置时展开为空字符串，awk 收到的程序就变成了 `{ print  }`，输出的是整条记录而不是第一列。实际写命令时坚持单引号，除非你明确需要 shell 变量插值。

在 PowerShell 里，情况不同：PowerShell 自己会解释 `$`，而且 `awk` 可能不在 PATH 中。**Windows 读者请使用 Git Bash 或 WSL 执行本教程的命令**。如果必须在 PowerShell 中调用，PowerShell 的单引号也是字面量，可以写成：

```powershell
awk '{ print $1 }' examples/data/employees.tsv
```

但前提是 `awk` 已在 PATH 中，且它的行为确实是 GNU awk。跨 shell 混用引号是初学者最常见的失败来源之一，遇到解析错误先回到 Git Bash 复现。

### UTF-8 与 locale

awk 的 `length()`、`substr()`、`toupper()` 以及字符类 `[[:alpha:]]` 是否按字符工作，取决于运行时 locale。同一个字符串在不同 locale 下可能得到不同长度：

```shell
$ LC_ALL=C awk 'BEGIN { print length("café") }'
5

$ LC_ALL=C.UTF-8 awk 'BEGIN { print length("café") }'
4
```

`café` 有 4 个字符；在 C/POSIX locale 下 awk 按字节数，`é` 占两个字节，所以得到 5。**需要按字符处理时，显式设置 UTF-8 locale**：

```shell
LC_ALL=C.UTF-8 awk '{ print length($0) }' examples/data/unicode.txt
```

输出：

```shell
4
5
2
```

`naïve` 有 5 个字符，`北京` 有 2 个字符。macOS 上如果没有 `C.UTF-8`，可以用 `LC_ALL=en_US.UTF-8`。如果只需要按字节处理，或者希望输出不受 locale 影响，用 `LC_ALL=C`。

GNU awk 还有一个 `-b` 选项，强制按字节处理：

```shell
LC_ALL=C.UTF-8 awk -b '{ print length($0) }' examples/data/unicode.txt
```

输出会回到 `5`、`6`、`6`。这个选项适合处理二进制或明确按字节计数的场景，不适合处理多语言文本。

### 命令块与终端记录

正文里有两种代码块：

- **可复制命令块**：只有命令，没有提示符，可以直接复制执行。
- **终端记录块**：以 `$` 开头表示命令，下面紧跟输出。复制时不要带上 `$`。

例如，可复制命令块：

```shell
awk -F '\t' 'NR > 1 { print $2, $3 }' examples/data/employees.tsv
```

终端记录块：

```shell
$ awk -F '\t' 'NR > 1 { print $2, $3 }' examples/data/employees.tsv | head -n 3
Alice Engineering
Bob Sales
Carol Engineering
```

终端记录里的输出可能因为 `head`、`sort` 或数据顺序被截断，正文会说明。**不要要求输出逐字匹配教程**，先看结构、字段和判断依据。

### 获取帮助

本地帮助：

```shell
gawk --help
man gawk
info gawk
```

`man` 和 `info` 在 Windows Git Bash 里可能没有，可以直接看在线手册。遇到不认识的函数，先查[GNU awk 官方手册](https://www.gnu.org/software/gawk/manual/gawk.html)，再用 `gawk --posix` 或 `gawk --lint` 检查可移植性。

### 检查清单

开始下一章前，确认：

- `gawk --version` 或 `awk --version` 的输出含 `GNU Awk`。
- `bash scripts/check-env.sh` 最后一行是“检查通过”。
- 能在仓库根目录执行 `awk -F '\t' 'NR > 1 { print $2 }' examples/data/employees.tsv`。
- 知道终端记录里的 `$` 不是命令的一部分。
- 知道遇到 UTF-8 字符计数问题时要显式设置 locale。

### 练习

- 用 `awk` 打印 `examples/data/employees.tsv` 的第一列，跳过表头。
- 用 `awk` 打印 `examples/data/passwd.txt` 的最后一列，并解释 `$NF` 为什么能取到 shell。
- 在 `LC_ALL=C` 和 `LC_ALL=C.UTF-8` 下分别运行 `awk 'BEGIN { print length("北京") }'`，记录两个结果。
- 运行 `gawk --help`，找出 `-F`、`-v`、`-f` 三个选项的说明。

<details>
<summary>参考答案</summary>

打印第一列：

```shell
awk -F '\t' 'NR > 1 { print $1 }' examples/data/employees.tsv
```

打印最后一列：

```shell
awk -F ':' '{ print $NF }' examples/data/passwd.txt
```

`$NF` 表示“第 NF 个字段”。`NF` 是当前记录的字段数，冒号分隔的 passwd 行有 7 个字段，所以 `$NF` 就是 `$7`，也就是 shell。

字符长度：

```shell
$ LC_ALL=C awk 'BEGIN { print length("北京") }'
6

$ LC_ALL=C.UTF-8 awk 'BEGIN { print length("北京") }'
2
```

`北京` 是两个字符，UTF-8 编码下每个汉字占 3 个字节，所以 C locale 下得到 6。

</details>
