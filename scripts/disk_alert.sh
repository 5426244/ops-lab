#!/bin/bash
# disk_alert.sh —— 磁盘使用率告警
# 用法：chmod +x disk_alert.sh && ./disk_alert.sh
#
# 考什么：管道、awk 取列、变量、if 判断、数值比较

THRESHOLD=80

# df -h 第一行是标题（Filesystem Size Used Avail Use% Mounted on），
# awk 'NR>1' 跳过它，否则 $5 取到的是文字 "Use%"，数值比较会报错。
df -h | awk 'NR>1 {gsub(/%/, "", $5); if ($5+0 >= '"$THRESHOLD"') print "[告警] " $6 " 使用率 " $5 "%"}'
