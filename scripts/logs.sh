#!/bin/bash
# STB Logs Script

echo "📋 STB HG680P Telegram Bot Logs"
echo "Press Ctrl+C to exit"
echo ""

docker-compose logs -f --tail=50
