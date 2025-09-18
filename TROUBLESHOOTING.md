# Troubleshooting Guide

## 🚨 Common Issues

### OAuth2 Error 400: invalid_request
**Symptoms**: OAuth2 authorization fails with missing response_type
**Solution**: Run `./fix-oauth2.sh` and ensure Web Application client type

### Container Restart Loop
**Symptoms**: Container keeps restarting
**Solution**: Check logs with `./logs.sh`, verify .env configuration

### Bot Not Responding
**Symptoms**: Bot doesn't respond to commands
**Solution**: Verify BOT_TOKEN is correct, check container status

### Download Failures
**Symptoms**: Downloads fail or don't upload to cloud
**Solution**: Verify OAuth2 authentication completed successfully

## 🔧 Diagnostic Tools

### Check Status
```bash
./status.sh      # Overall bot status
./logs.sh        # Real-time logs
./fix-oauth2.sh  # OAuth2 diagnosis
```

### Container Management
```bash
./start.sh       # Start bot
./stop.sh        # Stop bot
./restart.sh     # Restart bot
./shell.sh       # Access container
```

### Environment Debugging
```bash
# Check configuration
docker exec telegram-bot env | grep -E "(BOT_TOKEN|GOOGLE)"

# Test OAuth2
docker exec telegram-bot python -c "import google.auth; print('OK')"
```

## 🎯 Solution Matrix

| Problem | Symptoms | Solution |
|---------|----------|----------|
| OAuth2 Error | 400 invalid_request | `./fix-oauth2.sh` |
| Bot Offline | No response | Check BOT_TOKEN, restart |
| Download Fail | Error messages | Re-authenticate OAuth2 |
| Container Crash | Restart loop | Check logs, verify config |
| Permission Error | Access denied | Verify @zalhera username |

## 📞 Support Resources

### Log Files
- Container logs: `./logs.sh`
- System logs: `/app/logs/bot.log`
- Docker logs: `docker logs telegram-bot`

### Configuration Files
- Environment: `.env`
- OAuth tokens: `./data/token.json`
- Container config: `Dockerfile`

### Management Scripts
All scripts in package root directory provide comprehensive management and troubleshooting capabilities.
