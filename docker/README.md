# Docker 学习记录

> 2026-11-16 ~ 11-17，从零装 Docker 到把自写页面做成镜像跑起来。
> 所有结论都是在本机实际跑出来的，不是抄的。

---

## 目录

```
docker/
├── README.md            本文件
├── myweb/
│   ├── Dockerfile       FROM nginx + COPY 自己的页面
│   └── index.html       <h1>Hello from 张野的镜像</h1>
├── stack/
│   └── docker-compose.yml   nginx + mysql 5.7 两服务
└── screenshots/
    ├── 01-dockerfile-与镜像.png
    ├── 02-docker-build-与运行验证.png
    └── 04-docker-history-与数据卷.png
```

---

## 做了什么

| 环节 | 命令 | 结果 |
|---|---|---|
| 装 | `apt install -y docker.io` | `docker run hello-world` 通过 |
| 跑官方镜像 | `docker run -d --name mynginx -p 8080:80 nginx` | `curl -I` 返回 200 |
| 打包自己的页面 | `docker build -t myweb:v1 .` | 镜像 163MB |
| 换镜像看差别 | 三个版本 v1 / nocopy / run | 页面分别是自己的标题 / nginx 默认页 / `RUN 写的` |
| 数据卷 | `-v ~/testvol:/data` | 删容器后 `cat ~/testvol/a.txt` 仍是 `hello` |
| 多服务 | `docker compose up -d` | nginx + mysql 容器内互访 |
| 从零重建 | 删容器 → 删镜像 → 重新 build | `myweb:v2` + `final` 容器占 8096 |

---

## 三个实验：证明确实理解了 Dockerfile

| 实验 | 改了什么 | 访问结果 | 结论 |
|---|---|---|---|
| 删掉 COPY | 只剩 `FROM nginx` | `Welcome to nginx!` | **COPY 决定页面内容** |
| 改用 RUN 写页面 | `RUN echo ... > index.html` | `RUN 写的` | **RUN 在构建时把内容固化了** |
| 装回 COPY | 从宿主机搬文件 | 自己的标题 | COPY 是"搬运"，RUN 是"执行" |

**同一个基础镜像，只改一行指令，输出完全不同 —— 这就是镜像分层的意义。**

`docker history` 里能看到：最上面一层是 `COPY index.html`（几十字节），下面全是 nginx 官方镜像的层。

---

## 踩过的四个坑

**1. `COPY index.htlm /uer/share/...` 两处笔误**

报错：`"/index.htlm": not found`

**注意：文件名拼错会报错，但路径 `/uer/` 拼错不会报错，只是页面不生效。后者更危险。**

**2. 所有容器 `Exited (255)`**

机器重启后 Docker 守护进程重启，没设重启策略的容器全部停掉。

修法：`docker run` 时加 `--restart unless-stopped`。

**3. 容器内连 mysql 报证书错**

```
ERROR 2026 (HY000): TLS/SSL error: Certificate verification failure
```

修法：`mysql --skip-ssl` 或 `--ssl=0`。

**报证书错说明网络已经通了，只是 TLS 握手失败。**

**4. `docker build .` 报 `open Dockerfile: no such file or directory`**

因为当前目录不是项目目录，`.` 指错了地方。

修法：先 `cd ~/ops-lab/docker/myweb`，或者写成 `cd ... && docker build ...`。

---

## 关键命令速记

```bash
docker ps -a
docker images
docker build -t 镜像名:标签 .
docker run -d --name 容器名 --restart unless-stopped -p 宿主机端口:容器端口 镜像名:标签
docker logs 容器名
docker exec -it 容器名 bash
docker rm -f 容器名
docker rmi 镜像名:标签
docker history 镜像名:标签
docker container prune -f
```

**`rm` 删容器，`rmi` 删镜像 —— 容器有名字，镜像有标签（带冒号）。**

---

## 面试能答的四题

**Q：容器和虚拟机的区别？**
容器共享宿主机内核，启动是秒级；虚拟机跑完整操作系统，启动要几十秒。

**Q：容器里的数据怎么持久化？**
用数据卷。`-v 宿主机目录:容器目录` 是绑定挂载，`-v 卷名:容器目录` 是命名卷（Docker 在 `/var/lib/docker/volumes/` 下管理）。写容器层的数据随容器删除消失。

**Q：镜像是怎么构建的？**
Dockerfile 逐条执行，每条指令生成一层，层可复用（缓存）。改哪层只重建哪层之后的。

**Q：容器怎么做到开机自启？**
`docker run` 时加 `--restart unless-stopped`；已在跑的用 `docker update --restart unless-stopped 容器名`；compose 里写 `restart: unless-stopped`。
