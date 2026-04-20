# Tones Deployment Complete

## Deployed API
**Staging URL:** https://tones-api-staging.jazing14.workers.dev

## API Endpoints (Working)

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/apple` | POST | Sign in with Apple |
| `/auth/refresh` | POST | Refresh token |
| `/auth/me` | GET | Get current user |
| `/auth/username` | POST | Set username |
| `/users/search?q=` | GET | Search users |

## Test Results

```bash
# 1. Sign in with Apple
curl -X POST https://tones-api-staging.jazing14.workers.dev/auth/apple \
  -H "Content-Type: application/json" \
  -d '{"apple_token": "your_apple_token"}'

# 2. Get user profile  
curl -X GET https://tones-api-staging.jazing14.workers.dev/auth/me \
  -H "Authorization: Bearer <access_token>"

# 3. Set username
curl -X POST https://tones-api-staging.jazing14.workers.dev/auth/username \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer <access_token>" \
  -d '{"username": "yourhandle"}'

# 4. Search users
curl -X GET "https://tones-api-staging.jazing14.workers.dev/users/search?q=john" \
  -H "Authorization: Bearer <access_token>"
```

## Database
- **D1:** `tones` (85c743b7-ed33-4292-bed1-03dd0446d6a9)

## Local Storage
All chat/audio data stored on iPhone - no server storage needed!

## Next Steps
1. Open app in Xcode
2. Run on Simulator or device
3. Test Apple Sign In
4. Set username
5. Create local chats