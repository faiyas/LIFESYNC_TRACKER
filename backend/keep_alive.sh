#!/bin/bash
# ==============================================================================
# LifeSync Instabox Keep-Alive Daemon
# Sends a keep-alive heartbeat ping every 10 minutes to prevent the VM from sleeping.
# ==============================================================================

INTERVAL=600 # 10 minutes (600 seconds)
LOG_FILE="keep_alive.log"

echo "=========================================="
echo "⚡ Starting LifeSync Keep-Alive Daemon"
echo "⏰ Ping Interval: Every 10 minutes"
echo "=========================================="

while true; do
    TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
    
    # 1. Ping Local Django Server
    LOCAL_STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://127.0.0.1:8000/api/health/ || echo "FAIL")
    
    # 2. Touch active heartbeat file
    touch .heartbeat
    
    echo "[$TIMESTAMP] Heartbeat OK | Local Health HTTP: $LOCAL_STATUS" >> "$LOG_FILE"
    echo "[$TIMESTAMP] Heartbeat OK | Local Health HTTP: $LOCAL_STATUS"
    
    # Keep the log file compact (last 500 lines)
    if [ $(wc -l < "$LOG_FILE") -gt 500 ]; then
        tail -n 250 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
    fi
    
    sleep "$INTERVAL"
done
