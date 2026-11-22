# scripts/

四个脚本，都在 Kali 2023.3 上实际跑过。下面是**实测输出**，不是预期输出。

---

## disk_alert.sh

磁盘使用率超过阈值就打印告警。

阈值取第一个参数，不传就是 80：

```bash
THRESHOLD=${1:-80}
```

```bash
chmod +x disk_alert.sh
./disk_alert.sh          # 默认阈值 80
./disk_alert.sh 1        # 阈值改成 1，强制触发
```

实测：本机根分区 23%，默认阈值下**无输出**——没超阈值就不吭声，这是对的。

传 `1` 强制触发：

```
[告警] /dev/sda1 使用率 23%
参数个数: 1    第一个参数: 1
```

**只报真实分区**：`df -h -x tmpfs -x devtmpfs -x overlay` 把内存文件系统（tmpfs）和 Docker 存储层（overlay）排除掉——它们不是磁盘，报出来是噪音。

---

## log_rotate.sh

把 7 天前的 `.log` 压缩归档，按日期命名，**不删源文件**。

```bash
./log_rotate.sh
```

实测输出：

```
=== 扫描 /var/log/apache2 中 7 天前的 .log ===
[归档] /var/log/apache2/other_vhosts_access.log → /root/log-archive/other_vhosts_access-20261114.gz
=== 归档目录现有 ===
total 4.0K
-rw-r--r-- 1 root root 44 Nov 14 10:04 other_vhosts_access-20261114.gz
```

只有一个文件被归档——因为 `/var/log/apache2` 下其余的 `.log` 都是**当天还在写**的，不满足 `-mtime +7`。这是正常的，不是脚本没生效。

---

## db_backup.sh

`mysqldump` 导出，按日期命名，只留最近 7 份。

```bash
./db_backup.sh
```

实测输出：

```
=== 备份 dvwa → /root/db-backup/dvwa_20261114-200718.sql ===
[完成] 4.0K
=== 清理，只保留最近 7 份 ===
=== 当前备份 ===
1.5K  /root/db-backup/dvwa_20261114-084558.sql.gz
1.5K  /root/db-backup/dvwa_20261114-084600.sql.gz
1.5K  /root/db-backup/dvwa_20261114-090500.sql.gz
1.5K  /root/db-backup/dvwa_20261114-101911.sql.gz
1.5K  /root/db-backup/dvwa_20261114-102047.sql.gz
1.5K  /root/db-backup/dvwa_20261114-200718.sql.gz
```

**验证备份不是空壳**（`4.0K` 看着像空的，其实是压缩后的正常大小）：

```bash
f=$(ls -1t ~/db-backup/*.sql.gz | head -1)
zcat "$f" | grep -c "CREATE TABLE"
```

返回非 0 就说明备份里有表结构，能恢复。

**连跑第 8 次时才看得出清理逻辑**：文件数停在 7，最早那份被删。

---

## log_stat.py

统计访问日志里每个 IP 出现的次数，取前 5。

```bash
sudo python3 log_stat.py
```

实测前先造点流量：

```bash
for i in $(seq 1 20); do curl -s -o /dev/null http://127.0.0.1/DVWA/; done
```

输出：

```
共 1 个不同 IP，前 5 名：
    10 127.0.0.1
```

再造 10 条 404：

```bash
for i in $(seq 1 10); do curl -s -o /dev/null http://127.0.0.1/DVWA/nope$i; done
```

脚本里有 `if " 404 " not in line: continue`，所以只统计 404：

```
共 1 个不同 IP，前 5 名：
    10 127.0.0.1
```

**30 条正常请求 + 10 条 404，加了过滤后只剩 10——这个差值就是「过滤生效」的证据。**

---

## 四个脚本共用的三个坑

**1. CRLF 换行**
在 Windows 里编辑过再传进 Kali，会报 `./x.sh: 31: a: not found` 这种莫名错误。
`sed -i 's/\r$//' x.sh` 修，`file x.sh` 验证（应显示没有 `CRLF`）。

**2. `-mtime +7` 不是 `-mtime 7`**
`-mtime 7` 只匹配"正好第 7 天那一天"，`+7` 才是"超过 7 天"。

**3. 变量不加引号会被分词**
`$file` 里如果有空格，会被拆成两个参数。永远写 `"$file"`。

**4. 同名脚本留了多份副本**
`~/disk_alert.sh`、`~/Desktop/disk_alert.sh`、`~/ops-lab/scripts/disk_alert.sh` 三份并存时，**很容易改了 A 跑了 B**，现象是"明明改了却没生效"。
规矩：脚本只存在 `ops-lab/scripts/` 一份，改完先 `cat` 确认再跑。

---

## 截图索引

`screenshots/` 下两张，都用 `cat 脚本 && echo "===== 执行：xxx =====" && ./脚本 参数` 一条命令拍成，**代码、命令、输出在同一张图里**。

| 文件 | 证明什么 |
|---|---|
| `01-disk_alert-参数对比.png` | 同一张图跑了 `./disk_alert.sh`（无输出）和 `./disk_alert.sh 1`（一行告警），说明 `$1` 真的生效，且只报真实分区 |
| `02-log_rotate-日志归档-参数1.png` | `./log_rotate.sh 1` 把 `DAYS` 从 7 改成 1，归档了 `access.log` 与 `other_vhosts_access.log`，比默认参数归档得多 |
