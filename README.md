# ops-lab

2027 届 · 机械设计制造及其自动化 → IT 运维 / 安全运维方向
Linux · Shell 脚本 · 容器 · 监控
联系方式：2463037277@qq.com · 155-1131-0037
---

## 这个仓库解决什么问题

不是教程笔记，是**能跑起来的东西**。每一项都对应一类运维日常工作：

| 目录 | 解决什么问题 | 状态 |
|---|---|---|
| [scripts/](./scripts/) | 日常巡检与备份的自动化：磁盘告警、日志归档、数据库备份 | ✅ 3 个脚本已跑通 |
| [docker/](./docker/) | 用容器跑应用：部署、编排、数据持久化 | ✅ 含 3 张实测截图 |
| [checklist/](./checklist/) | 巡检清单：Linux 加固 20 条 + 巡检采集脚本 | ✅ 20 条已实测填写 |
| [sql/](./sql/) | 运维常用查询：聚合、分组、多表、子查询 | ✅ 建库脚本 + 10 题答案 |
| [python/](./python/) | 比 Shell 更合适的场景：端口探测、日志统计 | ✅ port_scan.py 扫 5 端口全通 |
| [monitor/](./monitor/) | 监控与告警链路 | ✅ 三容器 + 1860 看板 |
| [docs/](./docs/) | 运维手册、排障记录、速查表 | ✅ 6 份 |

---

## scripts/

三个脚本，都在 Kali 上实际跑过。

| 脚本 | 干什么 | 关键点 |
|---|---|---|
| [disk_alert.sh](./scripts/disk_alert.sh) | 磁盘使用率超 80% 打印告警 | `df -h` + `awk 'NR>1'` 跳表头 + `gsub` 去百分号 |
| [log_rotate.sh](./scripts/log_rotate.sh) | 7 天前的 `.log` 压缩归档，按日期命名 | `find -mtime +7` + `gzip -c` + `$(date)` + `${name%.log}` |
| [db_backup.sh](./scripts/db_backup.sh) | `mysqldump` 导出、按日期命名、只留 7 份 | `>` 重定向 + `$?` 退出码 + `ls -1t | tail -n +8` |
| [log_stat.py](./scripts/log_stat.py) | 统计访问日志里各 IP 出现次数，取前 5 | `split()` 取第 0 段 + 字典计数 + `sorted(key=...)` |

### 跑法

```bash
chmod +x scripts/*.sh
./scripts/disk_alert.sh
./scripts/log_rotate.sh
./scripts/db_backup.sh
sudo python3 scripts/log_stat.py
```

---

## docker/

一句话总结：**`docker history` 看镜像分层，`Dockerfile` 改一行就得重新 build，改了不 build 冰箱里还是旧菜。**

| 文件 | 说明 |
|---|---|
| [docker/README.md](./docker/README.md) | 七个环节、三个实验对比、四个坑 |

三个实验的差别（只看 `curl` 返回）：

| 镜像 | Dockerfile 内容 | 页面 |
|---|---|---|
| `myweb:nocopy` | 只有 `FROM nginx` | Welcome to nginx! |
| `myweb:run` | 用 `RUN echo` 写首页 | `<h1>RUN 写的</h1>` |
| `myweb:v1` | 用 `COPY index.html` 写首页 | `<h1>Hello from 张野的镜像</h1>` |

---

## checklist/

Linux 加固 20 条，**不是抄的，是逐条在这台 Kali 上跑命令验证过的**。

| 文件 | 说明 |
|---|---|
| [Linux加固20条.md](./checklist/Linux加固20条.md) | 20 条判定表：✅8 / ⚠️5 / ❌6 / —1 |
| [linux-audit.sh](./checklist/linux-audit.sh) | 20 段证据采集，一条命令出全部现状 |

两个「假加固」的教训：

**1. 改了 `login.defs` 不等于改完**
`PASS_MAX_DAYS` 改成 90 后，`chage -l root` 仍显示 `Password expires: never`。
因为 `login.defs` 只对**新建账号**生效，存量账号必须 `chage -M 90 root`。

**2. 注释掉的配置行仍走默认值**
`#PermitRootLogin prohibit-password` 看起来像"禁止了"，实际生效值要用 `sshd -T` 看，
`sshd -T | grep permitrootlogin` 才是真相。

---

## sql/

| 文件 | 说明 |
|---|---|
| [sql-practice.sql](./sql/sql-practice.sql) | 建库建表：`dept` 5 行 + `emp` 20 行 |
| [10题答案与验证.md](./sql/10题答案与验证.md) | 10 条查询 + 预期结果 |

覆盖：`WHERE` / `ORDER BY` / `GROUP BY` + `HAVING` / `JOIN` / `LEFT JOIN` / 子查询 / 日期区间筛选。

一个容易踩的点：**`COUNT(*)` 数行数（NULL 行也算），`COUNT(列名)` 数非 NULL。**
LEFT JOIN 出空行时，前者给 1，后者给 0。

---

## docs/

| 文件 | 说明 |
|---|---|
| [速查手册_命令与脚本.md](./docs/速查手册_命令与脚本.md) | 12 章：命令组成、程序索引、同名选项不同义、符号、Linux/Shell/Python、报错→解法 |
| [Python_按天整理_第1-7天.md](./docs/Python_按天整理_第1-7天.md) | Python 入门 7 天，每天一节 + 关键点表 |
| [week1-day1_三个脚本跑通.md](./docs/week1-day1_三个脚本跑通.md) | 三个 Shell 脚本的当日任务单 |
| [week1-day1_知识点详解.md](./docs/week1-day1_知识点详解.md) | 15 个知识点 + 调试三件套（`file` / `bash -n` / `bash -x`） |

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

**5. 脚本存成 CRLF 会报奇怪的错**
`./log_rotate.sh: 31: a: not found` 这种，八成是 Windows 换行。
`sed -i 's/\r$//' 文件名` 修，`file 文件名` 看有没有 `CRLF`。

**6. `docker rm` 删容器，`docker rmi` 删镜像**
报 `No such container: myweb` 是因为 myweb 是镜像；
报 `No such image: r1:latest` 是因为 r1 是容器。


