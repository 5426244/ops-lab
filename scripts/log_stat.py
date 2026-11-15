import sys


def count_ips(path):
    """统计每个 IP 出现的次数"""
    counts = {}
    with open(path, encoding="utf-8", errors="ignore") as f:
        for line in f:
            parts = line.split()
            if not parts:
                continue
            if " 404 " not in line:
                continue
            ip = parts[0]
            counts[ip] = counts.get(ip, 0) + 1
    return counts


def top_n(counts, n=5):
    """按次数倒序，取前 n 个"""
    items = sorted(counts.items(), key=lambda kv: kv[1], reverse=True)
    return items[:n]


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "/var/log/apache2/access.log"
    try:
        counts = count_ips(path)
    except FileNotFoundError:
        print(f"文件不存在: {path}")
        return
    except PermissionError:
        print(f"没权限: {path}，用 sudo 跑")
        return

    print(f"共 {len(counts)} 个不同 IP，前 {5} 名：")
    for ip, c in top_n(counts):
        print(f"{c:>6}  {ip}")


if __name__ == "__main__":
    main()
