#!/bin/bash
# linux-audit.sh —— Linux 安全加固 20 项证据采集
# 用法：sudo bash linux-audit.sh
# 说明：只采集证据，不做判断。合格与否由基线和人决定。

if [ "$(id -u)" -ne 0 ]; then
    echo "需要 root 权限，请用：sudo bash $0"
    exit 1
fi

sec() {
    echo
    echo "===== $1 ====="
}

sec "1  UID 0 的账号"
awk -F: '$3 == 0 { print $1, $7 }' /etc/passwd

sec "2  空口令账号"
awk -F: '($2 == "") { print $1 }' /etc/shadow

sec "3  可登录账号"
awk -F: '$7 !~ /(nologin|false)$/ { print $1, $7 }' /etc/passwd

sec "4  账号有效期"
for u in root kali; do
    echo "--- $u"
    chage -l "$u" 2>/dev/null | grep -E "Account expires|Password expires"
done

sec "5  sudo 授权"
grep -vE '^\s*#|^\s*$' /etc/sudoers
echo "--- sudoers.d"
ls /etc/sudoers.d/ 2>/dev/null

sec "6  口令最长有效期"
grep -E '^\s*PASS_MAX_DAYS' /etc/login.defs

sec "7  口令最短长度"
grep -E '^\s*PASS_MIN_LEN' /etc/login.defs

sec "8  登录失败锁定"
grep -E 'pam_faillock|pam_tally' /etc/pam.d/common-auth || echo "未配置失败锁定"

sec "9  SSH 允许 root 登录"
grep -E '^\s*#?\s*PermitRootLogin' /etc/ssh/sshd_config || echo "未显式配置"

sec "10 SSH 密码登录"
grep -E '^\s*#?\s*PasswordAuthentication' /etc/ssh/sshd_config || echo "未显式配置"

sec "11 SSH 最大认证次数"
grep -E '^\s*#?\s*MaxAuthTries' /etc/ssh/sshd_config || echo "未显式配置"

sec "12 全部监听端口"
ss -tln

sec "13 对外监听的端口"
ss -tln | grep -E '0\.0\.0\.0|\*:|:::' || echo "无"

sec "14 开机自启服务"
systemctl list-unit-files --state=enabled --type=service --no-pager

sec "15 敏感文件权限"
ls -l /etc/passwd /etc/shadow /etc/ssh/sshd_config

sec "16 /tmp 下的可执行文件"
find /tmp /var/tmp -type f -perm -o+x 2>/dev/null | head -20

sec "17 无主文件"
find / -xdev \( -nouser -o -nogroup \) 2>/dev/null | head -20

sec "18 日志是否持久化"
ls -ld /var/log/journal 2>/dev/null || echo "不存在：日志只写内存，重启即丢"

sec "19 SSH 最近登录记录"
journalctl -u ssh -n 5 --no-pager 2>/dev/null || journalctl -u sshd -n 5 --no-pager 2>/dev/null

sec "20 访问日志里的明文口令"
grep -i 'password=' /var/log/apache2/access.log 2>/dev/null | head -3 || echo "无"

echo
echo "===== 采集完成 ====="
