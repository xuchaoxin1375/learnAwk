## GNU awk 入门

一份面向初学者的 GNU awk 教程，假设你已经会使用 shell：知道管道、重定向、引号、变量和基本正则表达式。教程从 awk 的工作模型讲起，逐步进入字段、模式、正则、数组、函数、输入输出和真实场景。正文中的核心示例都在 GNU Awk 5.3.2 上实际运行过，明确标为错误示范的除外。

**awk** 是一门文本处理语言，不是单个命令的别名。它按记录读取输入，把每条记录拆成字段，再用“模式 + 动作”的规则处理这些字段。**GNU awk** 是 awk 语言最常用的实现，命令名通常是 `gawk`；很多系统也把 `awk` 指向它。

### 为什么学 awk

- **按列处理很自然**：日志、CSV(Comma-Separated Values, 逗号分隔值)、TSV(Tab-Separated Values, 制表符分隔值)、`/etc/passwd` 这类一行多字段的数据，用 `$1`、`$3` 就能取到需要的列。
- **自带聚合能力**：计数、求和、求平均、分组统计不需要先把数据导进数据库。
- **适合管道**：从标准输入读、向标准输出写，容易和 `grep`、`sort`、`uniq`、`sed` 组合。
- **无需额外运行时**：大多数 Linux、macOS 和 Git Bash 环境已经有 awk，脚本可以直接放进版本库。
- **理解一类数据处理模型**：记录、字段、模式、动作、关联数组这些概念会迁移到其他数据处理工具。
- **小而完整**：几十行就能写出一个可复用的报表脚本，比 Python 少很多样板代码。

### 学完能做什么

- 读懂并写出常见的 awk 单行命令和脚本文件。
- 用字段、记录、`FS`、`RS`、`NR`、`FNR` 精确控制输入怎么切分。
- 用模式、正则和范围选择要处理的数据。
- 用变量、控制流、函数和关联数组完成统计、分组、连接和去重。
- 用 `printf` 生成对齐的报表，用重定向把结果写到文件或管道。
- 用 `getline` 读取额外文件或命令输出，并正确处理失败。
- 识别 GNU awk 与 POSIX(Portable Operating System Interface) awk、mawk、BSD(Berkeley Software Distribution) awk 的差异，知道什么时候该换工具。

### 不适合用 awk 的场景

awk 适合**一记录多字段、逐行处理、规模中小**的任务。遇到以下情况，优先换工具：

- 解析 JSON(JavaScript Object Notation)、XML(eXtensible Markup Language)、YAML(YAML Ain't Markup Language) 等嵌套结构：用 `jq`、`yq` 或对应语言的库。
- 带引号、转义和换行的复杂 CSV：GNU awk 5.3 的 `--csv` 或 `FPAT` 能处理一部分，但复杂情况用 Python 的 `csv` 模块更稳。
- 需要复杂数据结构、递归下降解析、异常处理和大型测试：用 Python、Perl、Go 等通用语言。
- 需要随机访问、索引和事务：用数据库。
- 二进制文件或需要保留任意字节：先确认工具行为，通常不是 awk 的强项。
- 交互式编辑、需要撤销和语法高亮：用编辑器。

### 学习路径

按下面的顺序阅读，概念依赖最顺。必读章节构成主线，选做章节用于综合练习。

| 顺序 | 文档 | 内容 | 建议 |
| --- | --- | --- | --- |
| 1 | [环境与约定](docs/setup.md) | 确认 GNU awk、准备数据、运行检查 | 必读 |
| 2 | [awk 的工作模型](docs/how-awk-works.md) | 记录、字段、规则、主循环、BEGIN/END | 必读 |
| 3 | [字段与记录](docs/fields-records.md) | `$0`、`NF`、`FS`、`RS`、`OFS`、`NR`、`FNR` | 必读 |
| 4 | [模式与动作](docs/patterns-actions.md) | 表达式、正则、范围、`next`、`nextfile` | 必读 |
| 5 | [awk 的正则表达式](docs/regex.md) | ERE、锚点、字符类、捕获、动态正则 | 必读 |
| 6 | [变量与表达式](docs/expressions-variables.md) | 字符串/数字、比较、算术、`-v`、`ENVIRON` | 必读 |
| 7 | [控制流与函数](docs/control-flow.md) | `if`、循环、`next`、`exit`、自定义函数 | 必读 |
| 8 | [关联数组](docs/arrays.md) | 计数、分组、`split`、多维键、排序 | 必读 |
| 9 | [内置函数](docs/builtin-functions.md) | 字符串、数学、时间、`gensub` | 必读 |
| 10 | [格式化输出](docs/printf-output.md) | `printf`、宽度、精度、重定向、`close` | 必读 |
| 11 | [getline 与输入输出](docs/getline-io.md) | 六种 `getline`、`ARGV`、`system`、管道 | 必读 |
| 12 | [脚本化与可移植性](docs/scripts-and-portability.md) | `-f`、shebang、GNU 扩展、性能、调试 | 必读 |
| 13 | [实战案例](docs/recipes.md) | 日志、销售、连接、去重、报表 | 必读 |
| 14 | [排错与常见陷阱](docs/troubleshooting.md) | 症状、原因、诊断、修复 | 遇到问题先查 |
| 15 | [速查表](docs/cheatsheet.md) | 语法、变量、函数、单行命令 | 学后查阅 |
| 16 | [综合练习](docs/capstone.md) | 用真实数据完成一组任务 | 选做 |

### 环境准备

教程以 **GNU awk** 为准。先确认版本：

```shell
gawk --version
```

正常输出的前两行类似：

```shell
GNU Awk 5.3.2, API 4.0, PMA Avon 8-g1, (GNU MPFR 4.2.2, GNU MP 6.3.0)
Copyright (C) 1989, 1991-2025 Free Software Foundation.
```

如果系统没有 `gawk`，先试 `awk --version`。输出里含 `GNU Awk` 就说明 `awk` 已经指向 GNU 实现；如果显示 `mawk`、`BusyBox` 或只支持 `-W version`，请安装 GNU awk：

- **Debian/Ubuntu**：`sudo apt install gawk`
- **Fedora**：`sudo dnf install gawk`
- **Arch Linux**：`sudo pacman -S gawk`
- **macOS**：系统自带的 `awk` 是 BSD awk，功能较少。用 `brew install gawk` 安装，之后显式使用 `gawk`。
- **Windows**：推荐 Git Bash 或 WSL。教程的实测环境是 Git Bash 中的 GNU Awk 5.3.2；WSL 里可按 Debian/Ubuntu 的方式安装。

运行仓库自带的检查：

```shell
bash scripts/check-env.sh
```

它会检查 awk 实现、版本、locale、数据文件和一次最小运行，不会修改文件。

### 五分钟体验

以下命令在仓库根目录执行。数据都是虚构的，IP(Internet Protocol) 地址使用文档保留地址段。

按部门统计薪资：

```shell
awk -F '\t' 'NR > 1 { sum[$3] += $4 } END { for (d in sum) print d, sum[d] }' examples/data/employees.tsv | sort
```

计算销售额：

```shell
awk -F ',' 'NR > 1 { total += $4 * $5 } END { printf "%.2f\n", total }' examples/data/sales.csv
```

筛出 5xx 请求：

```shell
awk '$9 >= 500 { print $1, $7, $9 }' examples/data/access.log
```

统计日志状态码：

```shell
awk '{ count[$9]++ } END { for (s in count) print s, count[s] }' examples/data/access.log | sort -n
```

查看 awk 的内部模型：

```shell
printf 'Alice Engineering 120000\n' | awk '{ print NR, NF, $1, $NF }'
```

### 仓库结构

```shell
.
├── README.md
├── docs/                   教程正文
├── examples/
│   ├── data/               练习与案例数据
│   └── scripts/            可复用的 awk 脚本
├── scripts/
│   ├── check-env.sh        环境检查
│   └── verify.sh           示例与行为的自动校验
├── out/                    运行示例时生成的输出（不提交）
├── .gitattributes
└── .gitignore
```

### 使用约定

- 所有命令默认在**仓库根目录**执行，路径写成 `examples/data/...`。
- 正文中的 `awk` 指 GNU awk 的行为；提到其他实现时会写 mawk、BSD awk 或 BusyBox awk。
- 标记 **GNU** 的写法是 GNU 扩展，POSIX awk 或其他实现不一定支持。
- 命令块只放可复制命令；终端记录块用 `$` 开头表示命令，输出紧跟其后。不要把 `$` 一起复制。
- 示例输出默认来自 GNU Awk 5.3.2、Git Bash、显式 UTF-8 locale 的实际运行。涉及平台差异的地方会单独标注。
- 修改文件前先复制或使用备份。标准 awk 没有 sed 那样的 `-i`；GNU awk 可以用 `-i inplace` 扩展实现原地修改，但教程默认先写临时文件再替换，行为更可控。
- 未实际运行的内容会写“示意”或“未验证”，不把推断当成实测。

### 练习与自检

每篇正文末尾有少量练习，答案折叠在“参考答案”里。建议先自己写出命令，再展开对照。

全部读完后运行：

```shell
bash scripts/verify.sh
```

它会用临时目录验证教程中的核心行为，不会修改仓库文件。如果你想确认自己的环境是否符合 GNU awk 的预期，也先运行它。

### 参考资料

- [GNU awk 官方手册](https://www.gnu.org/software/gawk/manual/gawk.html)：最权威的 GNU awk 行为说明。
- [POSIX awk 规范](https://pubs.opengroup.org/onlinepubs/9699919799/utilities/awk.html)：可移植子集的边界。
- [The AWK Programming Language](https://awk.dev/)：Aho、Kernighan、Weinberger 的经典教材，第二版覆盖了新特性。
- [awk one-liners](https://awk.dev/awk.shtml)：经典单行命令合集，注意其中不少是 GNU 扩展。
- [GNU awk 的 CSV 支持](https://www.gnu.org/software/gawk/manual/html_node/CSV-Parsing.html)：`--csv` 与 `FPAT` 的边界。

发现错误或希望补充案例，欢迎提交 issue 或 pull request。修改示例后请运行 `bash scripts/verify.sh`。

### 许可证

本项目采用 **MIT** 许可证，允许使用、复制、修改、合并、发布、分发、再许可和销售，保留版权与许可声明即可。完整文本见 [LICENSE](LICENSE)。
