#!/usr/bin/env python3
"""
LifeSync Instabox Keep-Alive Daemon
Pings the health endpoint every 10-14 minutes so Instabox free VM does not idle out.
"""

import time
import datetime
import urllib.request
import os

PING_INTERVAL_SECONDS = 720  # 12 minutes (well within the 20-minute timeout)
HEALTH_URL = "http://127.0.0.1:8000/api/health/"
LOG_FILE = "keep_alive.log"

print(f"[{datetime.datetime.now()}] LifeSync Keep-Alive Daemon running every {PING_INTERVAL_SECONDS // 60} minutes...")

while True:
    now_str = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    try:
        req = urllib.request.Request(HEALTH_URL, headers={"User-Agent": "LifeSync-KeepAlive/1.0"})
        with urllib.request.urlopen(req, timeout=10) as response:
            status_code = response.getcode()
            msg = f"[{now_str}] Heartbeat Ping SUCCESS (HTTP {status_code})"
    except Exception as e:
        msg = f"[{now_str}] Heartbeat Ping WARNING: {e}"

    print(msg)
    with open(LOG_FILE, "a") as f:
        f.write(msg + "\n")

    # Touch heartbeat timestamp file to simulate disk activity
    try:
        with open(".heartbeat", "w") as f:
            f.write(now_str)
    except Exception:
        pass

    time.sleep(PING_INTERVAL_SECONDS)
