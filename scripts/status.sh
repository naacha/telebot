#!/bin/bash
# STB Status Script

cd "$(dirname "$0")"

echo "📊 STB HG680P Telegram Bot Status"
echo "================================="
echo ""

echo "🐳 Docker Services:"
docker-compose ps
echo ""

echo "💻 STB System Resources:"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3}') used / $(free -h | awk '/^Mem:/ {print $2}') total"
echo "Storage: $(df -h / | awk 'NR==2 {print $3}') used / $(df -h / | awk 'NR==2 {print $2}') total"
echo "CPU Load: $(uptime | cut -d',' -f3-)"
echo "Temperature: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000"°C"}' || echo 'N/A')"
echo ""

echo "📡 Network:"
ip addr show | grep inet | grep -v 127.0.0.1 | head -2
echo ""

echo "🔧 Docker Info:"
docker system df
