#!/bin/bash
# db_backup.sh —— MySQL 数据库备份，按日期命名，只留最近 7 份
# 用法：chmod +x db_backup.sh && ./db_backup.sh
#
# 考什么：重定向、命令替换 date、循环、条件判断、文件清理

DB_HOST="127.0.0.1"
DB_USER="dvwa"
DB_PASS="p@ssw0rd"
DB_NAME="dvwa"

BACKUP_DIR="$HOME/db-backup"
KEEP=7                          # 保留几份

mkdir -p "$BACKUP_DIR"

DATE=$(date +%Y%m%d-%H%M%S)     # 20261113-221530
FILE="$BACKUP_DIR/${DB_NAME}_${DATE}.sql"

echo "=== 备份 $DB_NAME → $FILE ==="

# > 是重定向：把 mysqldump 的标准输出写进文件
# 2>/dev/null 把报错丢掉（密码会出现在命令行，mysqldump 会警告）
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$FILE" 2>/dev/null

# $? 是上一条命令的退出码，0 表示成功
if [ $? -ne 0 ]; then
    echo "[失败] mysqldump 出错，删除空文件"
    rm -f "$FILE"
    exit 1
fi

# -s 表示文件存在且大小大于 0
if [ ! -s "$FILE" ]; then
    echo "[失败] 备份文件是空的"
    rm -f "$FILE"
    exit 1
fi

gzip "$FILE"
echo "[完成] $(du -h "${FILE}.gz" | awk '{print $1}')"

# 清理旧备份：按修改时间从新到旧排，跳过前 KEEP 个，剩下的删掉
echo "=== 清理，只保留最近 $KEEP 份 ==="
ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    echo "[删除] $(basename "$old")"
    rm -f "$old"
done

echo "=== 当前备份 ==="
ls -lh "$BACKUP_DIR"/*.sql.gz 2>/dev/null | awk '{print $5, $9}'
