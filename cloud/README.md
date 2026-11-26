# 阿里云 ECS + OSS 实操记录

一台按量付费的 ECS，从开通、装 nginx、开安全组，到 OSS 建私有桶并验证权限。
**全程按小时计费（¥0.123/小时），做完即释放——这个习惯比技术本身更重要。**

---

## 一、环境

| 项 | 值 |
|---|---|
| 地域 | 华北2（北京） |
| 规格 | 2 核 2 GiB |
| 系统 | Debian GNU/Linux 12 (bookworm) |
| 主机名 | `iZro7cildpnq8vZ` |
| 计费 | 按量付费 ¥0.12316/小时 |
| 额度 | 试用 300 元，有效期至 2027-02-26 |

---

## 二、开通时踩的三个坑

### 坑 1：镜像选成了 Windows Server

第一次创建时默认选了 **Windows Server 2022 数据中心版**。

**后果**：`apt` / `systemctl` / `ss` / `journalctl` 全部不存在。我过去三周学的命令一条都用不上，等于从零开始。

**处置**：控制台「全部操作 → 云盘和镜像 → 更换操作系统」，改成 **Debian 12.15 64 位**。

**教训**：运维岗默认给 Linux 镜像；Windows Server 是另一条线（AD、组策略、事件日志），单独学。

### 坑 2：换系统时的「停机模式」选错会启动失败

更换操作系统要先停机，弹窗有两种模式：

| 模式 | 计费 | 风险 |
|---|---|---|
| **普通停机模式** | 继续计费 | **资源保留，换系统不会失败** |
| 节省停机模式 | 停止计费 | 计算资源被回收，**换系统后可能「库存不足」启动失败** |

官方文案写得很清楚：**「如果您停止实例是为了更换操作系统…建议选择该模式，以避免启动失败」**。

所以换系统期间，那几毛钱不能省。

### 坑 3：「免费安全加固」会把 root 锁在外面

创建页默认勾选 **免费安全加固**，它做的事包括修改 `sshd_config`。

如果同时禁用了 root 密码登录，而你又没有密钥对，**换完系统就进不去了**。

**做法**：取消勾选。

---

## 三、登录：从进不去到能进

创建时「安全设置」选的是 **密钥对**，`Debian_12` 是**密钥对的名称**，不是密码。私钥（`.pem`）没下载，就等于没有钥匙。

```
$ ssh root@8.152.7.0
root@8.152.7.0: Permission denied (publickey).
```

先用 `Test-NetConnection 8.152.7.0 -Port 22` 确认 **TCP 通**（网络没问题），才判定是认证方式问题，而不是网络问题。

**处置**：控制台「远程连接 → Workbench 免密连接」——这条通道走阿里内部链路，不经 sshd 认证，所以能进。进去后执行：

```bash
echo 'root:Debian_2026' | chpasswd
echo 'PasswordAuthentication yes' > /etc/ssh/sshd_config.d/99-password.conf
systemctl restart ssh
```

之后 `ssh` 即可密码登录。

**判据**：`sshd -T | grep -E '^passwordauthentication|^permitrootlogin'` 两条都应为 `yes`。

---

## 四、安全组：默认只开 22

装完 nginx、本机 `curl` 通，但外网打不开：

```
8.152.7.0:22  → True
8.152.7.0:80  → False（超时）
```

**根因**：安全组入方向默认只放 22，80 没开。

**处置**：安全组 → 入方向 → 手动添加：

| 字段 | 值 |
|---|---|
| 授权策略 | 允许 |
| 优先级 | 1 |
| 协议 | 自定义 TCP |
| 访问来源 | `0.0.0.0/0` |
| 访问目的 | `80/80` |

新版控制台有快捷标签 **「Web HTTP 流量访问」**，点一下自动填好。

**判据**：加完立刻从本地测 `Test-NetConnection -Port 80` → `True`，再 `curl` 拿 200。

**这一层排查顺序永远是：安全组 → 系统防火墙 → 服务是否监听 → 应用本身。**

---

## 五、nginx

```bash
apt-get update -qq
apt-get install -y nginx
systemctl is-active nginx
ss -tlnp | grep ':80 '
```

结果：

```
nginx: active
版本: nginx/1.22.1
LISTEN 0 511 0.0.0.0:80 0.0.0.0:*  users:(("nginx",pid=1798,fd=5))
```

**故意不用默认欢迎页**，写了自己的 `/var/www/html/index.html`（883 字节），页面上带主机名、系统版本、nginx 版本、磁盘占用——**截图时这些信息本身就是证据**。

### 公网访问实测

浏览器直接访问 `http://8.152.7.0` 打开的就是自定义页（见截图 `12`）：标题「阿里云 ECS · nginx 已跑通」，表格里是这台机器的实时信息。

命令行同样验了一遍：

```
$ curl -I http://8.152.7.0/
HTTP 状态码 = 200
Server 头   = nginx/1.22.1
响应长度    = 883 字节
```

**两张证据互补**：截图证明"浏览器能打开"，`curl` 证明"服务头对得上"。

---

## 六、OSS：私有桶与三种 403

### 建桶

| 字段 | 值 |
|---|---|
| Bucket | `zhangye-opslab-2026` |
| 地域 | 华北2（北京）——与 ECS 同地域，走内网 |
| 存储类型 | 标准存储 |
| 冗余 | 同城冗余（默认，比本地冗余贵一倍，小文件可忽略） |
| 阻止公共访问 | 开通 |

### 三种 403 必须分清（这是本节的重点）

同样返回 `AccessDenied`，`EC` 码和 `Message` 完全不同：

| 访问方式 | Message | EC | 含义 |
|---|---|---|---|
| **对象 URL（无签名）** | `You have no right to access this object because of bucket acl.` | `0003-00000001` | **对象私有，匿名不可读** ← 这才证明权限生效 |
| Bucket 根（无签名） | `Anonymous user has no right to access this bucket.` | `0003-00000002` | 匿名列桶被拒 |
| 带签名但已过期 | `Request has expired.` | `0002-00000069` | **凭据过期，与权限无关** |

**辨析方法：看 XML 里有没有 `<Expires>` 元素。**
有 → 签名过期；没有 → 权限拒绝。

### 实测输出（无签名访问对象）

```xml
<Error>
  <Code>AccessDenied</Code>
  <Message>You have no right to access this object because of bucket acl.</Message>
  <HostId>zhangye-opslab-2026.oss-cn-beijing.aliyuncs.com</HostId>
  <EC>0003-00000001</EC>
</Error>
```

### 签名 URL 的三段结构

```
https://...png?Expires=1795673592&OSSAccessKeyId=TMP.xxx&Signature=xxx
```

| 参数 | 含义 |
|---|---|
| `Expires` | 过期时间戳（控制台默认 300 秒） |
| `OSSAccessKeyId` | 临时凭据 ID（`TMP.` 前缀 = STS 临时凭据） |
| `Signature` | 签名 |

**这种带签名的 URL 不能贴进文档或简历**——里面有临时凭据，虽然几分钟就失效，但习惯上不写。
文档里只写 Bucket 域名：`zhangye-opslab-2026.oss-cn-beijing.aliyuncs.com`。

---

## 七、费用与释放

| 资源 | 计费 | 处置 |
|---|---|---|
| ECS 按量付费 | ¥0.12316/小时 | **用完即释放** |
| OSS 标准存储 | 约 ¥0.12/GB/月 | 小文件留着不花钱，可留 |
| 公网流量 | 20 GiB 免费额度 | 正常用不完 |

**释放 ≠ 停机。** 普通停机仍会收取系统盘、公网 IP、镜像 License 费用——换系统时那个弹窗写得很明白。

释放路径：实例 → 更多 → 实例状态 → 释放实例 → 立即释放。

---

## 八、命令清单

```bash
# 登录
ssh root@8.152.7.0

# 确认密码登录真的开了
sshd -T | grep -E '^passwordauthentication|^permitrootlogin'

# 装 nginx 并确认监听
apt-get install -y nginx && systemctl is-active nginx && ss -tlnp | grep ':80 '

# 本机自测（排除 nginx 本身的问题）
curl -s -o /dev/null -w '%{http_code}\n' http://127.0.0.1/

# 公网自测（Windows 侧）
# Test-NetConnection 8.152.7.0 -Port 80
# Invoke-WebRequest http://8.152.7.0/

# 验证 OSS 私有：裸 URL 应返回 403 + 0003-00000001
curl -s "https://zhangye-opslab-2026.oss-cn-beijing.aliyuncs.com/12-阿里云-ECS公网访问nginx.png"
```

---

## 截图索引

| 文件 | 证明什么 |
|---|---|
| `screenshots/12-阿里云-ECS公网访问nginx.png` | 浏览器打开公网 IP 直接看到自定义页：主机名、Debian 12、nginx 1.22.1、监听 `0.0.0.0:80`、磁盘 6% |
| `screenshots/13-阿里云-OSS-读写权限-私有.png` | Bucket ACL = 私有，页面注明「对文件的所有访问操作需要进行身份验证」 |
| `screenshots/14-阿里云-OSS-匿名访问403.png` | 裸 URL 访问返回 `AccessDenied` + `because of bucket acl` + `EC 0003-00000001` |

---

## 一句话

**「开了台云主机、装了个 nginx、建了个私有桶」谁都会说；能拿出「安全组开了哪条、匿名访问返回哪个 EC 码」的人不多。**
