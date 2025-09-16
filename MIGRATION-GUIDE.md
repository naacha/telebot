# Migration from credentials.json to OAuth2

## Quick Migration:

### 1. Backup Current Setup:
```bash
cp -r /opt/leech-bot-speed /backup/
```

### 2. Deploy OAuth2 Version:
```bash
unzip bot-tele-3-oauth2.zip -d /opt/leech-bot-speed-oauth2
cd /opt/leech-bot-speed-oauth2
```

### 3. Setup OAuth2:
```bash
# Follow OAUTH2-SETUP-GUIDE.md
# Configure .env with Client ID/Secret
# NO credentials.json needed!
```

### 4. Migrate Data:
```bash
cp /backup/data/* ./data/
```

### 5. Test & Switch Over:
```bash
./build.sh && ./start.sh
# Test /auth and /d commands
# Switch DNS/proxy when ready
```

## Benefits After Migration:
✅ No more credentials.json file
✅ Better security
✅ Easier deployment
✅ Automatic token management

Support: @Zalherathink
