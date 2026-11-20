# Week 1 · Day 1 知识点详解

> 三个脚本里出现的每一个语法，逐条拆开。
> 格式固定四块：**是什么 → 怎么写 → 在哪个脚本里 → 坑在哪**。
> 看不懂代码的时候，回来查这一份，不要硬看脚本。

---

## 先说三个"心智模型"

学 Shell 最容易卡住的地方，不是语法，是**不知道这东西在现实里对应什么**。

先记三个比喻，后面所有知识点都挂在这三根钉子上：

| 概念 | 比喻 | 一句话 |
|---|---|---|
| **重定向 `>`** | 水管改道 | 本来水（输出）流到屏幕，现在让它流到文件 |
| **退出码 `$?`** | 考试成绩 | 0 分不是零分，是**满分**（成功）；非 0 才是失败 |
| **变量截取 `${x%.log}`** | 从右边剪 | 像剪指甲，从末尾剪掉一段 |

---

## 一、shebang：`#!/bin/bash`

### 是什么

每个脚本第一行那个 `#!` 开头的怪东西，叫 **shebang**（读作"西邦"）。

它告诉系统：**这个文件要用哪个程序来解释执行。**

### 怎么写

```bash
#!/bin/bash
```

`#!` 后面必须是**解释器的绝对路径**。

### 为什么必须写

| 有没有 shebang | 系统怎么办 |
|---|---|
| 有 `#!/bin/bash` | 用 bash 跑，支持 `[[ ]]`、数组、`$(( ))` 全部特性 |
| 没有 | 用 `/bin/sh` 跑，**sh 是简化版**，很多 bash 语法不支持 |
| 写错（如 `#!/bin/bash\r`） | 报 `bad interpreter: No such file or directory` |

### 坑在哪

**你昨天那个 `: 31: a: not found` 的报错格式，就是 sh 的格式。**

bash 报错长这样：

```
./script.sh: line 31: a: command not found
```

sh（dash）报错长这样：

```
./script.sh: 31: a: not found
```

**看到没有 `line` 两个字，就说明你的脚本没走 bash。** 原因通常是 shebang 丢了，或者第一行带了 `\r`。

### 怎么验证

```bash
head -1 log_rotate.sh        # 看第一行在不在
file log_rotate.sh           # 看是不是 "Bourne-Again shell script"
```

---

## 二、`$()` 命令替换

### 是什么

**把一条命令的输出，当成一个值塞进别的地方。**

### 怎么写

```bash
TODAY=$(date +%Y%m%d)
echo $TODAY                  # 20261114
```

执行顺序：

1. 先跑 `date +%Y%m%d` → 输出 `20261114`
2. 把 `20261114` 放进 `TODAY` 这个变量

### 在哪个脚本里

`log_rotate.sh`：

```bash
TODAY=$(date +%Y%m%d)
```

`db_backup.sh`：

```bash
DATE=$(date +%Y%m%d-%H%M%S)          # 20261114-221530
```

### `date` 的格式符速查

| 写法 | 输出 | 含义 |
|---|---|---|
| `date +%Y` | 2026 | 四位年 |
| `date +%m` | 11 | 两位月 |
| `date +%d` | 14 | 两位日 |
| `date +%H%M%S` | 101530 | 时分秒 |
| `date +%F` | 2026-11-14 | 等价 `%Y-%m-%d` |
| `date +%s` | 1763... | Unix 时间戳（秒） |

### 老写法（别用）

```bash
TODAY=`date +%Y%m%d`         # 反引号，能跑但别用
```

**为什么别用**：反引号**不能嵌套**。要嵌套只能这么写：

```bash
A=`echo \`date\``            # 地狱
```

`$()` 可以随便嵌套：

```bash
A=$(echo $(date +%Y))        # 清楚
```

### 坑在哪

**`$( )` 里面不能有空格问题，但外面一定要加引号：**

```bash
echo $TODAY                  # 变量里没空格，能跑
echo "$TODAY"                # 永远安全
```

**变量里如果有空格，不加引号会被拆成多个参数。** 详见第九节。

---

## 三、变量截取 `${name%.log}`

### 是什么

**从变量的值里，按规则剪掉一段。**

### 怎么写

四个符号，两两成对：

| 写法 | 剪哪边 | 剪多少 | 例子 |
|---|---|---|---|
| `${x%.log}` | 右边 | **最短**匹配 | `access.log` → `access` |
| `${x%%.*}` | 右边 | **最长**匹配 | `access.log.gz` → `access` |
| `${x#*/}` | 左边 | **最短**匹配 | `/var/log/a.log` → `var/log/a.log` |
| `${x##*/}` | 左边 | **最长**匹配 | `/var/log/a.log` → `a.log` |

**记忆法：**
- `%` 在键盘上靠右 → **从右边剪**
- `#` 在键盘上靠左 → **从左边剪**
- **单个**符号 = 最短匹配；**双写** = 最长匹配

### 在哪个脚本里

`log_rotate.sh`：

```bash
name=$(basename "$file")     # access.log
stem=${name%.log}            # 剪掉 .log → access
target="$ARCHIVE/${stem}-${TODAY}.gz"    # access-20261114.gz
```

### 坑在哪

**它不会真的改文件，只改字符串。**

```bash
name="access.log"
stem=${name%.log}
echo $name           # access.log    ← 原变量没变
echo $stem           # access       ← 新变量是剪过的
```

**如果写成 `name%.log`（漏了 `$` 和 `{}`）**，bash 会原样输出 `name%.log` 这几个字符。

**如果写成 `${name%.gz}` 但变量是 `access.log`**，没有 `.gz` 可剪，会**原样返回**，不报错：

```bash
name="access.log"
echo ${name%.gz}      # access.log   ← 啥也没剪
```

**这个"不报错"很危险**——脚本会静默产出错的文件名。

---

## 四、`find -mtime +7`

### 是什么

`find` 是**按条件找文件**的命令；`-mtime` 是**按修改时间**筛选。

### 怎么写

```bash
find /var/log/apache2 -maxdepth 1 -name "*.log" -mtime +7
```

拆开看：

| 部分 | 意思 |
|---|---|
| `/var/log/apache2` | 从哪个目录开始找 |
| `-maxdepth 1` | 只看这一层，**不进子目录** |
| `-name "*.log"` | 文件名匹配 `*.log` |
| `-mtime +7` | 修改时间**超过 7 天** |

### `+` `-` 和无符号，三个都不一样

| 写法 | 含义 | 通俗说法 |
|---|---|---|
| `-mtime +7` | 修改时间 **> 7 天前** | 7 天没动过 |
| `-mtime 7` | 恰好 **第 7 天那一天** | 只有第 7 天 |
| `-mtime -7` | 修改时间 **< 7 天** | 最近 7 天内动过 |

**做日志清理要的是 `+7`**，不是 `7`。

### 坑在哪

**① 正在写的日志永远不满足 `+7`。**

`/var/log/apache2/access.log` 是你每次访问 DVWA 都在写的，修改时间是"刚刚"。**这是正常的，不是你脚本错了。**

要测就造一个：

```bash
sudo cp /var/log/apache2/access.log /var/log/apache2/old-test.log
sudo touch -d "10 days ago" /var/log/apache2/old-test.log
```

`touch -d` 改的是**文件的修改时间**，不是内容。

**② 权限不够会有一堆红色报错**

```bash
find /var/log -name "*.log" -mtime +7
# find: '/var/log/private': Permission denied
# find: '/var/log/sudo-io': Permission denied
```

两种办法：

```bash
sudo find ...                    # 提权
find ... 2>/dev/null             # 把报错扔掉
```

**`2>/dev/null` 的意思是"所有错误消息丢进黑洞"。** 详见第十节。

### 想验证 find 找对了没

```bash
# 只打印，不操作
find /var/log/apache2 -maxdepth 1 -name "*.log" -mtime +7 -print

# 顺便打印时间，肉眼核对
find /var/log/apache2 -maxdepth 1 -name "*.log" -mtime +7 -ls
```

**`-ls` 会列出文件的详细信息**，包括修改时间。核对一下时间对不对，再决定要不要删。

---

## 五、`while read -r line`

### 是什么

**逐行读取**——把 `find` 或 `ls` 输出的每一行，一行一行地交给循环处理。

### 怎么写

```bash
find /var/log -name "*.log" | while read -r file; do
    echo "处理: $file"
done
```

### 为什么这么写，不这么写

**❌ 错误写法：**

```bash
for file in $(find /var/log -name "*.log"); do
    echo $file
done
```

**问题**：`$(...)` 的输出会被**按空格拆开**。如果文件名里带空格（比如 `my file.log`），会被拆成 `my` 和 `file.log` 两个。

**✅ 正确写法：**

```bash
find /var/log -name "*.log" | while read -r file; do
    echo "$file"
done
```

`read` 是**按行**读，一行就是一个完整的文件名。

### `-r` 是什么

`-r` 表示 **raw**——不把反斜杠当转义符。

**不加 `-r` 的后果：**

文件名是 `back\slash.log` 时，`read` 会把 `\s` 吃掉，变成 `backlash.log`。

**结论：永远加 `-r`，不用想。**

### 坑在哪

**`while` 循环里的变量，出了循环就没了。**

```bash
COUNT=0
find ... | while read -r f; do
    COUNT=$((COUNT + 1))
done
echo $COUNT          # 0 ！！！不是文件数
```

**原因**：管道 `|` 右边会开一个**子 shell**，子 shell 里改的变量，父 shell 看不到。

**绕过办法（两种）：**

```bash
# 办法 1：不用管道，用重定向
while read -r f; do
    COUNT=$((COUNT + 1))
done < <(find /var/log -name "*.log")
echo $COUNT          # 正常

# 办法 2：把结果写进临时文件
find ... > /tmp/list.txt
while read -r f; do ...; done < /tmp/list.txt
```

**你现在的脚本不需要这个**，因为没在循环里累加变量。但要知道有这个坑。

---

## 六、`awk 'NR>1'`

### 是什么

`awk` 是**按列处理文本**的工具。`NR` 是它的内置变量，意思是 **Number of Record——当前读到第几行**。

### 怎么写

```bash
df -h | awk 'NR>1 {print $6}'
```

**`NR>1` 的意思是：第 1 行跳过，从第 2 行开始处理。**

### 为什么需要它

`df -h` 的输出：

```
Filesystem      Size  Used Avail Use% Mounted on      ← 第 1 行是表头
/dev/sda1        98G   42G   51G  46% /
tmpfs           1.9G     0  1.9G   0% /dev/shm
```

**如果不跳过表头**，`$5`（第 5 列）取到的是文字 `"Use%"`：

```bash
df -h | awk '{print $5}'
# Use%        ← 第一行输出这个
# 46%
# 0%
```

**后面拿 "Use%" 去做数值比较，就会出问题。**

### 坑在哪

**去掉 `NR>1` 会怎样：**

```bash
df -h | awk '{if ($5+0 >= 80) print}'
```

第一行的 `$5` 是 `"Use%"`，`"Use%"+0` 在 awk 里会被当成 **0**，所以不会报错，就默默过了。

**"不报错但不正确"比"报错"更危险。** 这是今天最值得记住的一句话。

---

## 七、`gsub(/%/, "", $5)`

### 是什么

`gsub` = **global substitute**，全局替换。

### 怎么写

```awk
gsub(/要替换的/, "换成什么", 在哪个字段)
```

```awk
gsub(/%/, "", $5)        # 把 $5 里的 % 全部换成空
```

### 为什么需要它

`df -h` 的 `$5` 是 `"46%"`（带百分号）。**要比较大小，得先变成纯数字 `46`。**

```bash
df -h | awk 'NR>1 {gsub(/%/, "", $5); print $5}'
# 46
# 0
```

### `$5+0` 又是什么

**强制把字符串当数字看。**

```awk
print "46" + 0        # 46
print "abc" + 0       # 0
print "46%" + 0       # 46      ← 会自动截断到数字部分
```

**所以其实 `gsub` 和 `+0` 干的是同一件事**（都能去百分号），写一个是够的。

**我们两个都写，是"双保险"**——万一某天 df 的输出格式变了（比如带单位），`+0` 还能兜住。

### 完整拆解

```bash
df -h | awk 'NR>1 {gsub(/%/, "", $5); if ($5+0 >= '"$THRESHOLD"') print "[告警] " $6 " 使用率 " $5 "%"}'
```

| 片段 | 作用 |
|---|---|
| `NR>1` | 跳过表头 |
| `gsub(/%/, "", $5)` | 去掉第 5 列的 `%` |
| `if ($5+0 >= 80)` | 数字比较 |
| `print "[告警] " $6 " 使用率 " $5 "%"` | 输出：挂载点 + 使用率 |

**注意 `'"$THRESHOLD"'` 这一段**——它在**双引号里断开，插入 `$THRESHOLD` 的值，再重新接上单引号**。

**为什么要这么绕**：awk 的脚本被 `'` 包着，**单引号里不能展开变量**。所以必须"跳出单引号 → 用双引号展开 → 再跳回单引号"。

**这是今天最难的一行。** 不懂就先照着抄，能改数字就行。

---

## 八、`>` 重定向和它的四个兄弟

### 是什么

**改变命令输出的去向。**

默认情况下，命令的输出会打印到**屏幕**。`>` 让它**流进文件**。

### 五个符号

| 符号 | 意思 | 例子 |
|---|---|---|
| `>` | 覆盖写入（**先清空**） | `echo a > f.txt` |
| `>>` | 追加（不清空） | `echo b >> f.txt` |
| `2>` | 只重定向**错误**输出 | `cmd 2> err.log` |
| `2>/dev/null` | 把错误丢进黑洞 | `find / 2>/dev/null` |
| `&>` | 正确+错误一起重定向 | `cmd &> all.log` |

### 在哪个脚本里

`db_backup.sh`：

```bash
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$FILE" 2>/dev/null
```

**这一段同时干了两件事：**

1. `> "$FILE"` —— 把 mysqldump 的正常输出写进备份文件
2. `2>/dev/null` —— 把 mysqldump 的警告（"密码写在命令行不安全"）丢掉

### 坑在哪

**① `>` 会先清空文件，再写入。**

```bash
echo "第一行" > f.txt
echo "第二行" > f.txt      # ← 第一行没了
cat f.txt                  # 只剩 第二行
```

**要保留就写 `>>`。**

**② `>` 在命令执行前就把文件创建了。**

```bash
mysqldump 错了 > backup.sql
ls -l backup.sql          # 文件存在，但 0 字节
```

**所以你脚本里要判断"文件是不是空的"：**

```bash
if [ ! -s "$FILE" ]; then
    echo "备份空文件，删掉"
    rm -f "$FILE"
fi
```

`-s` = **文件存在且大小 > 0**。详见第十一节。

**③ `2>/dev/null` 会藏起真错误。**

调试时**先去掉它**：

```bash
mysqldump -h 127.0.0.1 -u dvwa -p'p@ssw0rd' dvwa > /tmp/t.sql
```

看到真报错（比如 `Access denied`），再去修。

**"为了界面干净牺牲可诊断性"是运维事故的第一大来源。**

---

## 九、引号：什么时候必须加

### 规则

**凡是变量，一律加双引号。**

```bash
cp $file /backup/          # ❌ 文件名带空格就炸
cp "$file" /backup/        # ✅
```

### 为什么

**不加引号，bash 会做"分词"（word splitting）**——把变量的值按空格拆成多个参数。

```bash
file="my report.txt"

cp $file /tmp/
# 实际执行的是：cp my report.txt /tmp/
# 结果：报错 "cp: cannot stat 'my'" 和 "cp: cannot stat 'report.txt'"

cp "$file" /tmp/
# 实际执行的是：cp "my report.txt" /tmp/
# 结果：正确
```

### 什么时候可以不加

**纯数字比较时：**

```bash
if [ $COUNT -gt 0 ]; then      # 能跑
if [ "$COUNT" -gt 0 ]; then    # 也跑，更安全
```

**变量是空值时，不加引号会出大问题：**

```bash
if [ $COUNT -gt 0 ]; then      # COUNT 是空 → 变成 [ -gt 0 ] → 报错
if [ "$COUNT" -gt 0 ]; then    # COUNT 是空 → 变成 [ "" -gt 0 ] → 报错但是可控
```

**结论：养成 `"$var"` 的肌肉记忆，不要判断"这个要不要加"。**

---

## 十、`$?` 退出码

### 是什么

**上一条命令的"考试成绩"。**

| 值 | 意思 |
|---|---|
| `0` | **成功**（满分） |
| `1`–`255` | 失败（不同数字代表不同错误类型） |

**⚠️ 反直觉：0 是成功，不是失败。**

### 怎么写

```bash
mysqldump ... > "$FILE"
if [ $? -ne 0 ]; then
    echo "备份失败"
fi
```

`-ne` = **not equal**（不等于）。

### 在哪个脚本里

`db_backup.sh`：

```bash
mysqldump -h "$DB_HOST" -u "$DB_USER" -p"$DB_PASS" "$DB_NAME" > "$FILE" 2>/dev/null

if [ $? -ne 0 ]; then
    echo "[失败] mysqldump 出错"
    rm -f "$FILE"
    exit 1
fi
```

### 坑在哪

**`$?` 只记住"上一条"命令。中间插一条别的，就变了：**

```bash
mysqldump ... > f.sql
echo "备份完了"              # ← 这条会覆盖 $?
if [ $? -ne 0 ]; then ...    # 现在判断的是 echo 的结果（永远 0）
```

**正确做法**：紧跟判断，或者用 `&&`：

```bash
mysqldump ... > f.sql && echo "成功" || echo "失败"
```

### 想查"这条命令成功是什么码"

```bash
ls /etc/passwd
echo $?          # 0

ls /etc/nonexist
echo $?          # 2（找不到文件）
```

### 为什么用 `exit 1` 退出脚本

`db_backup.sh` 里：

```bash
rm -f "$FILE"
exit 1
```

**`exit 1` 让脚本以"失败"状态退出。** 这样如果有人把脚本放进 crontab，或者用 `&&` 串联，**后面的步骤会自动停下**。

```bash
./db_backup.sh && echo "备份成功，继续上传"
# 备份失败 → exit 1 → 后面的 echo 不执行
```

**这是自愈脚本和"假装成功"脚本的分界线。**

---

## 十一、`[ ]` 测试表达式

### 是什么

`[ ]` 是 Shell 的**判断语句**，用来测文件、比数字、比字符串。

**注意：`[` 是一个命令，不是语法符号。**

```bash
which [
# /usr/bin/[        ← 它真的是个程序
```

### 常用测试符

**文件：**

| 写法 | 意思 |
|---|---|
| `[ -f "$f" ]` | 是普通文件 |
| `[ -d "$f" ]` | 是目录 |
| `[ -e "$f" ]` | 存在（不管类型） |
| `[ -s "$f" ]` | 存在**且非空** |
| `[ -r "$f" ]` | 可读 |
| `[ -x "$f" ]` | 可执行 |

**字符串：**

| 写法 | 意思 |
|---|---|
| `[ -z "$s" ]` | 空（zero） |
| `[ -n "$s" ]` | 非空（non-zero） |
| `[ "$a" = "$b" ]` | 相等 |
| `[ "$a" != "$b" ]` | 不等 |

**数字：**

| 写法 | 意思 |
|---|---|
| `[ "$a" -eq "$b" ]` | 等于 |
| `[ "$a" -ne "$b" ]` | 不等于 |
| `[ "$a" -gt "$b" ]` | 大于 |
| `[ "$a" -lt "$b" ]` | 小于 |
| `[ "$a" -ge "$b" ]` | 大于等于 |
| `[ "$a" -le "$b" ]` | 小于等于 |

### 在哪个脚本里

`db_backup.sh`：

```bash
if [ ! -s "$FILE" ]; then
```

拆开：

- `!` = **取反**
- `-s` = **存在且非空**
- 合起来：**"文件不存在 或者 是空的"**

**为什么这么写**：`>` 会把文件先创建出来，所以 mysqldump 失败时文件**存在但 0 字节**。`-s` 就是用来抓这种情况的。

### 坑在哪

**① 空格不能省。**

```bash
if [ "$a" -gt 0 ]; then      # ✅
if ["$a" -gt 0 ]; then       # ❌ 报 [ : command not found
if [ "$a" -gt 0 ]; then      # ✅ 方括号内两侧都要空格
```

**`[` 和 `]` 都是命令，所以前后必须有空格。**

**② 数字比较别用 `>` `<`。**

```bash
if [ "$a" > "$b" ]; then     # ❌ 这是"字符串比较"，且 > 被当成重定向
if [ "$a" -gt "$b" ]; then   # ✅
```

**`>` 在 `[ ]` 里会被当成重定向符号，可能悄悄创建一个叫 `0` 的文件。**

**③ `==` 和 `=`。**

- `[ "$a" = "$b" ]` —— POSIX 标准，sh 也支持
- `[ "$a" == "$b" ]` —— bash 特有，sh 不认

**写脚本一律用 `=`，兼容性最好。**

---

## 十二、`ls -1t | tail -n +8`

### 是什么

**"按时间从新到旧排，跳过前 7 个，剩下的打出来"** —— 用来找出该删的旧备份。

### 拆开看

```bash
ls -1t *.gz | tail -n +8
```

| 部分 | 意思 |
|---|---|
| `ls -1` | 一行一个文件（数字 1，不是字母 l） |
| `-t` | 按**修改时间**排序，**新的在前** |
| `\| tail -n +8` | 从**第 8 行**开始输出 |

### `tail -n +8` 是什么鬼

大多数人只见过 `tail -n 10`（最后 10 行）。

**`+8` 是另一种模式：从第 8 行开始，输出到结尾。**

```bash
seq 1 10 | tail -n +8
# 8
# 9
# 10
```

**所以 `-1t` 排好序后，`+8` 就是"第 8 个及以后的文件"** —— 也就是最旧的几个。

### 在哪个脚本里

```bash
KEEP=7
ls -1t "$BACKUP_DIR"/*.sql.gz 2>/dev/null | tail -n +$((KEEP + 1)) | while read -r old; do
    rm -f "$old"
done
```

**`$((KEEP + 1))` 就是 `8`。** 写 `$((KEEP + 1))` 而不是硬写 `8`，是为了以后改 `KEEP=30` 时不用改两处。

### `$(( ))` 是什么

**算术展开**——里面可以写数学运算。

```bash
echo $((3 + 5))            # 8
echo $((10 / 3))           # 3      ← 整数除法，小数被丢掉
echo $((10 % 3))           # 1      ← 取余
KEEP=7
echo $((KEEP + 1))         # 8
```

**注意：`$(( ))` 里面写变量名不用 `$`，写 `$KEEP` 也行，两种都能跑。**

### 坑在哪

**`ls` 处理文件名里有空格的情况很差。** 生产环境更稳的写法是：

```bash
find "$BACKUP_DIR" -name "*.sql.gz" -printf "%T@ %p\n" | sort -rn | tail -n +8 | cut -d' ' -f2-
```

**但今天不用管这个** —— 你的备份文件名是自己生成的，不可能带空格。**知道有这回事就行。**

---

## 十三、调试三件套

### `bash -n`：只检查语法

```bash
bash -n log_rotate.sh
```

**不执行，只解析。** 有语法错会打印行号，没错什么都不输出。

**写完脚本第一件事就跑这个。**

### `bash -x`：逐行跟踪

```bash
bash -x log_rotate.sh
```

输出：

```
+ LOG_DIR=/var/log/apache2
+ ARCHIVE=/root/log-archive
++ date +%Y%m%d
+ TODAY=20261114
+ find /var/log/apache2 -maxdepth 1 -name '*.log' -mtime +7
```

**前缀几个 `+` 就是几层嵌套：**

| 前缀 | 含义 |
|---|---|
| `+` | 主 shell 在跑 |
| `++` | 命令替换 `$(...)` 里在跑 |
| `+++` | 再深一层 |

**卡在哪一行，一眼就看见。**

### `file`：看文件类型和编码

```bash
file log_rotate.sh
```

- `Bourne-Again shell script, ASCII text executable` ✅
- `... with CRLF line terminators` ❌ 有 Windows 换行符
- `... Unicode text, UTF-8` ✅ 有中文注释，正常

### CRLF 是什么

| 系统 | 换行符 |
|---|---|
| Windows | `\r\n`（两个字符） |
| Linux | `\n`（一个字符） |

**Windows 文件拿到 Linux，多个 `\r`，shell 会把它当成命令的一部分。**

**症状：**

```
bash: ./script.sh: /bin/bash^M: bad interpreter
./script.sh: 31: a: not found
扫描 中 7 天前的 .log            ← 变量内容被 \r 覆盖了
```

**一条命令修：**

```bash
sed -i 's/\r$//' script.sh
```

`\r$` = 行尾的回车符，替换成空。

---

## 十四、`chmod +x` 和 `./`

### 为什么双击跑不了

Linux 里，一个文件要有 **`x`（执行）权限**才能被当程序跑。

```bash
ls -l log_rotate.sh
# -rw-r--r-- 1 root root 639 ...     ← 没有 x
```

`chmod +x log_rotate.sh` 之后：

```bash
ls -l log_rotate.sh
# -rwxr-xr-x 1 root root 639 ...     ← 有了 x
```

### 为什么必须写 `./`

```bash
log_rotate.sh          # ❌ command not found
./log_rotate.sh        # ✅
```

**因为当前目录 `.` 不在 `PATH` 里。**

`PATH` 是系统找命令的搜索路径列表。`/bin`、`/usr/bin` 在里面，`.`（当前目录）**不在**。

**这是故意的安全设计** —— 否则你在某个目录里 `cd` 过去，恶意文件叫 `ls`，你敲 `ls` 就中招了。

**`./` 的意思是"就这个目录里的这个文件，别去 PATH 里找"。**

---

## 十五、一页速查

| 你想干什么 | 写法 |
|---|---|
| 取命令输出放进变量 | `X=$(cmd)` |
| 取"今天"的日期 | `TODAY=$(date +%Y%m%d)` |
| 去掉 `.log` 后缀 | `${name%.log}` |
| 找 7 天前的文件 | `find 目录 -mtime +7` |
| 逐行读 | `... \| while read -r line` |
| 跳过第一行 | `awk 'NR>1'` |
| 去百分号 | `gsub(/%/, "", $5)` |
| 写进文件（覆盖） | `cmd > f` |
| 写进文件（追加） | `cmd >> f` |
| 丢掉错误 | `cmd 2>/dev/null` |
| 判断上条是否成功 | `[ $? -ne 0 ]` |
| 判断文件非空 | `[ -s "$f" ]` |
| 整数运算 | `$((a + b))` |
| 从第 8 行开始输出 | `tail -n +8` |
| 按时间从新到旧 | `ls -1t` |
| 只查语法 | `bash -n 脚本` |
| 逐行跟踪 | `bash -x 脚本` |
| 修 Windows 换行 | `sed -i 's/\r$//' 脚本` |

---

## 十六、闭卷五题

**不翻上面，写纸上。**

**Q1** `$?` 等于 `0` 表示成功还是失败？为什么说这个设计"反直觉"？

**Q2** `find /var/log -mtime +7` 和 `find /var/log -mtime 7` 有什么区别？

**Q3** `name="access.log"`，`${name%.log}` 的结果是什么？`${name%.gz}` 呢？为什么不报错？

**Q4** `cmd > f 2>/dev/null` 里，`>` 和 `2>` 分别管什么？为什么调试时要临时去掉 `2>/dev/null`？

**Q5** `ls -1t *.gz | tail -n +8` 为什么能实现"只留最近 7 份"？`+8` 和 `8` 有什么区别？

---

### 答案

**A1** `0` 表示**成功**。反直觉是因为日常数字里 0 是"没有/失败"，而在退出码体系里 0 = 没有错误 = 成功。非 0 才是失败。

**A2** `+7` = **修改时间超过 7 天**（7 天前及更早）；`7` = **恰好第 7 天那一天**（第 7×24 到 8×24 小时之间）。做清理要 `+7`。

**A3** `${name%.log}` → `access`；`${name%.gz}` → `access.log`（原样返回）。**不报错是因为截取规则没匹配上时就原样返回**，这个"静默不报错"很危险，可能产出错文件名。

**A4** `>` 把**标准输出**写进文件；`2>` 把**标准错误**重定向。`2>/dev/null` 把错误丢进黑洞，调试时要临时去掉——否则真正的报错（如 `Access denied`）被藏起来，你只看到"失败了"不知道为什么。

**A5** `-1t` 按修改时间从新到旧排，`tail -n +8` 从第 8 个开始输出（即最旧的那些），正好跳过最新的 7 个。`+8` 是"从第 8 行到结尾"，`8` 是"最后 8 行"——完全相反。

---

# 附录 A：调试三件套详解

## A.0 三个工具各管一段

| 工具 | 回答什么问题 | 检查层面 |
|---|---|---|
| `file` | 这文件本身是好的吗？ | **字节层**（换行符、编码、BOM） |
| `bash -n` | 语法对吗？ | **语法层**（括号配对、关键字闭合） |
| `bash -x` | 运行时到底发生了什么？ | **执行层**（变量值、分支走向、命令参数） |

**排查顺序永远是：file → bash -n → bash -x。**

**先确定"文件是好的"，再确定"写得对"，最后才查"跑起来为什么不对"。**

跳过前两步直接 `-x`，会在一个字节错误上浪费半小时。

---

## A.1 `file`：看文件到底是什么

### 用法

```bash
file log_rotate.sh
```

### 四种可能的输出

| 输出 | 含义 | 能用吗 |
|---|---|---|
| `Bourne-Again shell script, ASCII text executable` | 纯 ASCII，有执行权限 | ✅ 完美 |
| `Bourne-Again shell script, Unicode text, UTF-8 text` | 含中文，UTF-8 编码 | ✅ 正常 |
| `... ASCII text, with CRLF line terminators` | **有 Windows 换行符** | ❌ 必须修 |
| `... with BOM` | 文件开头有隐藏字节 | ❌ 必须修 |

### CRLF 为什么会出事

| 系统 | 换行 = 几个字节 | 具体是什么 |
|---|---|---|
| Linux | 1 个 | `\n`（0x0A） |
| Windows | 2 个 | `\r\n`（0x0D 0x0A） |

**Windows 文件到 Linux，每行末尾多一个 `\r`。**

shell 读 `done\r` 时，不认为这是关键字 `done`，而是"一个叫 `done\r` 的命令"。

**三种典型症状：**

```
bash: ./script.sh: /bin/bash^M: bad interpreter: No such file or directory
./script.sh: 31: a: not found
扫描 中 7 天前的 .log          ← 变量内容里的 \r 把前面的字覆盖了
```

**最后一种最难懂**：`\r` 是"回车"，终端收到它会把光标移回行首，后面输出的字覆盖前面的字。**看起来像"变量丢了"，其实变量有值，只是被遮住了。**

### 怎么确诊（两种手段互相印证）

```bash
file log_rotate.sh              # 手段 1：看有没有 CRLF
cat -A log_rotate.sh | head -5  # 手段 2：把不可见字符显示成符号
```

`cat -A` 会把每行结尾显示成 `$`，回车显示成 `^M`：

```
#!/bin/bash^M$          ← ^M 就是 \r
LOG_DIR="/var/log/apache2"^M$
```

**没有 `^M` 就是干净的：**

```
#!/bin/bash$
LOG_DIR="/var/log/apache2"$
```

### 修法

```bash
sed -i 's/\r$//' log_rotate.sh
```

`\r$` = 每行末尾的回车符，替换成空。

**修完再 `file` 一次确认。**

### BOM 是什么

有些编辑器（尤其 Windows 记事本）会在文件**最开头**加三个字节 `EF BB BF`，叫 BOM。

**后果**：`#!` 前面多了三个看不见的字节，shebang 失效。

```bash
# 检查
head -c 3 log_rotate.sh | od -An -tx1
# ef bb bf    ← 有 BOM
# 23 21 2f    ← 没有（23='#', 21='!', 2f='/'）

# 去掉
sed -i '1s/^\xEF\xBB\xBF//' log_rotate.sh
```

**今天的脚本不会遇到，但记住有这回事。**

---

## A.2 `bash -n`：只检查语法，不执行

### 用法

```bash
bash -n log_rotate.sh
```

- **没输出** = 语法没问题
- **有输出** = 语法错误，带行号

### 典型输出

```bash
$ bash -n bad.sh
bad.sh: line 12: syntax error: unexpected end of file
```

**意思是"读到文件末尾还没找到配对的 `done`/`fi`/`}`"。**

常见触发：

| 症状 | 原因 |
|---|---|
| `unexpected end of file` | `if` 少了 `fi`；`for/while` 少了 `done` |
| `syntax error near unexpected token 'fi'` | 多了个 `fi` |
| `syntax error near unexpected token 'then'` | `if` 后面少了 `; then` 或没换行 |
| `unexpected EOF while looking for matching '"'` | 引号没配对 |

### 它不检查什么（重要）

**`bash -n` 只解析，不执行，所以下面这些它一个都发现不了：**

| 你写错了 | bash -n 会报吗 |
|---|---|
| `findd /var/log`（命令名打错） | ❌ 不报 |
| `cd /var/logg`（路径不存在） | ❌ 不报 |
| `echo $LOG_DIRR`（变量名打错，值为空） | ❌ 不报 |
| `if [ "$a" -gt 80 ]` 但 a 是空 | ❌ 不报 |
| 逻辑写反了 | ❌ 不报 |

**这些只能靠 `bash -x` 或实际跑一遍。**

### 一个容易踩的坑：别用 `sh -n` 检查 bash 脚本

```bash
sh -n log_rotate.sh      # ❌ 会误报
bash -n log_rotate.sh    # ✅
```

`sh`（dash）不认识 bash 的扩展语法，会把合法的代码报成错误。

**同理，`bash -n` 检查一个 sh 脚本也可能误判。检查器要和解释器一致。**

### 什么时候用

- **写完脚本立刻跑一次**（改完也跑）
- **从别处拷来的脚本**（先看语法再执行，防恶意/防低级错）
- **改了一行之后**（改出括号不配对是常事）

---

## A.3 `bash -x`：逐行跟踪执行

### 用法

```bash
bash -x log_rotate.sh
```

**它会先展开变量、替换命令，再把"真正要执行的那一行"打印出来（前缀 `+`），然后执行。**

### 输出长什么样

```bash
+ LOG_DIR=/var/log/apache2
+ ARCHIVE=/root/log-archive
+ DAYS=7
+ mkdir -p /root/log-archive
++ date +%Y%m%d
+ TODAY=20261114
+ echo '=== 扫描 /var/log/apache2 中 7 天前的 .log ==='
=== 扫描 /var/log/apache2 中 7 天前的 .log ===
+ find /var/log/apache2 -maxdepth 1 -name '*.log' -mtime +7
+ read -r file
++ basename /var/log/apache2/other_vhosts_access.log
+ name=other_vhosts_access.log
+ stem=other_vhosts_access
```

**两类行：**

| 行 | 是什么 |
|---|---|
| `+ 命令` | 主 shell 要执行的命令（**已展开变量**） |
| 没有 `+` 的行 | 命令的**实际输出** |

### `+` 的层数 = 嵌套深度

| 前缀 | 含义 |
|---|---|
| `+` | 主 shell |
| `++` | 命令替换 `$(...)` 内部 |
| `+++` | 再深一层（`$( $( ... ) )`） |

**所以这段：**

```
++ date +%Y%m%d
+ TODAY=20261114
```

**读作：先跑 `date` 得到 20261114，再把它赋给 TODAY。**

**这是看懂别人脚本里 `$(...)` 的最好办法——不用猜，跑一次就摊开了。**

### 它最强的地方：能看见"空变量"和"隐藏字符"

**① 变量是空的，一眼就看见：**

```bash
+ echo '=== 扫描  中 7 天前的 .log ==='
#              ↑↑ 这里应该有个路径，但空了
```

**对比正常：**

```bash
+ echo '=== 扫描 /var/log/apache2 中 7 天前的 .log ==='
```

**② 变量里带 `\r`，bash 会显示成 `$'\r'`：**

```bash
+ LOG_DIR=$'/var/log/apache2\r'
```

**看到 `$'...'` 这种写法，就说明值里有不可见字符。** 这是 CRLF 最直接的物证——比 `cat -A` 还快。

**③ 分支走到哪，看得清清楚楚：**

```bash
+ [ -s /root/db-backup/dvwa.sql ]
+ echo '[失败] 备份文件是空的'
```

**或者：**

```bash
+ [ -s /root/db-backup/dvwa.sql ]
+ gzip /root/db-backup/dvwa.sql
```

**`if` 到底进了哪个分支，`-x` 直接告诉你。**

### 加行号（强烈推荐）

**默认的 `+` 不带行号，长脚本对不上号。加个环境变量就行：**

```bash
PS4='+ ${LINENO}: ' bash -x log_rotate.sh
```

输出变成：

```
+ 7: LOG_DIR=/var/log/apache2
+ 12: mkdir -p /root/log-archive
+ 17: echo '=== 扫描 /var/log/apache2 中 7 天前的 .log ==='
```

**`+ 17:` 就是"第 17 行"。** 出问题直接跳到那一行看。

**想永久生效，写进 `~/.bashrc`：**

```bash
echo "export PS4='+ \${LINENO}: '" >> ~/.bashrc
source ~/.bashrc
```

### 只跟踪一小段（脚本里加开关）

**脚本几百行，只想看某一段：**

```bash
#!/bin/bash
echo "这段不跟踪"

set -x               # ← 从这里开始跟踪
find /var/log -name "*.log" -mtime +7 | while read -r f; do
    echo "处理 $f"
done
set +x               # ← 到这里停止

echo "这段也不跟踪"
```

| 命令 | 作用 |
|---|---|
| `set -x` | 开启跟踪 |
| `set +x` | 关闭跟踪 |

**注意是 `+x` 关，不是 `-x`。** 这里有反直觉：`set -x` 开，`set +x` 关。

### 输出太多怎么办

**循环几千次时，`-x` 会刷屏。三种办法：**

```bash
# 办法 1：存进文件，事后慢慢看
bash -x log_rotate.sh 2> trace.log
less trace.log

# 办法 2：只看前 50 行
bash -x log_rotate.sh 2>&1 | head -50

# 办法 3：只看最后 30 行（看它死在哪）
bash -x log_rotate.sh 2>&1 | tail -30
```

**为什么是 `2>` 不是 `>`？** 因为 `-x` 的跟踪输出走**标准错误**（stderr），不是标准输出。这个细节很多人踩。

### `-x` 和 `-v` 的区别（容易混）

| 选项 | 打印什么 | 时机 |
|---|---|---|
| `-v` | **脚本原文那一行** | **展开前** |
| `-x` | **展开后的命令** | **展开后** |

```bash
bash -v script.sh     # 打印 echo $FOO
bash -x script.sh     # 打印 echo hello   ← 变量已替换
```

**日常只用 `-x`。** `-v` 只在排查"引号里的东西被吃掉了"这种怪问题时才有用。

---

## A.4 进阶：`set -euo pipefail`

**脚本写稳一点，加这三行：**

```bash
#!/bin/bash
set -euo pipefail
```

| 选项 | 作用 | 通俗说法 |
|---|---|---|
| `-e` | 任何命令失败就退出 | 出错即停，不往下瞎跑 |
| `-u` | 用未定义变量就报错 | 变量名打错立刻发现 |
| `-o pipefail` | 管道里任一环节失败就算失败 | `a \| b` 时 a 挂了不会被 b 掩盖 |

**为什么重要**：默认情况下，脚本里某一行失败了，它会**继续往下跑**，最后可能"成功退出"——这比崩溃更危险。

**⚠️ 注意 `-e` 有例外**：写在 `if`、`&&`、`||` 后面的命令失败**不会**触发退出（因为那是"允许失败"的语境）。这是设计如此。

**今天的脚本没加，因为要演示完整的错误处理。** 学会手写判断之后再加这行，会写出更稳的脚本。

---

## A.5 `shellcheck`：静态检查器

**不是三件套里的，但值得知道。**

```bash
sudo apt install shellcheck -y
shellcheck log_rotate.sh
```

**它会在不执行的情况下，指出引号、变量、常见陷阱：**

```
In log_rotate.sh line 20:
find "$LOG_DIR" ... | while read -r file; do
     ^-- SC2086: Double quote to prevent globbing and word splitting.
```

**`SC2086` 是最高频的一条：变量没加引号。**

**好处**：能在你跑之前就发现 80% 的低级错误。
**坏处**：啰嗦，初学者容易被吓到。**等你能跑通三个脚本之后再装。**

---

## A.6 按症状选工具

| 你看到的 | 先查什么 | 命令 |
|---|---|---|
| `bad interpreter` / `No such file` | 文件格式 | `file` |
| `syntax error` | 语法 | `bash -n` |
| 脚本跑了但结果不对 | 执行过程 | `bash -x` |
| 变量是空的 | 执行过程 | `bash -x`（看 `+ echo '...'`） |
| 循环只跑了一次 | 执行过程 | `bash -x` |
| 输出中文乱码 | 编码 | `file`、`cat -A` |
| 变量名打错 | 执行过程 | `set -u` 或 `bash -x` |
| 判断分支走错 | 执行过程 | `bash -x` |

---

## A.7 用你今天的 bug 复盘

**你遇到的三个报错，三件套分别会怎么说：**

### 报错 1：`扫描 中 7 天前的 .log`（变量"消失"）

| 工具 | 会看到什么 |
|---|---|
| `file` | `... with CRLF line terminators` ← **直接命中** |
| `cat -A` | `LOG_DIR="/var/log/apache2"^M$` |
| `bash -x` | `+ echo '=== 扫描 /var/log/apache2'$'\r'' 中 7 天前的 .log ==='` |
| `bash -n` | 大概率不报（语法没错，只是多了个字符） |

**结论：这是字节层问题，`bash -n` 抓不到，`file` 一秒定位。**

### 报错 2：`: 31: a: not found`

| 工具 | 会看到什么 |
|---|---|
| `file` | CRLF（同上） |
| `bash -n` | 可能报 `syntax error: unexpected end of file`（`done\r` 认不出来） |
| `bash -x` | 会跑不到第 31 行就提前结束，或打印出带 `$'\r'` 的命令 |

**报错格式 `: 31: a: not found` 本身也是线索** —— 没有 `line` 两个字，说明跑在 `sh` 下，不是 `bash`。

### 报错 3：`find: unknown predicate '-verbose'`

| 工具 | 会看到什么 |
|---|---|
| `bash -x` | `+ find /var/log/apache2 -name '*.gz' -mtime +7 -delete -verbose` |
| 其他 | 无感 |

**结论：这是"命令参数不存在"的问题，只能靠跑或查 man。`bash -x` 让你看清到底传了什么参数。**

**去查：**

```bash
man find | grep -A2 verbose
find --help | grep -i verbose
```

---

## A.8 五分钟练习

**自己造三个坏脚本，练手上工具：**

```bash
# ① 语法错（少 done）
cat > /tmp/bad1.sh << 'EOF'
#!/bin/bash
for f in *.log; do
    echo $f
EOF
bash -n /tmp/bad1.sh

# ② 变量名打错
cat > /tmp/bad2.sh << 'EOF'
#!/bin/bash
DIR=/var/log
echo "目录: $DIRR"
EOF
bash -n /tmp/bad2.sh     # 不报
bash -x /tmp/bad2.sh     # 看见 echo '目录: '

# ③ CRLF
printf '#!/bin/bash\necho hello\r\n' > /tmp/bad3.sh
bash /tmp/bad3.sh
file /tmp/bad3.sh
```

**三个都跑一遍，你对这三件套的手感就出来了。**
