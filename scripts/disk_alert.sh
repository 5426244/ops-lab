THRESHOLD=80

df -h | awk 'NR>1 {gsub(/%/, "", $5); if ($5+0 >= '"$THRESHOLD"') print "[告警] " $6 " 使用率 " $5 "%"}'
