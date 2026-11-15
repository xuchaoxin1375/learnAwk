## 示例脚本

这些脚本都使用 GNU awk 5.3 的特性，尤其是 `PROCINFO["sorted_in"]`。运行方式：

```shell
gawk -f examples/scripts/<script>.awk <输入文件>
```

脚本首行是 `#!/usr/bin/env -S gawk -f`。如果系统的 `env` 不支持 `-S`，直接用上面的 `gawk -f` 命令运行即可，不要依赖 shebang。

| 脚本 | 作用 | 示例 |
| --- | --- | --- |
| `salary-sum.awk` | 计算薪资总和 | `gawk -f examples/scripts/salary-sum.awk examples/data/employees.tsv` |
| `dept-report.awk` | 按部门统计人数和平均薪资 | `gawk -f examples/scripts/dept-report.awk examples/data/employees.tsv` |
| `log-summary.awk` | 汇总日志状态码和字节数 | `gawk -f examples/scripts/log-summary.awk examples/data/access.log` |
| `join.awk` | 把库存连接到订单 | `gawk -f examples/scripts/join.awk examples/data/inventory.tsv examples/data/orders.tsv` |
| `dedupe.awk` | 按整行去重 | `gawk -f examples/scripts/dedupe.awk examples/data/poem.txt` |
| `sales-report.awk` | 按地区生成固定宽度销售报表 | `gawk -f examples/scripts/sales-report.awk examples/data/sales.csv` |
| `wordfreq.awk` | 统计词频 | <code>gawk -f examples/scripts/wordfreq.awk examples/data/poem.txt &#124; sort -k2,2nr</code> |

`join.awk` 依赖“第一个文件是库存、第二个文件是订单”的顺序。换文件顺序会得到错误结果。
