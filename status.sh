#!/bin/bash
cd "$(dirname "$0")"
export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo "📊 Bot Status"
echo "============="

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "✅ Status: RUNNING"
    echo ""
    echo "📋 Container Info:"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" -f name=${CONTAINER_NAME}
    echo ""
    echo "💾 Resource Usage:"
    docker stats ${CONTAINER_NAME} --no-stream --format "CPU: {{.CPUPerc}}\tMemory: {{.MemUsage}}"
    echo ""
    echo "🔧 Management:"
    echo "./logs.sh    - View logs"
    echo "./stop.sh    - Stop bot"
    echo "./restart.sh - Restart bot"
else
    echo "❌ Status: NOT RUNNING"
    echo ""
    echo "🚀 Start: ./start.sh"
fi
