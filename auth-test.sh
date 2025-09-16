#!/bin/bash
echo "🔑 OAuth2 Authentication Test"
echo "============================"
cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs)
fi

CONTAINER_NAME=${CONTAINER_NAME:-"leech-bot"}

if ! docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo "❌ Container not running. Start with ./start.sh"
    exit 1
fi

echo "🔍 Checking OAuth2 configuration..."
echo ""

# Check environment variables
if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo "❌ GOOGLE_CLIENT_ID not set in .env"
    CONFIG_OK=false
else
    echo "✅ GOOGLE_CLIENT_ID configured"
    CONFIG_OK=true
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo "❌ GOOGLE_CLIENT_SECRET not set in .env"
    CONFIG_OK=false
else
    echo "✅ GOOGLE_CLIENT_SECRET configured"
fi

echo ""

if [ "$CONFIG_OK" != "true" ]; then
    echo "❌ OAuth2 configuration incomplete!"
    echo "📖 See: OAUTH2-SETUP-GUIDE.md"
    exit 1
fi

# Check token file
echo "🔍 Checking authentication status..."
if docker exec ${CONTAINER_NAME} test -f /app/data/google_token.json; then
    echo "✅ OAuth2 token file exists"

    # Try to validate token (if possible)
    TOKEN_CONTENT=$(docker exec ${CONTAINER_NAME} cat /app/data/google_token.json 2>/dev/null)
    if echo "$TOKEN_CONTENT" | grep -q "access_token"; then
        echo "✅ Token contains access_token"
    else
        echo "⚠️ Token file may be corrupted"
    fi

    echo ""
    echo "🔗 Token file location: /app/data/google_token.json"
    echo "📊 Token size: $(docker exec ${CONTAINER_NAME} wc -c < /app/data/google_token.json 2>/dev/null || echo "unknown") bytes"
else
    echo "❌ OAuth2 token not found"
    echo ""
    echo "📝 To authenticate:"
    echo "   1. Send /auth to bot in Telegram"
    echo "   2. Complete OAuth2 flow in browser"
    echo "   3. Token will be stored automatically"
fi

echo ""
echo "📋 Next steps:"
echo "   • Test in Telegram: /auth"
echo "   • Check logs: ./logs.sh | grep -i oauth"  
echo "   • View status: /stats in Telegram"
echo ""
echo "📖 Need help? See OAUTH2-SETUP-GUIDE.md"
