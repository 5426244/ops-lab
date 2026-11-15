#!/bin/bash

LOG_DIR="/var/log/apache2"        
ARCHIVE="$HOME/log-archive"        
DAYS=7                            

mkdir -p "$ARCHIVE"

TODAY=$(date +%Y%m%d)               
COUNT=0

echo "=== 扫描 $LOG_DIR 中 $DAYS 天前的 .log ==="

find "$LOG_DIR" -maxdepth 1 -name "*.log" -mtime +$DAYS 2>/dev/null | while read -r file; do
    name=$(basename "$file")                    
    stem=${name%.log}                          
    target="$ARCHIVE/${stem}-${TODAY}.gz"      


    if gzip -c "$file" > "$target"; then
        echo "[归档] $file → $target"
    else
        echo "[失败] $file"
    fi
done

echo "=== 归档目录现有 ==="
ls -lh "$ARCHIVE" 2>/dev/null || echo "（空）"

echo

