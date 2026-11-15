## 控制流与函数

awk 的动作里可以写条件、循环和函数。这一篇从最简单的分支开始，逐步到循环、`next`/`exit` 的边界，最后把重复逻辑封装成函数。目标是让程序从“一条命令”变成“一个可读、可复用的脚本”。

### if 与 else

```awk
if (condition) {
    statements
} else if (another_condition) {
    statements
} else {
    statements
}
```

根据分数分级：

```shell
$ awk '
function grade(score) {
  if (score >= 90) return "A"
  else if (score >= 80) return "B"
  else if (score >= 70) return "C"
  else if (score >= 60) return "D"
  else return "F"
}
{ print $1, $2, grade($2) }
' examples/data/scores.tsv
Alice 85 B
Bob 72 C
Carol 95 A
Dave 60 D
Eve 88 B
Frank 70 C
Grace 91 A
Heidi 64 D
```

这个例子同时用了函数和 `if`。函数先放一放，先看分支本身：条件按顺序判断，第一个为真的分支执行，后面的分支不再判断。

条件不一定是比较表达式，也可以是字段、变量或函数返回值。awk 的真假规则在[模式与动作](patterns-actions.md)里讲过：数字 0、空字符串为假，其他为真；字面量 `"0"` 是真。

### while 与 do-while

`while` 先判断再执行：

```shell
$ awk 'BEGIN { i = 1; while (i <= 5) { print i; i++ } }'
1
2
3
4
5
```

`do-while` 先执行一次再判断：

```shell
$ awk 'BEGIN { i = 1; do { print i; i++ } while (i <= 3) }'
1
2
3
```

`do-while` 至少执行一次，适合“先做再决定是否继续”的场景。初学阶段多数循环用 `while` 或 `for` 就够了。

循环必须有终止条件。最常见的死循环是忘记更新计数器：

```awk
while (i <= 5) {
    print i
    # 缺少 i++
}
```

awk 不会自动中断死循环，按 `Ctrl+C` 可以停止。

### for 循环

C 风格的 `for`：

```shell
$ awk 'BEGIN { for (i = 1; i <= 3; i++) print i }'
1
2
3
```

遍历字段是 awk 里非常常见的用法：

```shell
$ awk -F '\t' 'NR == 2 { for (i = 1; i <= NF; i++) print i, $i }' examples/data/employees.tsv
1 1
2 Alice
3 Engineering
4 120000
5 Beijing
```

`for (i = 1; i <= NF; i++)` 从第一个字段走到最后一个字段。注意循环条件里的 `NF` 是当前记录的字段数，不是固定的 5；处理不同行时它会变化。

数组的 `for (key in array)` 语法在[关联数组](arrays.md)里讲。

### break 与 continue

- `break` 立即结束当前循环。
- `continue` 跳过本次迭代，进入下一次。

```shell
$ awk 'BEGIN {
  for (i = 1; i <= 10; i++) {
    if (i == 3) continue
    if (i == 6) break
    print i
  }
}'
1
2
4
5
```

`break` 和 `continue` 只作用于最内层循环，不会影响外层的记录循环。

### next、nextfile 与 exit

这三个语句在[模式与动作](patterns-actions.md)里已经出现，这里放在控制流的语境里再对照一次：

| 语句 | 作用范围 | 典型用途 |
| --- | --- | --- |
| `next` | 当前记录 | 跳过后续规则，直接读下一条记录 |
| `nextfile` | 当前文件 | 跳过当前文件剩余内容（GNU） |
| `exit` | 整个程序 | 结束主循环，执行 `END`，设置退出码 |

`next` 和 `continue` 的区别是作用对象：`next` 作用于记录循环，`continue` 作用于显式的 `for`/`while` 循环。

`exit` 可以在普通规则、`BEGIN`、`END` 或函数里调用：

```shell
$ awk 'function stop() { exit 7 } BEGIN { print "before"; stop(); print "after" } END { print "end" }'
before
end
$ echo $?
7
```

`after` 没有打印，`end` 打印了，退出码是 7。

### 定义函数

函数把重复逻辑封装起来：

```awk
function average(a, b, c) {
    return (a + b + c) / 3
}
```

调用：

```shell
$ awk '
function average(a, b, c) {
  return (a + b + c) / 3
}
{ printf "%s %.2f\n", $1, average($2, $3, $4) }
' examples/data/scores.tsv
Alice 85.00
Bob 76.67
Carol 91.33
Dave 68.33
Eve 88.33
Frank 71.67
Grace 92.33
Heidi 70.33
```

函数可以定义在调用之前或之后，awk 会先解析整个程序：

```shell
$ awk 'BEGIN { print double(4) } function double(x) { return x * 2 }'
8
```

函数名不能和内置函数重名。`length`、`substr`、`split` 这些名字已经被占用，定义 `function length(x)` 会报错或产生不可预期的行为。

### 参数与局部变量

awk 的函数参数都是按值传递的标量；数组是例外，按引用传递（在[关联数组](arrays.md)里讲）。

函数内部没有 `var` 声明。**写在参数列表里的变量是局部变量，其他变量都是全局变量**：

```awk
function average(a, b, c,    sum) {
    sum = a + b + c
    return sum / 3
}
```

`sum` 是第四个参数，调用时不需要传值。按照惯例，局部变量放在参数列表末尾，并用额外的空格和真正的参数隔开：

```awk
function average(a, b, c,    sum, i)
```

这样读代码的人一眼能看出 `a`、`b`、`c` 是输入，`sum`、`i` 是局部变量。

对比下面两个函数：

```awk
function bad() {
    temp = 1      # 全局变量
}

function good(    temp) {
    temp = 1      # 局部变量
}
```

`bad()` 会污染全局命名空间，`good()` 不会。函数一多，这个区别非常重要。

### 递归

awk 支持递归，但要有终止条件：

```shell
$ awk '
function fact(n) {
  if (n <= 1) return 1
  return n * fact(n - 1)
}
BEGIN { print fact(5) }
'
120
```

递归适合树形结构、分治和数学定义。数据处理里更常见的是循环和数组，递归不是必须的。递归层数太深可能耗尽栈空间，awk 不会自动优化尾递归。

### 返回值

`return` 可以带值，也可以不带：

```shell
$ awk 'function f() { return } BEGIN { print "[" f() "]" }'
[]
```

不带值的 `return` 返回空字符串，在数值上下文里按 0 处理。函数执行到末尾没有 `return` 时，返回值同样是空/0。

`return` 只结束当前函数，不会结束整个程序。要结束程序用 `exit`。

### 函数与全局状态

函数可以读写全局变量：

```shell
$ awk 'function bump() { count++ } { bump() } END { print count }' examples/data/team-a.tsv
2
```

`count` 没有在函数参数里，所以它是全局变量。这个特性有时很方便，但会让函数依赖外部状态，降低可复用性。**优先通过参数传入、通过返回值传出**，全局变量只用于真正的程序级状态。

### 常见陷阱

| 现象 | 原因 | 修复 |
| --- | --- | --- |
| 函数里的变量互相影响 | 忘了把局部变量写进参数列表 | 在参数列表末尾声明局部变量 |
| 函数名报错 | 和内置函数重名 | 换一个名字，如 `my_length` |
| 递归不终止 | 缺少或写错终止条件 | 先检查 `n <= 1` 这类边界 |
| `next` 在函数里行为奇怪 | `next` 会跳过当前记录的剩余规则 | 尽量在普通规则里用 `next` |
| `exit` 后还有输出 | `END` 仍会执行 | 这是预期行为；需要彻底退出时在 `END` 里再判断 |
| 循环不结束 | 计数器没有更新，或条件永远为真 | 检查 `i++` 和边界 |
| 修改参数影响了调用者 | 标量按值传递，数组按引用传递 | 标量修改不会回传；数组要小心 |

### 小结

- `if`/`else if`/`else` 按顺序判断，第一个为真的分支执行。
- `while` 先判断，`do-while` 至少执行一次，`for` 适合计数循环。
- `break` 结束当前循环，`continue` 跳过本次迭代。
- `next` 跳过当前记录，`nextfile` 跳过当前文件，`exit` 结束程序并执行 `END`。
- 函数用 `function name(args) { ... }` 定义，可以返回标量。
- 局部变量写在参数列表里，其他变量是全局变量。
- 函数可以递归，但要有终止条件；`return` 只结束函数。

### 练习

- 用 `if` 把 `examples/data/scores.tsv` 的学生分成及格和不及格，统计人数。
- 用 `while` 计算 1 到 100 的和。
- 用 `for` 遍历 `examples/data/employees.tsv` 的字段，打印字段编号和值。
- 写一个函数 `max(a, b)`，返回两个数中较大的一个，并用它找出薪资最高的人。
- 写一个递归函数计算斐波那契数列的第 n 项，比较 n=10 和 n=20 的运行时间。
- 用 `exit` 在读到第一条薪资低于 70000 的记录时停止，并在 `END` 打印已处理的记录数。

<details>
<summary>参考答案</summary>

及格统计：

```shell
awk '
$2 >= 60 { pass++ }
$2 < 60 { fail++ }
END { print "pass", pass; print "fail", fail }
' examples/data/scores.tsv
```

1 到 100 的和：

```shell
awk 'BEGIN { i = 1; while (i <= 100) { sum += i; i++ } print sum }'
```

遍历字段：

```shell
awk -F '\t' 'NR == 2 { for (i = 1; i <= NF; i++) print i, $i }' examples/data/employees.tsv
```

最大值函数：

```shell
awk '
function max(a, b) {
  return a > b ? a : b
}
NR == 1 { next }
{
  best = max(best, $4)
  if ($4 == best) name = $2
}
END { print name, best }
' examples/data/employees.tsv
```

递归斐波那契：

```shell
awk '
function fib(n) {
  if (n <= 1) return n
  return fib(n - 1) + fib(n - 2)
}
BEGIN { print fib(10); print fib(20) }
'
```

n=20 会明显变慢，因为递归重复计算。实际统计用循环或记忆化。

提前退出：

```shell
awk -F '\t' '
NR == 1 { next }
$4 < 70000 { exit }
{ n++ }
END { print "processed", n }
' examples/data/employees.tsv
```

`exit` 在读到 Dave 时触发，`END` 仍会打印已处理数量。

</details>
