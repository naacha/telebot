# Owner Commands Documentation (@zalhera only)

## 🔒 Access Control
Only the user with username `zalhera` can access these commands.

## 📋 Available Commands

### `/env` - Environment Management
View current configuration (sensitive values masked):
```
/env
```

### `/env get KEY` - Get Specific Value
Retrieve a specific environment variable:
```
/env get BOT_TOKEN
/env get GOOGLE_CLIENT_ID
```

### `/env set KEY VALUE` - Update Configuration
Set or update environment variables:
```
/env set MAX_SPEED_MBPS 10
/env set GOOGLE_CLIENT_ID new-client-id
/env set GOOGLE_CLIENT_SECRET new-secret
```

### `/env reload` - Refresh Settings
Reload environment from file:
```
/env reload
```

### `/restart` - System Restart
Restart the bot container:
```
/restart
```

## 🔧 Usage Examples

### Update OAuth2 Credentials
```
/env set GOOGLE_CLIENT_ID 123456-abc.apps.googleusercontent.com
/env set GOOGLE_CLIENT_SECRET GOCSPX-new-secret-key
/env reload
```

### Modify Download Settings
```
/env set MAX_SPEED_MBPS 8
/env set MAX_CONCURRENT_DOWNLOADS 3
/restart
```

## 🛡️ Security Features

- **Username verification**: Only @zalhera can access
- **Value masking**: Sensitive data automatically hidden
- **Secure storage**: File permissions set to 0o600
- **Real-time updates**: Changes apply immediately

## ⚠️ Important Notes

1. Changes to certain values (like BOT_TOKEN) require restart
2. OAuth2 credentials need /restart to take effect
3. Always verify changes with `/env get KEY`
4. Use `/restart` after major configuration changes

## 🔍 Troubleshooting

### Command Not Working?
- Verify username is exactly `zalhera`
- Check bot has proper permissions
- Ensure container is running

### Changes Not Applied?
- Use `/env reload` after manual file edits
- Use `/restart` for core configuration changes
- Check logs with management scripts
