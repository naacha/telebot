# OAuth2 Troubleshooting Guide

## Common OAuth2 Issues:

### 1. Client ID Invalid
```
Error: invalid_client

Solutions:
- Check GOOGLE_CLIENT_ID format
- Verify client ID from Google Console
- Ensure OAuth consent screen configured
```

### 2. Token Refresh Failed
```
Error: refresh_token not found

Solutions:
- Delete token file: rm /app/data/google_token.json
- Re-authenticate: /auth
- Check offline access granted
```

### 3. Redirect URI Mismatch
```
Error: redirect_uri_mismatch

Solutions:
- Check GOOGLE_REDIRECT_URI
- Ensure localhost:8080 accessible
- Use manual flow if needed
```

Support: @Zalherathink
