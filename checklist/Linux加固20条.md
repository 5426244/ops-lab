# Linux 安全加固 20 条

---

## 一、账号与认证（5 条）

| # | 检查项 | 命令 | 合格标准 | 实测 | 判定 |
|---|---|---|---|---|---|
| 1 | 是否存在 UID 0 的非 root 账号 | `awk -F: '$3 == 0 { print $1, $7 }' /etc/passwd` | 只有 `root` 一行 | 只有 `root` | ✅ |
| 2 | 是否有空口令账号 | `awk -F: '($2 == "") { print $1 }' /etc/shadow` | 无输出 | 无输出 | ✅ |
| 3 | 可登录账号清单 | `awk -F: '$7 !~ /(nologin\|false)$/ { print $1, $7 }' /etc/passwd` | 只剩必要账号 | `root` / `sync` / `postgres` / `kali(1000)` / `devuser(1001)` | ❌ `devuser` 是通用命名账号，无法追溯责任人 |
| 4 | 账号口令是否过期 | `chage -l root` | 有明确到期日期 | 原 `never` → 执行 `chage -M 90 root` 后为 **`Jan 10, 2027`** | ✅ 已整改（注意：日期 = 上次改密日 + 90 天，不是从今天算） |
| 5 | sudo 授权范围 | `cat /etc/sudoers \| grep -v '^#'` | 无 `NOPASSWD: ALL` | `root ALL=(ALL:ALL) ALL`、`%sudo ALL=(ALL:ALL) ALL`，无 NOPASSWD | ✅ 但 `%sudo` 组成员 = 全权，需定期核名单 |

---

## 二、口令策略（3 条）

| # | 检查项 | 命令 | 合格标准 | 实测 | 判定 |
|---|---|---|---|---|---|
| 6 | 口令最长有效期 | `grep ^PASS_MAX_DAYS /etc/login.defs` | ≤ 90 | 原 `99999` → 已改 `90` | ⚠️ 只对新账号生效，见第 4 条 |
| 7 | 口令最短长度 | `grep ^PASS_MIN_LEN /etc/login.defs` | ≥ 8 | 原被注释 → 已改 `8` | ⚠️ Debian 系实际由 `pam_pwquality` 控制 |
| 8 | 登录失败锁定 | `grep pam_faillock /etc/pam.d/common-auth` | 有 `deny=5` + `unlock_time` | 无输出（未配置） | ❌ 这是 Burp 爆破能成功的直线原因 |

---

## 三、SSH（3 条，生效值用 `sshd -T` 查）

| # | 检查项 | 命令 | 合格标准 | 实测（生效值） | 判定 |
|---|---|---|---|---|---|
| 9 | 是否允许 root 直接登录 | `sshd -T \| grep permitrootlogin` | `no` | `permitrootlogin without-password`（= 禁密码，只能密钥） | ✅ 实际安全，但走的是默认值非显式配置 |
| 10 | 是否允许密码登录 | `sshd -T \| grep passwordauthentication` | `no` | **`passwordauthentication yes`** | ❌ 密码登录开放，爆破/撞库可打 |
| 11 | 最大认证尝试次数 | `sshd -T \| grep maxauthtries` | ≤ 3 | `maxauthtries 3`（本次已改并验证生效） | ✅ |

---

## 四、服务与端口（3 条）

| # | 检查项 | 命令 | 合格标准 | 实测 | 判定 |
|---|---|---|---|---|---|
| 12 | 监听端口清单 | `ss -tlnp` | 每个端口能说出用途 | 22 OpenSSH 9.3p2 / 80 Apache 2.4.57 / 3306 MariaDB 10.11.4 | — 三个都有明确用途 |
| 13 | 监听地址是否对外 | `ss -tlnp \| grep -E '0\.0\.0\.0\|:::'` | 敏感服务只听 `127.0.0.1` | 3306 仅 `127.0.0.1` ✅；**80 是 `*:80` 对外且承载靶场** | ❌ P0 |
| 14 | 开机自启服务 | `systemctl list-unit-files --state=enabled` | 无多余服务 | 19 个，含 `lightdm`（图形）、`ModemManager`（调制解调器）、`haveged` | ⚠️ 桌面环境组件，服务器场景可关 |

---

## 五、文件与权限（3 条）

| # | 检查项 | 命令 | 合格标准 | 实测 | 判定 |
|---|---|---|---|---|---|
| 15 | 敏感文件权限 | `ls -l /etc/passwd /etc/shadow /etc/ssh/sshd_config` | shadow 至少 640 | `/etc/passwd` 644（正常）；`/etc/shadow` `-rw-r-----` root:shadow；`access.log` 644→640 | ✅ |
| 16 | 全局可写目录里的可执行文件 | `find /tmp /var/tmp -type f -perm -o+x` | 无输出 | 无输出 | ✅ |
| 17 | 无主文件 | `find / -xdev \( -nouser -o -nogroup \)` | 无输出 | 输出大量 `/var/lib/docker/overlay2/...` 与 `.../dbdata/mysql/...` | ⚠️ **全是容器层文件**（容器内 uid 在宿主机无对应用户），非真实孤儿文件 |

---

## 六、日志与审计（3 条）

| # | 检查项 | 命令 | 合格标准 | 实测 | 判定 |
|---|---|---|---|---|---|
| 18 | 日志是否持久化 | `ls -ld /var/log/journal` | 目录存在 | **不存在**，只写 `/run/log/journal` | ❌ 重启即丢，无法满足「保存不少于六个月」 |
| 19 | 是否记录关键事件 | `journalctl -u ssh -n 5` | 能看到登录成败 | 只有 `Server listening on 0.0.0.0 port 22` 与 `Started ssh service`，无登录记录 | ⚠️ 服务日志正常，只因服务 08:18 才启动、期间无人登录 |
| 20 | 日志里是否有明文口令 | `grep -i 'password=' /var/log/apache2/access.log` | 无输出 | 有：`GET .../brute/?username=admin&password=password&Login=Login` | ❌ 口令原样落盘，审计记录成了二次泄露源 |

---

## 汇总

| 判定 | 条数 | 编号 |
|---|---|---|
| ✅ 合格 | 8 | 1、2、4、5、9、11、15、16 |
| ⚠️ 需关注 | 5 | 6、7、14、17、19 |
| ❌ 不合格 | 6 | 3、8、10、13、18、20 |
| — 仅记录 | 1 | 12 |

**本轮 4 个整改动作：** `PASS_MAX_DAYS` 99999→90、启用 `PASS_MIN_LEN` 8、`MaxAuthTries` 3、`access.log` 644→640。**其中 `MaxAuthTries` 已用 `sshd -T` 验证生效。**

---

## 两个「假加固」——本轮最大收获

### 坑一：`login.defs` 只对新建账号生效

把 `PASS_MAX_DAYS` 改成 90 之后，`chage -l root` 仍然显示 **`Password expires: never`**。

**已经存在的账号不会因为改配置文件而变化**，必须逐个改：

```bash
sudo chage -M 90 root
sudo chage -M 90 kali
chage -l root
```

**这就是「报告写了已加固、实际没生效」的典型形态。**

### 坑二：注释掉的配置行仍走默认值

```
#PermitRootLogin prohibit-password      → 生效值 prohibit-password
#PasswordAuthentication yes             → 生效值 yes
```

**看配置文件看不出真实状态，要用 `sshd -T` 看合并默认值后的结果。**

**这条命令是审计和交付的底气：说不出「依据」的检查，等于没做。**

---

## 一条运维常识：`find -nouser` 在容器机器上会误报

`/var/lib/docker/overlay2/...` 与 `dbdata/mysql/...` 里大量文件显示「无主」，是因为**容器内的 uid（如 999）在宿主机没有对应用户**。这属于正常现象，不是安全事件。

**判断方法**：看路径是否在 `/var/lib/docker` 或容器卷下。是 → 误报。

---

## 改配置的铁律

**改任何远程访问配置（SSH / 防火墙 / 网络）之前：**

1. **先备份**：`cp 文件 文件.bak`
2. **先验证语法**：`sshd -t` / `nginx -t` / `named-checkconf`
3. **保留一个已登录的会话**，别关掉再试新的
4. **改完立刻验证生效值**，验证通过再关旧会话

**违反任何一条，都可能把自己锁在系统外面。**
