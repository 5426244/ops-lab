#!/bin/bash

DB_HOST="127.0.0.1"
DB_USER="dvwa"
DB_PASS="p@ssw0rd"
DB_NAME="dvwa"

BACKUP_DIR="$HOME/db-backup"
KEEP=7                          

mkdir -p "$BACKUP_DIR"

DATE=$(date +%Y%m%d-%H%M%S)    
FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql"

echo "=== 备份 $DB_NAME → $FILE ==="

mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$FILE" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "[失败] mysqldump 出错，删除空文件"
    rm -f "$FILE"
    exit 1
fi

if [ ! -s "$FILE" ]; then
    echo "[失败] 备份文件是空的"
    rm -f "$FILE"
    exit 1
fi

gzip "$FILE"
echo "[完成] $(du -h "${FILE}.gz" | awk '{print $1}')"

echo "=== 清理，只保留最近 $KEEP 份 ==="
ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    echo "[删除] $(basename "$old")"
    rm -f "$old"
done

echo "=== 当前备份 ==="
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | awk '{print $5, $9}'
