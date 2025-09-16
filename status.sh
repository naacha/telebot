#!/bin/bash
echo "📊 Bot Status (OAuth2 + Docker Direct)"
echo "======================================"
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "✅ Container Status: RUNNING"
    echo ""

    echo "📋 Container Information:"
    docker ps --format "table {{.Names}}	{{.Status}}	{{.Ports}}" -f name=${CONTAINER_NAME}
    echo ""

    echo "🔓 Root Access:"
    ROOT_USER=$(docker exec ${CONTAINER_NAME} whoami 2>/dev/null || echo "error")
    echo "   User: $ROOT_USER (should be root)"
    echo ""

    echo "🔑 OAuth2 Status:"
    if [ ! -z "$GOOGLE_CLIENT_ID" ]; then
        # Mask client ID for security
        MASKED_ID=$(echo "$GOOGLE_CLIENT_ID" | sed 's/./*/g' | sed 's/\*\*\*$/.../')
        echo "   Client ID: $MASKED_ID"
    else
        echo "   Client ID: ❌ Not configured"
    fi

    # Check token file exists
    TOKEN_STATUS=$(docker exec ${CONTAINER_NAME} test -f /app/data/google_token.json && echo "✅ Exists" || echo "❌ Missing")
    echo "   Token file: $TOKEN_STATUS"

    if [ "$TOKEN_STATUS" = "✅ Exists" ]; then
        # Try to get token expiry (if jq is available)
        EXPIRY=$(docker exec ${CONTAINER_NAME} sh -c "command -v jq >/dev/null && jq -r '.expiry // "unknown"' /app/data/google_token.json 2>/dev/null" || echo "unknown")
        if [ "$EXPIRY" != "unknown" ] && [ "$EXPIRY" != "null" ]; then
            echo "   Token expires: $EXPIRY"
        fi
    fi
    echo ""

    echo "📊 Speed Limiting:"
    echo "   Max concurrent: 2 downloads per user"
    echo "   Max speed: 5 MB/s per user"
    echo "   Auto cleanup: ✅ Enabled"
    echo ""

    echo "💾 Container Resources:"
    docker stats ${CONTAINER_NAME} --no-stream --format "   CPU: {{.CPUPerc}}	Memory: {{.MemUsage}}	Network: {{.NetIO}}"
    echo ""

    echo "🔧 Management Commands:"
    echo "   ./logs.sh       - View logs"
    echo "   ./shell.sh      - Access shell"
    echo "   ./auth-test.sh  - Test OAuth2"
    echo "   ./restart.sh    - Restart bot"

else
    echo "❌ Container Status: NOT RUNNING"
    echo ""
    echo "🚀 To start: ./start.sh"
    echo "📖 Setup guide: OAUTH2-SETUP-GUIDE.md"
fi
