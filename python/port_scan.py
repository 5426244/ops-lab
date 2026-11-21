#!/usr/bin/env python3
"""port_scan.py - 批量探测一组端口是否开放

用法:
    python3 port_scan.py                # 扫本机
    python3 port_scan.py 192.168.59.130 # 扫靶机
"""

import socket
import sys

PORTS = [22, 80, 443, 3306, 8080, 1524]


def check_port(host, port, timeout=1.0):
    """返回 True 表示端口开放"""
    s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    s.settimeout(timeout)
    code = s.connect_ex((host, port))
    s.close()
    return code == 0


def main():
    host = sys.argv[1] if len(sys.argv) > 1 else "127.0.0.1"
    print(f"目标: {host}")
    print("-" * 30)

    open_ports = []
    for port in PORTS:
        if check_port(host, port):
            print(f"[开放] {port}")
            open_ports.append(port)
        else:
            print(f"[关闭] {port}")

    print("-" * 30)
    print(f"共扫描 {len(PORTS)} 个端口，开放 {len(open_ports)} 个")
    print(f"开放的端口: {open_ports}")


if __name__ == "__main__":
    main()
