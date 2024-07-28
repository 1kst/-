#!/bin/bash

# 域名和端口设置
DOMAIN="g.com"
PORTS=(39441 39442 39445 39443)
CHECK_INTERVAL=60  # 检测间隔（秒）
MAX_FAILED_CHECKS=5  # 最大失败检测次数

# Cloudflare API 设置
CLOUDFLARE_API_TOKEN="LDn3fPUHb"  # 使用提供的 Cloudflare API 令牌
ZONE_ID="222"  # 使用提供的区域 ID
RECORD_IDS=("222" "333")  # 替换为实际的 DNS 记录 ID
TARGET_DOMAIN="444.buzz"

# 日志设置
LOG_DIR="/root"
LOG_FILE="$LOG_DIR/port_check.log"

# 获取目标域名的 IP 地址
TARGET_IP=$(dig +short "$TARGET_DOMAIN" | tail -n 1)

# 计数器初始化
failed_checks=0

# 检测端口连通性
check_ports() {
  for port in "${PORTS[@]}"; do
    nc -z -w5 "$DOMAIN" "$port"
    if [ $? -eq 0 ]; then
      return 0  # 端口通
    fi
  done
  return 1  # 所有端口不通
}

# 更新 Cloudflare DNS 记录
update_dns_records() {
  for record_id in "${RECORD_IDS[@]}"; do
    curl -X PUT "https://api.cloudflare.com/client/v4/zones/$ZONE_ID/dns_records/$record_id" \
      -H "Authorization: Bearer $CLOUDFLARE_API_TOKEN" \
      -H "Content-Type: application/json" \
      --data "{\"type\":\"A\",\"name\":\"$(echo $DOMAIN | cut -d'.' -f1)\",\"content\":\"$TARGET_IP\",\"ttl\":1,\"proxied\":false}" >> "$LOG_FILE" 2>&1
  done
}

# 删除超过7天的日志
find "$LOG_DIR" -type f -name "*.log" -mtime +7 -exec rm {} \;

# 主循环
while true; do
  timestamp=$(date "+%Y-%m-%d %H:%M:%S")
  if check_ports; then
    failed_checks=0  # 端口通，重置计数器
    echo "$timestamp - Ports are reachable" >> "$LOG_FILE"
  else
    ((failed_checks++))  # 端口不通，增加计数器
    echo "$timestamp - Ports are not reachable (failed_checks=$failed_checks)" >> "$LOG_FILE"
  fi

  if [ "$failed_checks" -ge "$MAX_FAILED_CHECKS" ]; then
    echo "$timestamp - Updating DNS records" >> "$LOG_FILE"
    update_dns_records  # 更新 DNS 记录
    failed_checks=0  # 重置计数器
  fi

  sleep "$CHECK_INTERVAL"
done
