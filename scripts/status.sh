#!/bin/bash
# STB Status Script

cd "$(dirname "$0")"

echo "📊 STB HG680P Telegram Bot Status"
echo "================================="
echo ""

echo "🔑 Integrated Credentials:"
echo "✅ Bot Token: 8436081597:AAE-8bfWrbvhl26-l9y65p48DfWjQOYPR2A"
echo "✅ Channel ID: -1001802424804 (@ZalheraThink)"
echo ""

echo "🐳 Docker Services:"
docker-compose ps
echo ""

echo "🔌 Port Usage:"
netstat -tuln | grep :808 || echo "No ports 808x in use"
echo ""

echo "💻 STB System Resources:"
echo "Memory: $(free -h | awk '/^Mem:/ {print $3}') used / $(free -h | awk '/^Mem:/ {print $2}') total"
echo "Storage: $(df -h / | awk 'NR==2 {print $3}') used / $(df -h / | awk 'NR==2 {print $2}') total"
echo "CPU Load: $(uptime | cut -d',' -f3-)"
echo "Temperature: $(cat /sys/class/thermal/thermal_zone0/temp 2>/dev/null | awk '{print $1/1000"°C"}' || echo 'N/A')"
echo ""

echo "📢 Channel Status: @ZalheraThink subscription required"
echo ""

echo "🔧 Management Commands:"
echo "./start.sh   - Start bot"
echo "./stop.sh    - Stop bot"
echo "./restart.sh - Restart bot"
echo "./logs.sh    - View logs"
