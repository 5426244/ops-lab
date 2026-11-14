#!/bin/bash
# log_rotate.sh —— 把 7 天前的日志压缩归档，按日期命名
# 用法：chmod +x log_rotate.sh && ./log_rotate.sh
#
# 考什么：find、gzip、date、命令替换 $(...)、while read、字符串截取 ${f%.log}

LOG_DIR="/var/log/apache2"          # 要处理的日志目录
ARCHIVE="$HOME/log-archive"         # 归档放哪
DAYS=7                              # 超过几天算旧

# 归档目录不存在就建
mkdir -p "$ARCHIVE"

TODAY=$(date +%Y%m%d)               # 命令替换：把 date 的输出接过来
COUNT=0

echo "=== 扫描 $LOG_DIR 中 $DAYS 天前的 .log ==="

# -maxdepth 1 只看这一层，不递归进子目录
find "$LOG_DIR" -maxdepth 1 -name "*.log" -mtime +$DAYS 2>/dev/null | while read -r file; do
    name=$(basename "$file")                    # access.log
    stem=${name%.log}                           # 去掉后缀 → access
    target="$ARCHIVE/${stem}-${TODAY}.gz"       # access-20261113.gz

    # -c 写到标准输出，原文件不动（不删源文件，更安全）
    if gzip -c "$file" > "$target"; then
        echo "[归档] $file → $target"
    else
        echo "[失败] $file"
    fi
done

echo "=== 归档目录现有 ==="
ls -lh "$ARCHIVE" 2>/dev/null || echo "（空）"

echo
echo "提示：生产环境确认归档成功后再删源文件，别一上来就 mv 或 rm。"
