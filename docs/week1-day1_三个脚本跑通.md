# Week 1 · Day 1（11/14）：把三个 Shell 脚本跑通

> 8 周计划第 1 天。今天只做一件事：**三个脚本在本机跑出结果**。
> 时间：3 小时。前 90 分钟装/传/跑，后 90 分钟看报错、改、再跑。

---

## 零、先纠正一个观念

**脚本不是"背下来的"，是"改出来的"。**

你上次写 `log_rotate.sh` 报 `find: unknown predicate '-verbose'`——那不是你不会，那是 find 的版本差异。**真实运维每天都在撞这种错。**

今天允许报错。**报错是过程，跑通才算完成。**

---

## 一、准备目录（10 分钟）

```bash
mkdir -p ~/ops-lab/scripts
cd ~/ops-lab/scripts
pwd          # 应该显示 /root/ops-lab/scripts
```

**`pwd` 这一步别省。** 你之前 `php test.php` 报 `Could not open input file`，就是因为人在 `/root`，文件在 `/root/Desktop`。

---

## 二、把三个文件弄进来（20 分钟）

**三个文件在 Windows 这边：**

```
C:\Users\1\Documents\deepseek-harness\default-workspace\ops-lab\scripts\
├── disk_alert.sh
├── log_rotate.sh
└── db_backup.sh
```

### 方法 A：VMware 拖拽（推荐）

从 Windows 资源管理器**直接拖进 Kali 的桌面或终端窗口**。

文件会落到 `/root/Desktop/` 或当前目录。

### 方法 B：复制粘贴

打开 Windows 上的 `.sh` 文件 → 全选 → Ctrl+C → Kali 里开 `mousepad` → Ctrl+V → Ctrl+S

```bash
mousepad disk_alert.sh
```

⚠️ **不要直接粘到终端里。** 终端里换行就执行了，粘 20 行脚本会炸成一堆报错。

### 方法 C：如果拖拽失败，手打第一个脚本

`disk_alert.sh` 只有 9 行，手打一遍反而是最好的练习：

```bash
nano disk_alert.sh
```

打完 `Ctrl+O` → 回车 → `Ctrl+X`

---

## 三、跑第一个：disk_alert.sh（25 分钟）

```bash
chmod +x disk_alert.sh
./disk_alert.sh
```

### 预期结果 A：什么都没打印

**这可能是对的。** Kali 的磁盘通常用不到 80%。

**验证办法——把阈值临时改小：**

```bash
# 直接改文件里的 THRESHOLD
mousepad disk_alert.sh      # 把 THRESHOLD=80 改成 THRESHOLD=1
./disk_alert.sh
```

**改成 1 之后必须刷出一堆 `[告警]`。** 如果还是一行没有，说明脚本有问题。

### 常见报错

| 报错 | 原因 | 怎么改 |
|---|---|---|
| `Permission denied` | 没执行权限 | `chmod +x disk_alert.sh` |
| `bash: ./disk_alert.sh: /bin/bash^M: bad interpreter` | **Windows 换行符** | `sed -i 's/\r$//' disk_alert.sh` |
| `awk: cmd. line:1: unexpected newline` | awk 里的引号没配对 | 检查 `'` 和 `"` 的位置 |
| 什么都没打印也没报错 | 阈值太高 或 `NR>1` 写错 | 先 `df -h` 看看真实使用率 |

**`^M` 那个坑最典型** —— Windows 的换行是 `\r\n`，Linux 只认 `\n`，多出来的 `\r` 会被当成命令的一部分。

**一条命令批量修三个脚本：**

```bash
sed -i 's/\r$//' *.sh
```

---

## 四、跑第二个：log_rotate.sh（25 分钟）

```bash
./log_rotate.sh
```

### 预期结果

```
=== 扫描 /var/log/apache2 中 7 天前的 .log ===
[归档] /var/log/apache2/access.log → /root/log-archive/access-20261114.gz
=== 归档目录现有 ===
-rw-r--r-- 1 root root  12K Nov 14 08:30 access-20261114.gz
```

### ⚠️ 大概率什么都不归档，这也是对的

因为 `/var/log/apache2/*.log` 是**当前正在写的日志**，修改时间是"刚才"，不是 7 天前。

**`-mtime +7` 找的是"7 天没动过的文件"，正在写的日志当然不符合。**

### 怎么造一个"7 天前的日志"来测

```bash
# 复制一份日志，然后把时间改成 10 天前
sudo cp /var/log/apache2/access.log /var/log/apache2/old-test.log
sudo touch -d "10 days ago" /var/log/apache2/old-test.log

# 再跑
./log_rotate.sh
```

**这次应该能看到 `[归档] ... old-test.log → .../old-test-20261114.gz`。**

```bash
# 确认归档文件真的存在、大小对不对
ls -lh ~/log-archive/
zcat ~/log-archive/old-test-20261114.gz | head -3
```

**`zcat` 能直接看压缩包内容** —— 这个命令运维天天用。

---

## 五、跑第三个：db_backup.sh（25 分钟）

```bash
./db_backup.sh
```

### 前提：MySQL 里有 dvwa 这个库

你之前已经验证过：

```bash
mysql -h 127.0.0.1 -u dvwa -p'p@ssw0rd' dvwa -e "show tables;"
```

**如果能列出表，就能备份。**

### 预期结果

```
=== 备份 dvwa → /root/db-backup/dvwa_20261114-083000.sql ===
[完成] 88K
=== 清理，只保留最近 7 份 ===
=== 当前备份 ===
88K /root/db-backup/dvwa_20261114-083000.sql.gz
```

### 常见报错

| 报错 | 原因 |
|---|---|
| `command not found: mysqldump` | 装了 mariadb-client 但没 mysqldump，`sudo apt install mariadb-client -y` |
| `Access denied for user 'dvwa'` | 密码错了，注意 `-p` 后面**不能有空格**：`-p"$DB_PASS"` |
| 备份文件 0 字节 | mysqldump 失败了但 `>` 已经把文件创建了 → 脚本里 `[ ! -s "$FILE" ]` 就是防这个 |
| `[失败] mysqldump 出错` | 把 `2>/dev/null` 临时去掉，看真实报错：`mysqldump ... > file` |

**调试技巧：先把 `2>/dev/null` 去掉跑一次，看到真错误再改回来。** 这个习惯要养成——**`2>/dev/null` 会把有用的错误也一起藏起来。**

### 验证备份能不能用

```bash
# 看压缩包里前几行
zcat ~/db-backup/dvwa_*.sql.gz | head -20

# 应该能看到 CREATE TABLE 和 INSERT 语句
```

**备份没验证过 = 没有备份。** 这句话是运维的铁律。

### 多跑几次，观察"只留 7 份"

```bash
for i in 1 2 3 4 5 6 7 8 9; do ./db_backup.sh; sleep 1; done
ls ~/db-backup/
```

**应该只剩 7 个文件。** 如果剩 9 个，说明 `tail -n +$((KEEP + 1))` 算错了。

---

## 六、三个都跑通之后（30 分钟）

**给每个脚本截一张图。** 截图要求：

| 截图 | 要包含什么 |
|---|---|
| 1 | `chmod +x` + `./disk_alert.sh` 输出（阈值改 1 之后那堆告警） |
| 2 | `./log_rotate.sh` 输出的 `[归档]` 那行 + `ls -lh ~/log-archive/` |
| 3 | `./db_backup.sh` 输出的 `[完成]` + `ls -lh ~/db-backup/` + `zcat ... \| head` |

**截图标准：能看清输入的命令和输出**（不是只截结果）。

---

## 七、今天必须能回答的 4 个问题

**明天讲 Docker 之前，先确认这 4 个能答上来：**

**Q1** `df -h | awk 'NR>1 {...}'` 里的 `NR>1` 是干什么的？去掉会怎样？

**Q2** `gzip file` 和 `gzip -c file > out.gz` 有什么区别？

**Q3** `mysqldump ... > backup.sql` 里的 `>` 和 `2>/dev/null` 分别管什么？

**Q4** `ls -1t *.gz | tail -n +8` 为什么能实现"只留 7 份"？

---

## 八、卡住的时候

**按顺序试：**

1. `pwd` 看在不在对的目录
2. `ls -l` 看文件在不在、有没有 `x` 权限
3. `sed -i 's/\r$//' *.sh` 修换行符
4. `bash -x ./script.sh` **单步调试**，会打印每一行执行的命令
5. 把报错原样发我

**`bash -x` 是今天最有价值的一个新工具。** 它会把脚本每一行展开打印出来，卡在哪一行一眼就看见。

```bash
bash -x ./disk_alert.sh
```

---

## 九、今天的验收

```
□ disk_alert.sh 改阈值到 1 后能刷出告警
□ log_rotate.sh 能归档造出来的 old-test.log，zcat 能看内容
□ db_backup.sh 能生成 .sql.gz，zcat 能看到 CREATE TABLE
□ 连跑 9 次后 db-backup 里只剩 7 个文件
□ 4 个问题能答上来
□ 3 张截图
```

**做到就是第 1 天完成。做不到就明天继续，不跳。**
