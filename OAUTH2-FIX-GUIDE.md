# OAuth2 Error Fix Guide

## 🚨 Error: "Error 400: invalid_request - missing response_type"

### Root Cause
The OAuth2 client configuration is incorrect or incomplete.

### ✅ Solution Steps

#### 1. Verify Google Cloud Setup
- OAuth client must be **Web Application** type (NOT Desktop)
- Redirect URI must include: `http://localhost:8080`
- OAuth consent screen must be configured

#### 2. Check Client Configuration
```python
# Correct configuration (Web Application):
client_config = {
    "web": {  # This must be "web", not "installed"
        "client_id": "your-client-id",
        "client_secret": "your-client-secret",
        "auth_uri": "https://accounts.google.com/o/oauth2/auth",
        "token_uri": "https://oauth2.googleapis.com/token",
        "redirect_uris": ["http://localhost:8080"]
    }
}
```

#### 3. Run OAuth2 Fix
```bash
chmod +x fix-oauth2.sh
./fix-oauth2.sh
```

### 🔍 Diagnosis Tools

#### Check Configuration
```bash
./fix-oauth2.sh  # Automated diagnosis
./logs.sh        # View detailed logs
```

#### Manual Testing
```bash
# Test OAuth URL generation
docker exec telegram-bot python -c "
import os
from google_auth_oauthlib.flow import Flow
# Test OAuth2 configuration
"
```

### 🎯 Common Solutions

1. **Wrong Client Type**: Change to Web Application
2. **Missing Redirect URI**: Add http://localhost:8080
3. **Incorrect Scopes**: Use drive.file scope
4. **Consent Screen**: Ensure published status

### ✅ Verification
After fixing, test with:
1. `/auth` command - should generate valid URL
2. Complete OAuth flow - should work without errors
3. `/d [link]` - should download and upload successfully
