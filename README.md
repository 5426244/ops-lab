# ops-lab

2027 届 · 机械设计制造及其自动化 → IT 运维 / 安全运维方向
Linux · Shell 脚本 · 容器 · 监控

---

## 这个仓库解决什么问题

是**能跑起来的能处理运维工作的东西**。

| 目录 |解决了什么问题|
|---|---|
| [scripts/](./scripts/) | 日常巡检与备份的自动化：磁盘告警、日志归档、数据库备份 |
---

## scripts/

三个脚本，都在 Kali 上实际跑过。

| 脚本 | 干什么 | 关键点 |
|---|---|---|
| [disk_alert.sh](./scripts/disk_alert.sh) | 磁盘使用率超 80% 打印告警 | `df -h` + `awk 'NR>1'` 跳表头 + `gsub` 去百分号 |
| [log_rotate.sh](./scripts/log_rotate.sh) | 7 天前的 `.log` 压缩归档，按日期命名 | `find -mtime +7` + `gzip -c` + `$(date)` + `${name%.log}` |
| [db_backup.sh](./scripts/db_backup.sh) | `mysqldump` 导出、按日期命名、只留 7 份 | `>` 重定向 + `$?` 退出码 + `ls -1t | tail -n +8` |

### 跑法

```bash
chmod +x scripts/*.sh
./scripts/disk_alert.sh
./scripts/log_rotate.sh
./scripts/db_backup.sh
```

---

## 几个踩过的坑

**1. `find -verbose` 不存在**
Kali 的 find 不认 `-verbose`，报 `find: unknown predicate '-verbose'`。
要边删边打印用 `-delete -print`。

**2. `-mtime +7` 和 `-mtime 7` 不是一回事**
`-mtime 7` 只匹配"正好第 7 天那一天"，`-mtime +7` 才是"超过 7 天"。
做日志清理要的是后者。

**3. `[ ]` 里面的空格不能省**
`[ "$usage" -ge 80 ]` 是对的，`["$usage" -ge 80]` 会报 `command not found`。
因为 `[` 本身是个命令，不是语法符号。

**4. 变量不加引号会被"分词"**
`$file` 如果路径里有空格，会被拆成两个参数。养成习惯：**永远写 `"$file"`**。

---
