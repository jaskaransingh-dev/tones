# Tones Deployment

Production: https://tones-api-prod.jazing14.workers.dev

## Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/auth/apple` | POST | Sign in with Apple |
| `/auth/demo` | POST | Sign in with demo username (App Review) |
| `/auth/refresh` | POST | Refresh token |
| `/auth/me` | GET | Get current user |
| `/auth/username` | POST | Set username |
| `/auth/avatar` | POST | Upload avatar |
| `/auth/push-token` | POST | Register APNs device token |
| `/auth/delete` | POST | Permanently delete account (Guideline 5.1.1(v)) |
| `/users/search?q=` | GET | Search users (excludes blocked) |
| `/users/block` | POST | Block a user (Guideline 1.2) |
| `/users/unblock` | POST | Unblock a user |
| `/users/blocked` | GET | List blocked users |
| `/reports` | POST | Report a user/message (Guideline 1.2) |
| `/friends` | GET | List friends |
| `/friends/add` | POST | Add a friend |
| `/chats/dm` | POST | Create or fetch DM |
| `/chats/group` | POST | Create group chat |
| `/chats` | GET | List chats |
| `/chats/:id/messages` | GET/POST | List or send messages |
| `/chats/:id/messages/heard` | POST | Mark messages heard |
| `/chats/:id` | PUT | Update group chat |

## Database

D1 `tones` (`85c743b7-ed33-4292-bed1-03dd0446d6a9`).

Apply schema and demo data:

```bash
# 1. Apply schema (idempotent)
wrangler d1 execute tones --remote --file=sql/schema.sql

# 2. Generate + apply demo seed for App Review
./sql/seed_demo.sh
wrangler d1 execute tones --remote --file=sql/seed_demo.sql
```

## APNs configuration

Push notifications require these `wrangler secret`s on the production worker:

```bash
wrangler secret put PUSH_PRIVATE_KEY  --env production   # the full PEM, with -----BEGIN/-----END lines
wrangler secret put PUSH_KEY_ID       --env production   # the 10-char Key ID from Apple Developer
wrangler secret put TEAM_ID           --env production   # your Apple Team ID
```

The worker now signs APNs JWTs with ES256 via SubtleCrypto (`generateAPNSJWT`) and caches the
token for 50 minutes.

## App Review (Guideline 2.1(a)) — what to paste into App Store Connect

In App Store Connect → My Apps → Tones → App Review Information:

```
Demo Account
─────────────
Sign-in: this app uses Sign in with Apple. To verify all features without an
Apple ID, the app includes a hidden demo mode for App Review.

How to access demo mode:
  1. Open the app to the welcome screen.
  2. Tap the round Tones logo at the top 5 times in a row.
  3. Enter the demo username:  appreview
  4. Tap "sign in".

The demo account is pre-populated with 4 friends (alex, sam, jordan, riley),
2 direct-message chats, and 1 group chat ("weekend crew") with sample voice
messages. To test sending tones to another account, tap the logo 5 times again
on a second device or after signing out, and use any of: alex, sam, jordan, riley.

Notes
─────────────
- Required permission: Microphone (used to record voice messages).
- Account deletion: Settings (top-left avatar on home) → "delete account".
- Block/Report: open any DM → tap the "⋯" button in the top-right.
- Blocked-users list: Settings → "blocked users".

Contact
─────────────
jaskaransinghdoel@gmail.com
```

Also fill these App Store Connect fields:

- **Privacy Policy URL** — host the policy currently shown in `Settings → privacy policy` at a public URL.
- **Support URL** — a page (or mailto link) where users can reach you.
- **App Privacy** (data types collected): user identifier (Apple sub),
  username, avatar image, push token, audio messages.
- **Export compliance** — "Uses standard encryption (HTTPS only)" for most cases.

## Local test

```bash
# Demo sign-in
curl -X POST https://tones-api-prod.jazing14.workers.dev/auth/demo \
  -H "Content-Type: application/json" \
  -d '{"username": "appreview"}'

# Block
curl -X POST https://tones-api-prod.jazing14.workers.dev/users/block \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"blocked_id": "<user_id>"}'

# Report
curl -X POST https://tones-api-prod.jazing14.workers.dev/reports \
  -H "Authorization: Bearer <access_token>" \
  -H "Content-Type: application/json" \
  -d '{"reported_user_id": "<user_id>", "reason": "spam"}'

# Delete account
curl -X POST https://tones-api-prod.jazing14.workers.dev/auth/delete \
  -H "Authorization: Bearer <access_token>"
```
