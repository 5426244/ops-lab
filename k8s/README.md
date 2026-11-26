# k8s/ — 单节点集群与第一个应用

在 Debian 13 上用 **k3s** 起单节点集群，跑一个 nginx Deployment + NodePort Service。

## 环境

| 项 | 值 |
|---|---|
| 系统 | Debian GNU/Linux 13 (trixie)，kernel 6.12 |
| 主机名 | `opslab` |
| 规格 | 2 核 / 4 GB / 23 GB 根分区 |
| 集群 | k3s v1.37.2+k3s1（单节点，control-plane + worker 同机） |
| 容器运行时 | containerd（k3s 自带，**不读 Docker 的 daemon.json**） |

## 为什么用 k3s 而不是 minikube

先试的 minikube v1.39.0，失败在 K8s 二进制下载：

```
❌ Exiting due to K8S_INSTALL_FAILED: downloading kubelet: download failed:
   https://kubernetes.oss-cn-hangzhou.aliyuncs.com/kubernetes-release/release/v1.37.0/bin/linux/amd64/kubelet?checksum=...
   invalid checksum: Error downloading checksum file: bad response code: 404
```

探测镜像站真实可用版本，7 个候选全部 404：

```bash
for v in v1.34.0 v1.33.0 v1.32.0 v1.31.0 v1.30.0 v1.29.0 v1.28.3; do
  printf "%-9s %s\n" "$v" "$(curl -s -o /dev/null -w '%{http_code}' \
    https://kubernetes.oss-cn-hangzhou.aliyuncs.com/kubernetes-release/release/$v/bin/linux/amd64/kubelet.sha256)"
done
# 结果：v1.34.0 404 / v1.33.0 404 / v1.32.0 404 / v1.31.0 404
#       v1.30.0 404 / v1.29.0 404 / v1.28.3 404
```

阿里镜像的 `stable.txt` 还停在 **v1.13.4（2018 年）**，二进制目录实际已不服务。

改 k3s：单二进制、约 500 MB 内存、官方有中国镜像站。

```bash
curl -sfL https://rancher-mirror.rancher.cn/k3s/k3s-install.sh | INSTALL_K3S_MIRROR=cn sh -
```

装完配 kubectl：

```bash
mkdir -p ~/.kube
sudo cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
sudo chown $USER ~/.kube/config
kubectl get nodes
```

```
NAME     STATUS   ROLES                  AGE   VERSION
opslab   Ready    control-plane,master   97s   v1.37.2+k3s1
```

## 核心坑：所有 Pod 卡在 ContainerCreating

**现象**

```bash
kubectl get pods -n kube-system
```

```
coredns-577d995dff-plmqm              0/1   ContainerCreating   0   3h53m
helm-install-traefik-crd-zmqxq        0/1   ContainerCreating   0   3h53m
local-path-provisioner-56c6584955-... 0/1   ContainerCreating   0   3h53m
metrics-server-778c4649b4-2ccvm       0/1   ContainerCreating   0   3h53m
```

**定位**

```bash
kubectl describe pod -l app=web | tail -30
```

```
Warning  FailedCreatePodSandBox  ...  failed to create pod sandbox:
  failed to pull image "rancher/mirrored-pause:3.10.2":
  dial tcp 104.16.252.55:443: connect: connection refused
```

**根因**

`pause` 是每个 Pod 的**沙箱地基镜像**：K8s 先起一个极小的 pause 容器占住网络命名空间，再把业务容器塞进去。
它从 `docker.io` 拉，而 `docker.io` 国内不可达 → 沙箱建不起来 → **所有** Pod（含 k3s 自身的 coredns / traefik / metrics-server）全部停在 `ContainerCreating`。

注意：报的是 `FailedCreatePodSandBox` 而不是 `Pulling`，所以**不会**出现常见的 `ImagePullBackOff`，容易误判成别的问题。

**处置**

给 k3s 的 containerd 配镜像站（k3s 不读 `/etc/docker/daemon.json`）：

```bash
sudo mkdir -p /etc/rancher/k3s
sudo tee /etc/rancher/k3s/registries.yaml > /dev/null <<'EOF'
mirrors:
  docker.io:
    endpoint:
      - "https://docker.m.daocloud.io"
      - "https://docker.1ms.run"
EOF
sudo systemctl restart k3s
```

重启后 k3s 会用镜像站重新拉 pause（约 20–60 秒）。

**兜底：手动灌镜像 + 打 tag**

如果重启后仍拉不到，用 `crictl` 直接把镜像塞进 containerd，再打上 k3s 想要的 `docker.io/` 标签：

```bash
sudo k3s crictl pull docker.m.daocloud.io/rancher/mirrored-pause:3.10.2
sudo k3s ctr -n k8s.io images tag \
  docker.m.daocloud.io/rancher/mirrored-pause:3.10.2 \
  docker.io/rancher/mirrored-pause:3.10.2
kubectl delete pods -n kube-system --all
```

**验证地基修好**

```bash
kubectl get pods -n kube-system
```

```
coredns-577d995dff-dkbsl        1/1   Running
local-path-provisioner-...      1/1   Running
metrics-server-...              1/1   Running
traefik-68df944ff7-znl47        1/1   Running
svclb-traefik-d8f10c74-mgmv5    2/2   Running
helm-install-traefik-9wsvc      0/1   Completed
```

`Completed` 是 Helm 安装任务跑完退出，正常。

## 四层对象：从 Deployment 到能访问

| 层 | 作用 | 类比 Docker |
|---|---|---|
| **Deployment** | 声明「我要几个副本」，负责自愈与滚动更新 | compose 里的服务定义 |
| **ReplicaSet** | Deployment 每次改动生成一个 RS，保证副本数 | 无直接对应 |
| **Pod** | 最小调度单位，1 个（或几个）容器 + 共享网络栈 | 一个 `docker run` |
| **Service** | 给一组 Pod 一个固定 ClusterIP / NodePort，做负载均衡 | `-p` 端口映射 + 反代 |

**层级关系：`Deployment → ReplicaSet → Pod`，`Service` 通过 label selector 找 Pod。**

删 Pod 会被 Deployment 自动重建——这是自愈，也是「改配置靠删 Pod」不靠谱的原因。

## 实测结果（2026-11-23）

```bash
kubectl create deployment web --image=nginx:1.27
kubectl expose deployment web --port=80 --type=NodePort
```

```
$ kubectl get deploy,rs,pods,svc
NAME                     READY   UP-TO-DATE   AVAILABLE   AGE
deployment.apps/web      1/1     1            1           91m

NAME                               DESIRED   CURRENT   READY   AGE
replicaset.apps/web-69c6f74b8b     1         1         1       91m

NAME                               READY   STATUS    RESTARTS   AGE
pod/web-69c6f74b8b-wn9hv           1/1     Running   0          4m57s

NAME                 TYPE        CLUSTER-IP     EXTERNAL-IP   PORT(S)        AGE
service/kubernetes   ClusterIP   10.43.0.1      <none>        443/TCP        5h18m
service/web          NodePort    10.43.197.91   <none>        80:32676/TCP   2m31s
```

```
$ curl -I http://127.0.0.1:32676
HTTP/1.1 200 OK
Server: nginx/1.27.5
Content-Type: text/html
Content-Length: 615
```

`80:32676/TCP` —— 左边是 Service 在集群内的端口，右边是宿主机上真正监听的 NodePort。

## 命令速查

| 想干什么 | 命令 |
|---|---|
| 看节点 | `kubectl get nodes` |
| 看所有命名空间的 Pod | `kubectl get pods -A` |
| 看四层对象 | `kubectl get deploy,rs,pods,svc` |
| 实时盯 Pod 状态 | `kubectl get pods -w` |
| 看 Pod 事件（排障第一步） | `kubectl describe pod -l app=web` |
| 看日志 | `kubectl logs -l app=web --tail=20` |
| 进容器 | `kubectl exec -it deploy/web -- bash` |
| 建 Deployment | `kubectl create deployment web --image=nginx:1.27` |
| 暴露端口 | `kubectl expose deployment web --port=80 --type=NodePort` |
| 删 Pod 让它重建 | `kubectl delete pod -l app=web` |
| 删整个应用 | `kubectl delete deploy/web svc/web` |
| 看 containerd 里的镜像 | `sudo k3s crictl images` |

## 三个故障实测（2026-11-24）

三个故障对应三种状态，都是自己造的。下面每个都按「制造 → 现象 → 定位 → 结论 → 修」写。

### 排障固定顺序

从上往下查，查到哪步有答案就停：

| 顺序 | 命令 | 看什么 |
|---|---|---|
| 1 | `kubectl get pods` | STATUS 和 RESTARTS |
| 2 | `kubectl describe pod <名>` | **Events 段（在最后）** |
| 3 | `kubectl logs <名>` | 程序自己说什么 |
| 4 | `kubectl logs <名> --previous` | 崩溃前那次 |
| 5 | `kubectl get pod <名> -o yaml` | 配置写对没 |

两个要害：**`describe` 的 Events 在末尾**；**`logs --previous` 才是崩溃前**。

### 故障一：CrashLoopBackOff（程序自己退出）

**制造**

```bash
kubectl run crash --image=nginx:1.27 -- sh -c "echo 启动中; sleep 2; exit 1"
kubectl get pods -w
```

**现象**

```
crash   0/1   Running             0   3s
crash   0/1   Error               1   8s
crash   0/1   CrashLoopBackOff    1   12s
crash   0/1   CrashLoopBackOff    2   35s   ← 间隔变长
crash   0/1   CrashLoopBackOff    3   1m20s
```

`RESTARTS` 在涨，但**每次重启间隔越来越长**——这是 K8s 的退避（backoff），防止坏容器打满 CPU。

**定位**

```bash
kubectl describe pod crash | grep -A12 "Containers:"
kubectl logs crash --previous
```

证据链：

| 证据 | 值 | 含义 |
|---|---|---|
| `State` | `Waiting` / `CrashLoopBackOff` | 等下一次重启 |
| `Last State` | `Terminated` / `Reason: Error` | 上次是异常终止 |
| `Exit Code` | `1` | 程序自己认为失败 |
| `Args` | `sh -c echo 启动中 ; sleep 2 ; exit 1` | **命令原文就写着 `exit 1`** |
| `logs --previous` | `启动中` | 跑了两秒就退 |

**结论**：不是镜像问题、不是资源问题，是程序自身退出。

**一个坑**：`logs --previous` 有时报 `unable to retrieve container logs`——容器重启多次后旧实例被 containerd 回收，日志跟着没了。这时看 `Args` 段，命令原文比日志更直接。

**修**

```bash
kubectl run crash-fixed --image=nginx:1.27 -- sh -c "echo 修好了; sleep 3600"
kubectl get pods
```

```
crash-fixed   1/1   Running            0   10s   ← 同镜像，只是不退出
crash         0/1   CrashLoopBackOff   3   3m
```

### 故障二：ImagePullBackOff（镜像拉不到）

**制造**

```bash
kubectl run bad --image=nginx:9.99
kubectl get pods -w
```

**现象**（3 秒内两次跳变）

```
bad   0/1   ContainerCreating   0   6s
bad   0/1   ErrImagePull        0   30s
bad   0/1   ImagePullBackOff    0   37s
```

**定位**

```bash
kubectl describe pod bad | tail -8
```

```
Warning  Failed  ...  Failed to pull image "nginx:9.99":
  failed to resolve reference "docker.io/library/nginx:9.99":
  unexpected status from HEAD request to https://docker.m.daocloud.io/v2/library/nginx/manifests/9.99:
  403 Forbidden
  denied: 这镜像不在白名单 this image is not in the allowlist
```

**结论**：三层信息——K8s 层 `ImagePullBackOff`、请求层 `403`、原因层 `not in allowlist`。
因为 `9.99` 这个 tag 不存在，镜像站查不到就拒绝。

**镜像站不是有求必应的，它有白名单。**「同样的镜像别人能拉我不能拉」，很可能不是网络问题，是镜像站没收录。

**修**：换成存在的 tag（`nginx:1.27` 已在本地，`Pulled` 事件显示 `already present`）。

### 故障三：OOMKilled（内存超限被杀）

这个故障走了一段弯路，弯路本身有教学价值。

**第一轮：`8Mi` → 还是 Running**

```bash
kubectl run oom --image=nginx:1.27 --restart=Never --overrides='{"spec":{"containers":[{"name":"oom","image":"nginx:1.27","resources":{"limits":{"memory":"8Mi"}}}]}}'
```

结果一直 `Running`——**说明空闲的 nginx 只吃 4–6 MB，8Mi 装得下**。

**第二轮：`2Mi` → StartError**

```bash
kubectl delete pod oom --ignore-not-found
kubectl run oom --image=nginx:1.27 --restart=Never --overrides='{"spec":{"containers":[{"name":"oom","image":"nginx:1.27","resources":{"limits":{"memory":"2Mi"}}}]}}'
```

结果 `StartError`，且 `grep "Last State"` **什么都没输出**——因为容器从来没跑起来过，没有「上一次终止」。

`2Mi` 小到容器运行时都起不来，这时候报的是 `StartError`（`State: Waiting`），不是 `OOMKilled`。

**第三轮：主动吃内存 → 成功**

```bash
kubectl delete pod oom --ignore-not-found
kubectl run oom --image=alpine:3.20 --restart=Never --overrides='{"spec":{"containers":[{"name":"oom","image":"alpine:3.20","command":["sh","-c","echo 开始吃内存; dd if=/dev/zero of=/dev/shm/big bs=1M count=100; sleep 3600"],"resources":{"limits":{"memory":"32Mi"}}}]}}'
```

`dd` 往 `/dev/shm`（内存盘，算进 cgroup）写 100 MB，limit 只有 32Mi，写到 32 MB 被内核 SIGKILL。

**验证**

```bash
kubectl get pods
kubectl get pod oom -o jsonpath='{.status.containerStatuses[0].state.terminated.reason}{" / exit "}{.status.containerStatuses[0].state.terminated.exitCode}'
```

```
NAME   READY   STATUS      RESTARTS   AGE
oom    0/1     OOMKilled   0          99s

OOMKilled / exit 137
```

**关键数字**：`32Mi` 足够让 alpine 启动，又不够写完 100 MB——这个甜点区才出得来 `OOMKilled`。

### 状态对照表（这张是核心）

| 状态 | 容器走到哪一步 | 有退出码 | 典型原因 |
|---|---|---|---|
| `CrashLoopBackOff` | 起来了，反复退出 | 有（1 / 137 / 143） | 程序 bug、探针失败 |
| `ImagePullBackOff` | 没到容器这步 | 无 | tag 错、镜像站拦截、网络 |
| `OOMKilled` | 起来了，被内核杀 | 有（137） | 超 memory limit |
| `StartError` | 没起来 | 无 | limit 小到运行时都起不来 |
| `ErrImagePull` | 拉取首次失败 | 无 | 过渡态，几秒后转 `ImagePullBackOff` |

**判据：有退出码说明容器跑过；没退出码说明没跑起来。**

### 退出码表

| 码 | 含义 | 对付办法 |
|---|---|---|
| `0` | 正常结束 | — |
| `1` | 程序自己认为失败 | 看日志、改代码 |
| `137` | `128 + 9`，被 SIGKILL | 多半是 OOM，查 limit |
| `143` | `128 + 15`，收到 SIGTERM | 正常停止 / 被驱逐 |

## 第四种重启原因：探针（2026-11-25）

前面三个故障都是「容器自己出问题」，这一种是 **K8s 主动杀它**。

### liveness 失败 → 杀掉重启

**制造**

```bash
kubectl run probe --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"probe","image":"nginx:1.27","livenessProbe":{"exec":{"command":["cat","/tmp/healthy"]},"initialDelaySeconds":5,"periodSeconds":5,"failureThreshold":2}}]}}'
```

探针是 `cat /tmp/healthy`，而这个文件不存在，所以必然失败。

**现象**

```
probe   1/1   Running   0   3s
probe   1/1   Running   1   25s     ← STATUS 一直是 Running，只有 RESTARTS 在涨
probe   0/1   CrashLoopBackOff   3   1m15s
```

**和昨天的 `CrashLoopBackOff` 的区别**：昨天那个 Pod 一直 `Error`，这个是「跑着跑着被杀」。

**定位**

```bash
kubectl describe pod probe | grep -B2 -A6 "Liveness"
```

```
Restart Count:  5
Liveness:       exec [cat /tmp/healthy] delay=5s timeout=1s period=5s #success=1 #failure=2

Events:
  Warning  Unhealthy  65s (x12 over 2m30s)  Liveness probe failed: cat: /tmp/healthy: No such file or directory
  Normal   Killing    65s (x6 over 2m25s)   Container probe failed liveness probe, will be restarted
  Warning  BackOff    4s  (x5 over 1m15s)   Back-off restarting failed container probe
```

**一个容易被忽略的数字关系**：`Unhealthy` 12 次、`Killing` 6 次，正好 **2:1** ——
因为 `failureThreshold: 2`，连续失败 2 次才杀一次。**这个比例就是 `failureThreshold` 的可视化证明。**

**修法 A（治标）：把探针指到真实存在的路径**

Pod 的 `livenessProbe` 不可改，只能删了重建：

```bash
kubectl delete pod probe
kubectl run probe --image=nginx:1.27 --overrides='{"spec":{"containers":[{"name":"probe","image":"nginx:1.27","livenessProbe":{"httpGet":{"path":"/","port":80},"initialDelaySeconds":3,"periodSeconds":5,"failureThreshold":2}}]}}'
```

**修法 B（治本）：别用 liveness 检查外部依赖**

如果 `livenessProbe` 查的是「数据库连不连得上」：

> 数据库一抖动 → 所有 Pod 健康检查全失败 → K8s 把所有 Pod 全部重启 → **雪崩**

### readiness 失败 → 不重启，只摘流量

**制造**

```bash
kubectl create deployment ready --image=nginx:1.27
kubectl patch deployment ready -p '{"spec":{"template":{"spec":{"containers":[{"name":"nginx","image":"nginx:1.27","readinessProbe":{"httpGet":{"path":"/healthz","port":80},"periodSeconds":3,"failureThreshold":2}}]}}}}'
kubectl get pods -l app=ready -o wide
```

**现象（这是全 K8s 最容易被误判的状态）**

```
NAME                     READY   STATUS    AGE   IP
ready-5699ddfb49-7qjff   1/1     Running   8m    10.42.0.151    ← 旧版，服务中
ready-6d7fb5b989-jn2fv   0/1     Running   24s   10.42.0.152    ← 新版，不 Ready

NAME    ENDPOINTS        AGE
ready   10.42.0.151:80   7m58s     ← 只有旧 Pod 的 IP

$ kubectl rollout status deployment/ready --timeout=5s
Waiting for deployment "ready" rollout to finish: 1 old replicas are pending termination...
error: timed out waiting for the condition
```

**关键**：新 Pod `STATUS` 是 `Running`（容器活得好好的），但 `READY` 是 `0/1`，所以**不进 Endpoints**。

**所以旧 Pod 一直不被替换，发布卡住 —— 但线上服务完全没有中断。**

### 这组对照就是「零宕机发布」的全部

| 探针 | 失败后的 Pod 状态 | Service 后端 | 会不会重启 |
|---|---|---|---|
| `livenessProbe` 挂 | 反复重启 → `CrashLoopBackOff` | 有（但一直重启） | **会** |
| `readinessProbe` 挂 | **`Running` 但 `READY 0/1`** | **不含它** | **不会** |

**没有 readiness 会怎样**：新 Pod 一起来就被塞进 Endpoints，用户 50% 报错。
**有 readiness**：新 Pod 不健康就不接流量，旧版本继续扛 —— 发布卡住但服务不中断。

### 三种探针分工

| 探针 | 失败时 | 该查什么 |
|---|---|---|
| `livenessProbe` | **杀掉重启** | 只查自己进程是否卡死（死锁、线程池耗尽） |
| `readinessProbe` | **不重启，从 Service 摘掉** | 查依赖（数据库/缓存/下游接口） |
| `startupProbe` | 启动期保护，成功后不再查 | 查启动是否完成（慢启动应用） |

**一句话：依赖挂了用 readiness，进程死了用 liveness。搞反就是雪崩。**

### 顺带：Endpoints 已被 EndpointSlice 取代

```
Warning: v1 Endpoints is deprecated in v1.33+; use discovery.k8s.io/v1 EndpointSlice
```

| | Endpoints | EndpointSlice |
|---|---|---|
| 一个 Service 对应几个对象 | 1 个（Pod 全塞进去） | 多个（每片最多 100 个） |
| 大规模服务 | 单对象过大，etcd 压力大 | 分片，可扩展 |
| 状态 | **已弃用** | 推荐 |

查法：`kubectl get endpointslices -l kubernetes.io/service-name=ready`

## 持久化：PVC（2026-11-25）

思想和 Docker 数据卷一样（容器删了数据还在），只是 K8s 多了两层抽象。

| 对象 | 是什么 | 类比 Docker |
|---|---|---|
| **PV** | 集群里的一块真实存储（k3s 用 local-path，落在 `/var/lib/rancher/k3s/storage`） | 宿主机上某个目录 |
| **PVC** | 我的申请单：「我要 1Gi，可读写」 | `-v` 那行的左边 |
| **StorageClass** | 自动创建 PV 的模板（k3s 自带 `local-path`） | 无对应 |

**声明 PVC → K8s 自动建 PV → Pod 挂载 PVC。**

### 建 PVC

```bash
kubectl apply -f - << 'EOF'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: data
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
EOF
```

`kubectl apply -f -` 表示从标准输入读 YAML，不落文件。

### PVC 显示 Pending 不一定有问题

刚建完 `kubectl get pvc` 会显示 `Pending`，Events 是这样：

```
WaitForFirstConsumer   waiting for first consumer to be created before binding
ExternalProvisioning   Waiting for a volume to be created either by the external provisioner
Provisioning           External provisioner is provisioning volume for claim "default/data"
ProvisioningSucceeded  Successfully provisioned volume pvc-e2f67e58-...
```

**`WaitForFirstConsumer` = 延迟绑定**：local-path 的存储在某台节点的本地磁盘上，必须等 Pod 调度完、知道它在哪台机器，才能在那台机器上建 PV。

| 模式 | 行为 | 用在哪 |
|---|---|---|
| `Immediate` | PVC 一创建就分配 | 云盘（跨节点都能挂） |
| **`WaitForFirstConsumer`** | **等有 Pod 用了才分配** | **本地盘** |

**排查判据：Events 里有 `WaitForFirstConsumer` 就是正常 Pending；没有这一行、只有 `no persistent volumes available` 才是真问题。**

**如果真卡住**：给 PVC 显式写 `storageClassName: local-path`，不依赖「默认 StorageClass」这个前提（重装/升级后默认标记可能丢）。

### 实测：换 Pod 数据还在

```bash
kubectl run writer --image=busybox:1.36 --restart=Never --overrides='{"spec":{"containers":[{"name":"writer","image":"busybox:1.36","command":["sh","-c","echo 我写入了 $(date) > /data/hello.txt; cat /data/hello.txt; sleep 3600"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data"}}]}}'
```

删掉它，再起一个只读的：

```bash
kubectl delete pod writer
kubectl run reader --image=busybox:1.36 --restart=Never --overrides='{"spec":{"containers":[{"name":"reader","image":"busybox:1.36","command":["sh","-c","cat /data/hello.txt; echo; ls -l /data"],"volumeMounts":[{"name":"data","mountPath":"/data"}]}],"volumes":[{"name":"data","persistentVolumeClaim":{"claimName":"data"}}]}}'
kubectl logs reader
```

```
NAME   STATUS   VOLUME                                     CAPACITY   ACCESS MODES   STORAGECLASS
data   Bound    pvc-e2f67e58-1721-4eb7-91cc-f91e96132a1a   1Gi        RWO            local-path

我写入了 Wed Nov 25 02:18:03 UTC 2026

total 4
-rw-r--r--  1 root  root  42 Nov 25 02:18 hello.txt
```

**换了 Pod、换了容器、还是同一份数据 —— 这就是 PVC 存在的意义。**

**一个细节**：容器里打印的是 UTC 时间（`02:18 UTC`，宿主机是 `10:18`）。容器默认 UTC，要改时区得挂 `/etc/localtime` 或设 `TZ` 环境变量。

## 有状态部署：Deployment 挂 PVC（2026-11-26）

前面是「一个 Pod 用 PVC」，这一步换成 **Deployment 管理 Pod + PVC 挂数据目录** —— 真实业务里 nginx 挂网页目录、MySQL 挂数据目录都是这个写法。

### 一份 YAML 两个对象

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: webdata
spec:
  accessModes: ["ReadWriteOnce"]
  resources:
    requests:
      storage: 1Gi
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: webstate
spec:
  replicas: 1
  selector:
    matchLabels:
      app: webstate
  template:
    metadata:
      labels:
        app: webstate
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          volumeMounts:
            - name: html
              mountPath: /usr/share/nginx/html
      volumes:
        - name: html
          persistentVolumeClaim:
            claimName: webdata
```

`---` 是 YAML 的分隔符，一个文件里放多个对象，`kubectl apply -f` 会依次创建。

文件落在 `ops-lab/k8s/manifests/web-pvc.yaml`。

### 一个必须先知道的现象：卷会盖住目录原有内容

nginx 镜像自带欢迎页 `/usr/share/nginx/html/index.html`。把**空 PVC** 挂到这个目录后，镜像里那层内容被盖住了，目录变成空的，访问就是 `403 Forbidden`。

挂载的基本规则是：**数据卷永远在最上层，镜像里同名路径被遮蔽**。所以要先自己写一个页面进去。

### 实测：删 Pod 重建，页面还在

```bash
POD=$(kubectl get pod -l app=webstate -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- sh -c 'echo "<h1>张野的 PVC 页面 v1</h1>" > /usr/share/nginx/html/index.html'
kubectl exec $POD -- cat /usr/share/nginx/html/index.html
```

```
<h1>张野的 PVC 页面 v1</h1>
```

删掉 Pod，Deployment 自动拉起一个新的：

```bash
kubectl delete pod $POD
kubectl get pods -l app=webstate
```

```
NAME                        READY   STATUS    RESTARTS   AGE
webstate-56d5d8455f-2rv4d   1/1     Running   0          79s
```

重新取一次 Pod 名（旧变量已失效），再读文件：

```bash
POD=$(kubectl get pod -l app=webstate -o jsonpath='{.items[0].metadata.name}')
kubectl exec $POD -- cat /usr/share/nginx/html/index.html
```

```
<h1>张野的 PVC 页面 v1</h1>
```

### 三件证据缺一不可

| 证据 | 数值 | 证明什么 |
|---|---|---|
| PVC `webdata` | `Bound`，AGE **6m54s** | 卷是老的，没重建 |
| Pod `webstate-...-2rv4d` | AGE **79s**，名字带新 hash | 容器是新的 |
| `cat` 输出 | `<h1>张野的 PVC 页面 v1</h1>` | 内容还是老的 |

**判据：PVC 的 AGE 远大于 Pod 的 AGE，而内容不变 —— 数据在卷里，不在容器里。**

只看「页面还在」无法排除「Pod 根本没被删」，所以必须同时有这两个时间戳。

### 两个坑

**① 删 Pod 后 `$POD` 变量失效**

`kubectl delete pod $POD` 之后，变量还指着已删除的 Pod 名，再 `exec` 会报 `not found`。必须重新 `kubectl get pod ... -o jsonpath` 取一次。

**② `kubectl exec` 里的重定向要在容器内执行**

```bash
kubectl exec $POD -- echo "xxx" > /usr/share/nginx/html/index.html
```

反例：这里的 `>` 是**宿主机的 shell** 在重定向，文件被写到你本机根目录，容器里什么都没变。

```bash
kubectl exec $POD -- sh -c 'echo "xxx" > /usr/share/nginx/html/index.html'
```

正解：加 `sh -c` 才是让容器内的 shell 去执行重定向。

## 截图索引

| 文件 | 证明什么 |
|---|---|
| `screenshots/01-k3s-四层对象与Service.png` | `deploy,rs,pods,svc` 一次看全：Deployment 1/1、RS 1/1、Pod Running、Service NodePort 80:32676 |
| `screenshots/02-k3s-curl验证nginx.png` | `curl -I 127.0.0.1:32676` 返回 `HTTP/1.1 200 OK` + `Server: nginx/1.27.5` |
| `screenshots/03-k8s-CrashLoopBackOff-与修复对比.png` | `crash2 Error / RESTARTS 3` + `Args: exit 1` + `crash-fixed Running`，一张图含故障与修复 |
| `screenshots/05-k8s-ImagePullBackOff-状态流转.png` | `ContainerCreating → ErrImagePull → ImagePullBackOff` 三次跳变 |
| `screenshots/06-k8s-ImagePullBackOff-Events.png` | Events 里的 `403 Forbidden` + `this image is not in the allowlist` |
| `screenshots/07-k8s-OOMKilled-退出码137.png` | `oom 0/1 OOMKilled` + `OOMKilled / exit 137` |
| `screenshots/08-k8s-liveness-探针失败.png` | `probe2 0/1 CrashLoopBackOff 3` + `Restart Count: 3` + `Liveness: ... #failure=2` + `Unhealthy x8` / `Killing x4`（8÷4=2 就是 failureThreshold） |
| `screenshots/09-k8s-readiness-发布卡住.png` | 新旧两 Pod 并存：`1/1 Running` 与 `0/1 Running`；Endpoints 仍指向旧 IP；`rollout status` 超时报 `1 old replicas are pending termination` |
| `screenshots/10-k8s-PVC-数据持久化.png` | `data Bound pvc-e2f67e58... 1Gi RWO local-path` + 换 Pod 后 `cat` 到 `我写入了 ...` + `hello.txt 42 字节` |
| `screenshots/11-k8s-Deployment挂PVC-页面不丢.png` | 一张图三证据：PVC AGE 6m54s Bound + Pod AGE 79s Running + `cat` 出 `张野的 PVC 页面 v1` |

