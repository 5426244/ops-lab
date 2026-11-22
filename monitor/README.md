# monitor/ — 监控链路

用 Docker 跑 Prometheus + node_exporter + Grafana，采集本机指标并出图。

## 为什么用 Docker 而不是 apt

在 Kali 上 `apt install prometheus grafana` 踩了两个坑：

| 坑 | 现象 | 结论 |
|---|---|---|
| Grafana 不在 Kali 源 | `E: Unable to Locate Package grafana` | 要加官方源 |
| Grafana 官方 deb 包前端资源与二进制不匹配 | 页面显示 `Grafana has failed to load its application files`，`/public/build/*.js` 返回 302 跳登录页 | **apt 包在 Kali 上不可靠** |

改用官方镜像后一次成功。生产环境里 Grafana / Prometheus 基本都是容器部署，这也是更规范的做法。

## 三个容器

| 容器 | 镜像 | 端口 | 作用 |
|---|---|---|---|
| prometheus | `prom/prometheus` | 9090 | 拉取并存储指标 |
| node-exporter | `prom/node-exporter` | 9100 | 暴露 CPU / 内存 / 磁盘 / 网络指标 |
| grafana | `grafana/grafana-oss` | 3000 | 查询 Prometheus 并出图 |

## 一条命令起全部

见仓库根目录 `../新环境恢复/setup.sh`，或手打：

```bash
docker network create mon

docker run -d --name node-exporter --restart unless-stopped \
  --network mon -p 9100:9100 \
  --pid=host -v /:/host:ro,rslave \
  prom/node-exporter --path.rootfs=/host

docker run -d --name prometheus --restart unless-stopped \
  --network mon -p 9090:9090 \
  -v ~/ops-lab/monitor/prometheus.yml:/etc/prometheus/prometheus.yml \
  prom/prometheus

docker run -d --name grafana --restart unless-stopped \
  --network mon -p 3000:3000 \
  grafana/grafana-oss
```

## 验证链路（三步）

### 1. 三个容器都 Up

```bash
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
```

### 2. Prometheus 抓到了两个 target

```bash
curl -s 'http://127.0.0.1:9090/api/v1/query?query=up' | python3 -m json.tool
```

正常返回两个 job，值都是 `"1"`：

```json
{
  "status": "success",
  "data": {
    "result": [
      { "metric": { "instance": "node-exporter:9100", "job": "node" }, "value": [1763, "1"] },
      { "metric": { "instance": "localhost:9090", "job": "prometheus" }, "value": [1763, "1"] }
    ]
  }
}
```

`"1"` = 抓取成功，`"0"` = 目标挂了。

### 3. CPU 使用率能算出来

```bash
curl -sS --data-urlencode 'query=100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)' http://127.0.0.1:9090/api/v1/query | python3 -m json.tool
```

`value` 里那个小数就是当前 CPU 占用百分比。

## 指标查询的写法

| 想查什么 | PromQL |
|---|---|
| CPU 使用率 % | `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[1m])) * 100)` |
| 内存使用率 % | `100 * (1 - node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)` |
| 磁盘使用率 % | `100 * (1 - node_filesystem_avail_bytes{mountpoint="/"} / node_filesystem_size_bytes{mountpoint="/"})` |
| 系统负载 | `node_load1` |
| 开机时长 | `time() - node_boot_time_seconds` |

## Grafana 接数据源

1. 浏览器打开 `http://127.0.0.1:3000`，账号密码 `admin` / `admin`，首次登录改密码
2. 左侧 **Connections → Data sources → Add data source → Prometheus**
3. Connection URL 填 **`http://prometheus:9090`**（同一 Docker 网络内用容器名，不要写 127.0.0.1）
4. **Save & test**，出现绿色 `Successfully queried the Prometheus API` 即可

> 坑：如果 Grafana 和 Prometheus 在同一 `mon` 网络里，数据源地址必须写容器名 `prometheus:9090`。
> 写 `127.0.0.1:9090` 会指向 Grafana 容器自己，一定连不上。

## Grafana 导入看板

**Dashboards → New → Import → 输入 ID `1860`（Node Exporter Full）→ 选数据源 → Import。**

1860 是社区最常用的 node_exporter 看板，导入后直接有 CPU、内存、磁盘、网络十几个图。

## 排障记录

| 现象 | 原因 | 解法 |
|---|---|---|
| 容器全 `Exited (255)` | 宿主重启，容器没设重启策略 | 加 `--restart unless-stopped` |
| `curl localhost:9090` 空 / `Failed to connect` | Kali 的 `localhost` 走 IPv6（`::1`），服务只听 IPv4 | 一律用 `127.0.0.1` |
| `systemctl is-active` 是 active 但端口不通 | SysV wrapper 假活，进程实际没起 | 只看 `ss -tlnp \| grep 端口` + `curl 健康接口` |
| Prometheus 网页 404 | Debian 包不带 React UI | 用官方镜像，或只走 HTTP API |
| Grafana 数据源连不上 | 数据源写了 127.0.0.1 | 改成容器名 `prometheus:9090` |

## 面试 30 秒

> 我用 Docker 起了 Prometheus + node_exporter + Grafana 这套监控。node_exporter 通过 `--pid=host` 和挂载宿主根目录采集真实的物理机指标；Prometheus 每 15 秒拉一次，配置写在 `prometheus.yml` 里；Grafana 通过容器网络连 Prometheus，导入 1860 看板出图。判断采集是否正常，看 `up` 这个指标——每个 target 的值是 1 就说明抓取成功，0 就是目标挂了。

## 实测结果（2026-11-22，Debian 13 opslab）

环境：Debian 13 (kernel 6.12)、Docker 26.1.5、2 核 2 GB 内存、根分区 23 GB。

```
$ docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
NAMES           STATUS          PORTS
grafana         Up 15 seconds   0.0.0.0:3000->3000/tcp
prometheus      Up 4 minutes    0.0.0.0:9090->9090/tcp
node-exporter   Up 5 minutes    0.0.0.0:9100->9100/tcp
```

```
$ curl -s 'http://127.0.0.1:9090/api/v1/query?query=up'
{"metric":{"instance":"node-exporter:9100","job":"node"},"value":[...,"1"]}
{"metric":{"instance":"localhost:9090","job":"prometheus"},"value":[...,"1"]}
```

看板 1860 出图后的实测数值（开机 1.5 小时、空闲状态）：

| 面板 | 值 |
|---|---|
| CPU Busy | 7.7% |
| Sys Load | 21.0% |
| RAM Used | 82.1%（2 GiB 总量） |
| SWAP Used | 34.6%（1 GiB 总量） |
| Root FS Used | 30.9%（23 GiB 总量） |
| Uptime | 1.5 hours |

> 刚导入看板时图上只有最右侧一小段曲线，是因为 Prometheus 才跑了十几分钟、只存了这些点。
> 时间范围选 `Last 1 hour` 或 `Last 15 minutes` 曲线就铺满了；选 `Last 24 hours` 大部分是空的，属正常。

两个坑（Docker Hub 与 curl）：

| 坑 | 现象 | 解法 |
|---|---|---|
| Docker Hub 拉不下来 | `Get "https://registry-1.docker.io/v2/": Client.Timeout exceeded` | 配 `/etc/docker/daemon.json` 的 `registry-mirrors`，或 `docker pull 加速器域名/镜像名` 后打回本地 tag |
| `curl: command not found` | setup.sh 检测到 docker 已装而跳过 apt，把 curl 也跳了 | `sudo apt install -y curl`（脚本已修） |

## 截图索引

| 文件 | 内容 |
|---|---|
| `screenshots/01-prometheus-targets-两个UP.png` | `http://127.0.0.1:9090/targets`，job=node 与 job=prometheus 均为 UP |
| `screenshots/02-grafana-datasource-连接成功.png` | 数据源 `http://prometheus:9090`，绿色 `Successfully queried the Prometheus API` |
| `screenshots/03-grafana-dashboard-1860.png` | Node Exporter Full 看板，CPU / 内存 / 网络 / 磁盘 均有数据 |
