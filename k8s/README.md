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

## 面试 30 秒

> 我在 Debian 上用 k3s 起了单节点集群。国内搭 K8s 最难的不是装，是拉镜像——k3s 装完所有 Pod 卡在 ContainerCreating，`describe` 一看是 `FailedCreatePodSandBox: failed to pull rancher/mirrored-pause`。pause 是每个 Pod 的沙箱地基镜像，它拉不到后面全卡，而且报的是 sandbox 失败不是 ImagePull，容易误判。解法是 `/etc/rancher/k3s/registries.yaml` 给 docker.io 配 mirror endpoint，重启 k3s，再删掉卡死的 Pod 让它重建。之后我用 Deployment 跑 nginx，`kubectl get deploy,rs,pods,svc` 能看到四层关系，`expose --type=NodePort` 后 curl 宿主机端口返回 200。

## 截图索引

| 文件 | 证明什么 |
|---|---|
| `screenshots/01-k3s-四层对象与Service.png` | `deploy,rs,pods,svc` 一次看全：Deployment 1/1、RS 1/1、Pod Running、Service NodePort 80:32676 |
| `screenshots/02-k3s-curl验证nginx.png` | `curl -I 127.0.0.1:32676` 返回 `HTTP/1.1 200 OK` + `Server: nginx/1.27.5` |

## 明天要做的

- Pod 一直重启怎么查（`CrashLoopBackOff` / `ImagePullBackOff` / `OOMKilled`）
- `kubectl logs --previous` 看崩溃前的日志
- 故意制造故障 + 写一次完整排障记录
