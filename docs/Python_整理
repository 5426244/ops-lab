# Python 学习记录

> 按天整理，每天只留**能跑的最短代码**和**一句记住的话**。
> 最后有一节「最容易记混的 6 组」，专门治混淆。

---

# 第 1 天 · 变量、print、input

## 代码

```python
name = "张野"
age = 25
print("你好，", name)
print(f"{name} 今年 {age} 岁")

ip = input("请输入 IP: ")
print("你输入的是", ip)
```

## 关键点

| 写法 | 意思 |
|---|---|
| `name = "张野"` | 赋值（`=` 右边算完，存到左边） |
| `print(a, b)` | 逗号分隔，打印多个值（自动加空格） |
| `f"{name}"` | f-string，字符串里插变量 |
| `input("提示")` | **返回的永远是字符串** |

## 记住这一句

**`input()` 拿回来的是字符串，要算数得先 `int()`。**

---

# 第 2 天 · 列表 + for 循环

## 代码

```python
ports = [22, 80, 443]
print(ports[0])       # 22
print(ports[-1])      # 443
ports.append(3306)    # 加到末尾
print(len(ports))     # 4

for p in ports:
    print(p)
```

## 关键点

| 写法 | 意思 |
|---|---|
| `[22, 80, 443]` | 列表，方括号 + 逗号 |
| `ports[0]` | 第 1 个（**下标从 0 开始**） |
| `ports[-1]` | 最后一个 |
| `.append(x)` | 往末尾加一个 |
| `len(x)` | 有几个 |
| `for p in ports:` | 逐个取出来，冒号结尾、下面缩进 |

## 记住这一句

**「下标 0 = 第 1 个，下标 -1 = 最后一个。」**

---

# 第 3 天 · if 判断 + 字符串处理

## 代码

```python
line = '192.168.59.128 - - "GET /DVWA/ HTTP/1.1" 200 1234'

low = line.lower()                 # 全转小写
if "get" in low:
    print("这是 GET 请求")

parts = line.split()               # 按空格切
ip = parts[0]                      # 第一段就是 IP
print(ip)
```

## 字符串五件套

| 写法 | 意思 |
|---|---|
| `"abc" in s` | s 里包不包含 abc |
| `s.lower()` | 转小写 |
| `s.strip()` | 去掉两端空白（含换行） |
| `s.split()` | 按空白切 → 列表 |
| `s.startswith("GET")` | 以什么开头 |

## if 的形状

```python
if score >= 90:
    print("优秀")
elif score >= 60:
    print("及格")
else:
    print("不及格")
```

## 记住这一句

**`==` 是比较，`=` 是赋值。写错一个，代码不报错但结果全错。**

---

# 第 4 天 · 函数 + return

## 代码

```python
def add(a, b):
    return a + b

def check(ports):
    bad = []
    for p in ports:
        if p in [21, 23]:
            bad.append(p)
    return bad

print(add(3, 5))            # 8
print(check([22, 23, 445])) # [23]
```

## 关键点

| 部位 | 意思 |
|---|---|
| `def 名字(参数):` | 定义函数，冒号 + 缩进 |
| `return 值` | 把结果交回去，**函数立刻结束** |
| 没写 `return` | 返回 `None`（什么也没有） |

## `print` vs `return`

```python
def f():
    print("A")      # 显示在屏幕上，抓不住

x = f()             # 屏幕出现 A
print(x)            # None
```

## 记住这一句

**`print` 给人看，`return` 给程序用。**

---

# 第 5 天 · 文件读写

## 读（最常用）

```python
with open("/var/log/apache2/access.log", encoding="utf-8", errors="ignore") as f:
    for line in f:
        print(line.strip())
```

## 写

```python
with open("out.txt", "w") as f:      # w = 覆盖
    f.write("hello\n")

with open("out.txt", "a") as f:      # a = 追加
    f.write("more\n")
```

## 关键点

| 写法 | 意思 |
|---|---|
| `with open(...) as f:` | 打开文件，**离开缩进块自动关闭** |
| `for line in f:` | 一行一行读（大文件也不炸内存） |
| `line.strip()` | 去掉行尾的换行符 |
| `errors="ignore"` | 遇到乱码字符跳过，不崩 |

## 记住这一句

**读文件一律 `with open`；每行读出来第一件事是 `.strip()`。**

---

# 第 6 天 · try / except

## 代码

```python
try:
    x = int("abc")
except ValueError:
    print("转不了，这不是数字")
```

## 常见异常

| 异常名 | 什么时候出现 |
|---|---|
| `ValueError` | 值不对（`int("abc")`） |
| `FileNotFoundError` | 文件不存在 |
| `PermissionError` | 没权限读 |
| `KeyError` | 字典里没这个键 |
| `IndexError` | 列表越界 |

## 规则

```python
try:
    print(1)
    print(2)      # ← 这里出错，后面的不执行
    print(3)
except ValueError:
    print("出错")
print(4)          # ← except 结束后继续执行
```

**`try` 里没出错 → 整个 `except` 被跳过。**

## 记住这一句

**只接你预料到的异常，别写裸 `except:`（会把所有错都吞掉）。**

---

# 第 7 天 · 字典计数 + 排序

## 字典计数（最常用的套路）

```python
counts = {}

for ip in ["1.1.1.1", "2.2.2.2", "1.1.1.1"]:
    counts[ip] = counts.get(ip, 0) + 1

print(counts)     # {'1.1.1.1': 2, '2.2.2.2': 1}
```

**为什么不能写 `counts[ip] += 1`：第一次遇到这个键时它还不存在，会 `KeyError`。**

## 按次数排序

```python
items = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)
```

| 部分 | 意思 |
|---|---|
| `counts.items()` | 变列表：`[("1.1.1.1", 2), ("2.2.2.2", 1)]` |
| `key=lambda kv: kv[1]` | 按**第 2 个**（次数）排 |
| `reverse=True` | 从大到小 |
| `items[:5]` | 取前 5 个 |

## 记住这一句

**「`sorted` 排整体，`key=` 决定拿哪部分比；`kv[1]` = 拿次数比。」**

---

# 串起来：`log_stat.py` 每一行来自第几天

| 代码 | 来自 |
|---|---|
| `path = sys.argv[1] if ...` | 第 7 天（参数） |
| `with open(...) as f:` | 第 5 天 |
| `for line in f:` | 第 2 天 + 第 5 天 |
| `parts = line.split()` | 第 3 天 |
| `if not parts: continue` | 第 3 天（判断） |
| `ip = parts[0]` | 第 3 天 |
| `counts[ip] = counts.get(ip, 0) + 1` | 第 7 天 |
| `if " 404 " not in line:` | 第 3 天（`in`） |
| `sorted(..., key=lambda, reverse=True)` | 第 7 天 |
| `try / except FileNotFoundError` | 第 6 天 |
| `print(f"{c:>6}  {ip}")` | 第 1 天（f-string） |

**30 行脚本 = 七天的东西拼起来，没有一行是新的。**

---

# 最容易记混的 6 组

## ① `split()` vs `split(' ')`

```python
"a  b".split()       # ['a', 'b']        连续空格算一个分隔
"a  b".split(' ')    # ['a', '', 'b']    多出一个空串
```

**默认用 `split()`，别传参数。**

## ② `parts[0]` vs `parts[-1]`

```python
parts = ["127.0.0.1", "-", "-", "200"]
parts[0]     # "127.0.0.1"    第一个
parts[-1]    # "200"          最后一个
```

## ③ `print` vs `return`

```python
def a():
    print(5)      # 屏幕有 5，但 x 是 None

def b():
    return 5      # 屏幕没东西，但 x 是 5
```

## ④ `if not x`

```python
if not parts:       # parts 是空的 → 执行下面
if not line:        # line 是空字符串 → 执行
if not os.path.exists(p):   # 路径不存在 → 执行
```

**`not` 就是「不」。空列表、空字符串、0、None 都算「假」。**

## ⑤ `=` vs `==`

```python
x = 5       # 赋值：把 5 放进 x
if x == 5:  # 比较：x 等不等于 5
```

## ⑥ 列表 vs 字典

```python
ports = [22, 80]              # 列表：靠位置，ports[0]
counts = {"1.1.1.1": 2}       # 字典：靠名字，counts["1.1.1.1"]
```

**列表是「一排格子」，字典是「带标签的抽屉」。**

---

# 现在能写什么 / 还不会什么

## ✅ 现在就能写

| 能做什么 | 用到 |
|---|---|
| 读日志统计每个 IP 访问次数 | 第 5、7 天 |
| 找出 404 最多的 IP | 第 3、7 天 |
| 判断哪些端口是危险端口 | 第 2、3 天 |
| 把结果写成文件 | 第 5 天 |
| 处理"文件不存在/没权限" | 第 6 天 |

## ❌ 还没学（不用急）

| 不会 | 什么时候学 |
|---|---|
| 正则 `re` | 第 4 周写工具时 |
| `requests` 发请求 | 第 4 周 |
| 类 `class` | 基本用不上 |
| 多线程 | 用不上 |

---

# 每天 3 分钟复习法

**打开终端，不看笔记，凭记忆敲：**

```
第 1 天：打印自己的名字和年龄
第 2 天：造一个端口列表，for 打印出来
第 3 天：切一行日志，取出 IP
第 4 天：写一个函数，返回列表里所有危险端口
第 5 天：读一个文件，逐行打印
第 6 天：用 try/except 接住 int("abc")
第 7 天：统计一组 IP 出现次数并排序
```

**七段都能凭记忆敲出来，这套就真会了。**

**敲不出来的那天，回来翻对应那节，别从头看。**
