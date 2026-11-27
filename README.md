# ops-lab

2027 届 · 机械设计制造及其自动化 → IT 运维 / 安全运维方向
Linux · Shell 脚本 · 容器 · 监控

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
| [k8s/](./k8s/) | 单节点集群、Deployment/Service、镜像加速踩坑、三个故障排障 | ✅ k3s + nginx + NodePort 可访问；CrashLoopBackOff / ImagePullBackOff / OOMKilled 亲手造过 |
| [monitor/](./monitor/) | 监控与告警链路 | ✅ 三容器 + 1860 看板 |
| [cloud/](./cloud/) | 云上开机器与对象存储：ECS + 安全组 + nginx + OSS 私有桶 | ✅ 含 3 张实测截图 |
| [windows/](./windows/) | Windows Server 域环境与安全基线：用户与组、密码策略与账户锁定、事件日志取证 | ✅ 含 4 张实测截图 |
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
| docker/myweb/Dockerfile | 基于 nginx，`COPY` 自定义首页 |
| docker/stack/docker-compose.yml | nginx + mysql 5.7 双服务 |

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

## python/

Shell 写起来别扭的活儿交给 Python：网络探测和文本统计。

| 文件 | 说明 |
|---|---|
| [port_scan.py](./python/port_scan.py) | socket 扫端口，`connect_ex()` 返回 0 即开放 |
| [log_stat.py](./python/log_stat.py) | 统计访问日志里各 IP 出现次数，支持 `--top N` |

实测：扫 `192.168.59.130` 的 `21/22/23/80/1524` 五个端口全通（1524 是 Metasploitable2 的后门端口）；`log_stat.py` 对 30 条正常流量统计出 1 个 IP、筛 404 后剩 10 条。

一个自己补上的坑：`--top` 后面不给数字会 `IndexError: list index out of range`，因为 `args[i + 1]` 越界。修法是先判断 `i + 1 >= len(args)` 再取值，顺便用 `try/except ValueError` 挡住非数字。

---

## k8s/

单节点集群（k3s），从部署到排障到持久化走了一遍。

| 文件 | 说明 |
|---|---|
| [k8s/README.md](./k8s/README.md) | 为什么用 k3s、pause 镜像卡点、四类重启原因、探针、PVC、有状态部署 |
| [k8s/manifests/web-pvc.yaml](./k8s/manifests/web-pvc.yaml) | 一份 YAML 两个对象：PVC + Deployment |
| [k8s/screenshots/](./k8s/screenshots/) | 10 张实测截图，编号 01–10 |

三个值得单独说的点：

**1. minikube 起不来，不是我的问题**
`kubelet` 从阿里云镜像拉取报 `invalid checksum: ... bad response code: 404`。逐个探测 7 个版本的 `kubelet.sha256` 全是 404，`stable.txt` 停在 `v1.13.4`（2018 年）——镜像站的 K8s 二进制目录已停更。改用 k3s `v1.37.2+k3s1`。

**2. Pod 卡 `ContainerCreating` 但看不到 `Pulling`**
`describe` 的 Events 里翻到 `FailedCreatePodSandBox`：`pause` 沙箱镜像从 `docker.io` 拉不到。**pause 是每个 Pod 的地基镜像，它失败时不会报 `ImagePullBackOff`**，报的是 sandbox 错误。配 `/etc/rancher/k3s/registries.yaml` 走镜像加速解决。

**3. 四类重启原因，全亲手造过**
程序自己退出（`exit 1`）、镜像拉不到（`403 not in allowlist`）、内存超限（`OOMKilled` / `exit 137`）、探针失败（`Running` 但 RESTARTS 在涨）。判据：**有退出码说明容器跑过，没退出码说明没跑起来**。

另外三个进阶：`readinessProbe` 失败时 Pod 是 `Running` 但 `READY 0/1`，不进 Service 后端，所以发布卡住而服务不中断（零宕机发布）；PVC 的 `WaitForFirstConsumer` 表示延迟绑定，Pod 调度完才建 PV；**Deployment 挂 PVC 后删 Pod 重建，页面内容不变 —— 判据是 PVC 的 AGE 远大于 Pod 的 AGE**（老卷 + 新容器 + 老内容）。

---

## monitor/

监控链路三个容器串起来：

```
node-exporter:9100  →  Prometheus:9090 拉取  →  Grafana:3000 出图
```

| 文件 | 说明 |
|---|---|
| [monitor/README.md](./monitor/README.md) | 三容器启动、5 条 PromQL、数据源配置、排障记录 |
| [monitor/prometheus.yml](./monitor/prometheus.yml) | 两个 job：`prometheus` 和 `node` |
| [monitor/screenshots/](./monitor/screenshots/) | targets 全 UP、数据源连通、看板 1860 |

**为什么不用 apt 装 Grafana**：Kali 的 Grafana 13 装完后前端资源请求返回 302 跳到 `/login`，`public/views/index.html` 里的 Go 模板占位符没被渲染，说明二进制和前端文件版本不匹配（dpkg 中途失败）。改用官方镜像跑容器，文件是配套的。

**一个必须记住的配置**：Grafana 里的数据源地址要填 `http://prometheus:9090`，**不能填 `127.0.0.1:9090`**——容器里的 `127.0.0.1` 指的是它自己，不是宿主机。同一 Docker 网络里直接用容器名互访。

---

## cloud/

一台按量付费的阿里云 ECS，从开通到释放走了一遍完整流程，外加一个私有 OSS 桶。

| 环节 | 做了什么 | 关键判据 |
|---|---|---|
| 开通 | 华北2 · 2核2GiB · Debian 12 · 按量 ¥0.123/小时 | 换系统要选**普通停机模式**，否则可能「库存不足启动失败」 |
| 登录 | 密钥对拿不到私钥 → Workbench 免密通道 → 开密码登录 | `sshd -T \| grep passwordauth` 应为 `yes` |
| 安全组 | 默认只放 22，手动放行 80/80 | 加完立刻 `Test-NetConnection -Port 80` 验证 |
| nginx | `apt-get install nginx`，换成自定义页再公网访问 | `curl -I` 拿 `200` + `Server: nginx/1.22.1` |
| OSS | 建私有桶、传对象、用裸 URL 验证被拒 | 403 + `because of bucket acl` + `EC 0003-00000001` |

### 三种 403 必须分清

同样返回 `AccessDenied`，含义完全不同：

| 访问方式 | Message | EC |
|---|---|---|
| 对象 URL 无签名 | `because of bucket acl` | `0003-00000001` ← 权限生效 |
| Bucket 根无签名 | `Anonymous user has no right to access this bucket` | `0003-00000002` |
| 带签名但已过期 | `Request has expired` | `0002-00000069` ← 凭据过期，与权限无关 |

**辨析方法：看 XML 里有没有 `<Expires>` 元素——有是签名过期，没有才是权限拒绝。**

详细过程见 [cloud/README.md](./cloud/README.md)（含开通三个坑、安全组字段对照、费用与释放）。

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

---

## 待办（按 8 周计划推进）

- [x] Week 1：三个 Shell 脚本 + Python 基础（第 1–7 天）
- [x] Week 2：Docker 三天（提前完成）+ Linux 加固四天
- [x] Week 3：SQL + 备份恢复实战 + logrotate + 运维手册
- [x] Week 4：Python 小工具（`port_scan.py` / `log_stat.py`）+ Prometheus/Grafana
- [x] Week 5–6：K8s —— 部署 ✅（k3s + nginx + NodePort）、排障 ✅（四类重启 + 探针 + PVC + 有状态部署）、阿里云 ✅（ECS + 安全组 + nginx + OSS 私有桶，已释放）
- [ ] Week 6 剩余：云监控（CloudMonitor）接入
- [ ] Week 7：Windows Server + 网络设备核查
- [ ] Week 8：仓库整合 + 简历改版





