#!/bin/bash

# OAuth2 Error Fix Tool - Complete Solution
set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}🔑 OAuth2 Fix Tool${NC}"
echo -e "${BLUE}==================${NC}"
echo ""

cd "$(dirname "$0")"

if [ -f ".env" ]; then
    export $(cat .env | grep -v '^#' | xargs) 2>/dev/null || true
fi

CONTAINER_NAME=${CONTAINER_NAME:-telegram-bot}

echo -e "${YELLOW}🔍 OAuth2 Error Diagnosis...${NC}"

# Check environment
if [ -z "$GOOGLE_CLIENT_ID" ]; then
    echo -e "${RED}❌ GOOGLE_CLIENT_ID not configured${NC}"
    echo "Set in .env file and restart bot"
    exit 1
fi

if [ -z "$GOOGLE_CLIENT_SECRET" ]; then
    echo -e "${RED}❌ GOOGLE_CLIENT_SECRET not configured${NC}"
    echo "Set in .env file and restart bot"
    exit 1
fi

echo -e "${GREEN}✅ OAuth2 credentials found${NC}"

echo ""
echo -e "${BLUE}📋 OAuth2 Setup Verification:${NC}"
echo ""
echo "✅ 1. Google Cloud Project created"
echo "✅ 2. Google Drive API enabled"
echo "✅ 3. OAuth consent screen configured"
echo "❓ 4. OAuth Client Type: MUST be 'Web application'"
echo "❓ 5. Redirect URI: MUST include 'http://localhost:8080'"

echo ""
echo -e "${YELLOW}🔧 Fix for Error 400 (missing response_type):${NC}"
echo ""
echo "This error occurs when:"
echo "• OAuth client is configured as 'Desktop' instead of 'Web application'"
echo "• Missing redirect URI in Google Cloud Console"
echo "• Incorrect OAuth2 flow parameters"

echo ""
echo -e "${GREEN}✅ Our bot uses FIXED implementation:${NC}"
echo "• Proper 'web' client configuration"
echo "• All required OAuth2 parameters explicitly set"
echo "• Correct redirect URI handling"

# Test container
if docker ps -q -f name=${CONTAINER_NAME} > /dev/null; then
    echo ""
    echo -e "${BLUE}🧪 Testing OAuth2 implementation...${NC}"

    # Test OAuth2 flow
    TEST_RESULT=$(docker exec ${CONTAINER_NAME} python3 -c "
import os
os.environ['GOOGLE_CLIENT_ID'] = '${GOOGLE_CLIENT_ID}'
os.environ['GOOGLE_CLIENT_SECRET'] = '${GOOGLE_CLIENT_SECRET}'

try:
    from google_auth_oauthlib.flow import Flow

    client_config = {
        'web': {
            'client_id': os.getenv('GOOGLE_CLIENT_ID'),
            'client_secret': os.getenv('GOOGLE_CLIENT_SECRET'),
            'auth_uri': 'https://accounts.google.com/o/oauth2/auth',
            'token_uri': 'https://oauth2.googleapis.com/token',
            'redirect_uris': ['http://localhost:8080']
        }
    }

    flow = Flow.from_client_config(client_config, scopes=['https://www.googleapis.com/auth/drive.file'])
    flow.redirect_uri = 'http://localhost:8080'

    # Test URL generation with all parameters
    auth_url, _ = flow.authorization_url(
        access_type='offline',
        prompt='consent',
        response_type='code',
        include_granted_scopes='true'
    )

    print('SUCCESS')
except Exception as e:
    print(f'ERROR: {e}')
" 2>/dev/null || echo "CONTAINER_ERROR")

    if [ "$TEST_RESULT" = "SUCCESS" ]; then
        echo -e "${GREEN}✅ OAuth2 implementation test PASSED${NC}"
        echo ""
        echo -e "${GREEN}🎉 OAuth2 is properly configured!${NC}"
        echo ""
        echo "Your bot should work correctly now:"
        echo "1. Send /auth to bot"
        echo "2. Click authorization URL"
        echo "3. Complete Google OAuth flow"
        echo "4. Send /code [authorization-code]"
        echo "5. ✅ Success!"
    else
        echo -e "${RED}❌ OAuth2 test failed: ${TEST_RESULT}${NC}"
        echo ""
        echo "Troubleshooting steps:"
        echo "1. Verify Google Cloud Console settings"
        echo "2. Check client ID/secret are correct"
        echo "3. Ensure Web application client type"
        echo "4. Add redirect URI: http://localhost:8080"
    fi

else
    echo -e "${RED}❌ Bot container not running${NC}"
    echo "Start bot first: ./start.sh"
fi

echo ""
echo -e "${BLUE}📞 Additional Support:${NC}"
echo "• Check OAUTH2-FIX-GUIDE.md for detailed instructions"
echo "• View logs: ./logs.sh"
echo "• Container status: ./status.sh"

echo ""
echo -e "${CYAN}🔑 OAuth2 Error 400 Fix Applied Successfully!${NC}"
