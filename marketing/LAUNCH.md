# Tones — Launch Kit

Voice messages, nothing else.

---

## 1. Slogans (pick one — A/B test variants)

**Primary:** voice messages, nothing else.

**Variants:**
- talk. don't type.
- the inbox you actually listen to.
- voice notes, organized.
- one tap. one tone. one reply.
- texting is loud. voice is louder.

---

## 2. App Store

### Subtitle (30 char)
voice messages, nothing else.

### Promotional text (170 char)
no typing. no scrolling. open a chat — your friend's voice plays automatically and the mic is ready for your reply. tones is the calmest way to keep in touch.

### Description (4000 char max)

tones is voice messages, done right. no feeds. no likes. no read receipts to obsess over. just a calm inbox of unheard voices from the people you actually care about.

open a chat → unheard tones play automatically.
tap once to record. tap again to send.
that's the whole app.

WHY TONES

— voice carries tone. tone carries meaning.
texting strips the warmth out of conversations. tones puts it back.

— faster than typing, calmer than calling.
your friend hears you when they're ready. you reply on your own time. nobody is left "online."

— no algorithm. no infinite scroll.
your tones live in chats with people you chose. that's it.

— private by default.
audio lives on your device. no public profiles. no follower counts.

WHAT'S INSIDE

• 1-on-1 voice chats with auto-play
• group voice threads up to 32 people
• live waveform while you record
• tap-to-send (no awkward "press and hold")
• share your @handle with one tap
• apple sign in or pick a username — no password

PERFECT FOR

• couples who hate texting all day
• friends in different time zones
• family members who want to hear you, not read you
• small teams who'd rather not sit on a call
• anyone who feels burned out by chat apps

tones is built by one person, in public. no ads. no tracking. no AI summarizing your friends.

just voice.

### Keywords (100 char, comma-separated)
voice,message,chat,audio,messenger,walkie talkie,push to talk,voice notes,group voice,podcast friends

### What's New (4000 char) — v1.0
this is the first version of tones. say hi.

### App Store Categories
Primary: **Social Networking**
Secondary: **Communication**

### Age Rating
4+

### Support URL & Marketing URL
- Support: github.com/<your-handle>/tones-support (or a simple Notion page)
- Marketing: tones.app (or your landing page)

---

## 3. Product Hunt

### Tagline (60 char, start with a verb)
voice messages, nothing else. no typing, no feeds.

**Tagline variants (pick the best one for your audience):**
- talk to friends without typing.
- voice notes, organized like an inbox.
- the calmest way to keep in touch.
- replace your group chat with voice.

### First comment (you, the maker — paste at launch)

hey product hunt 👋

i built tones because my group chats had become unreadable walls of text and i missed actually hearing my friends.

tones is intentionally tiny:
• open a chat → unheard voice notes play automatically
• tap once to record, tap again to send
• that's the whole product

what it ISN'T:
• not a feed
• not "social" — there are no followers, no public profiles
• not push-to-hold (just tap)
• not chat + voice — it is *only* voice

i'd love to know:
1. what's the longest you've gone without texting today?
2. would you use this with your partner / family / a specific friend?
3. one thing that would make you actually keep it on your phone?

it's free, no signup wall, ios only for now. android coming if there's love.

— jas

### Description (260 char)
tones is the calmest voice messenger. open a chat → unheard tones play automatically. tap to record, tap to send. no feeds, no likes, no public profiles — just voice between friends. ios.

### Topics (pick up to 4)
- Messaging
- Social Networking
- iOS
- Productivity (or Communication)

### Maker comment hooks (drop into replies as conversations come in)
- "voice carries 38% of meaning that text strips out — that's the whole pitch"
- "no feed, no likes — every screen in the app is a person you chose to add"
- "everything's stored on-device. server only knows who your friends are."

---

## 4. Launch day plan (Tuesday or Wednesday, 12:01 AM PT)

### T-2 weeks
- [ ] Create the Product Hunt "coming soon" / upcoming page; collect emails.
- [ ] Soft-launch to 30–50 friends to get TestFlight feedback + bug reports.
- [ ] Reach out to a respected hunter (Chris Messina, Kevin William David). Optional but lifts credibility.
- [ ] Build a 60-second demo screen recording (real device, real audio).

### T-3 days
- [ ] App Store: submit & get approved (don't release).
- [ ] Schedule App Store release for the **same day** as PH (use phased rollout off, manual release).
- [ ] Pre-write 5–6 reply templates for common PH comments.

### Launch day (00:01 PT)
- [ ] Post your maker comment within 5 minutes of launch.
- [ ] DM the 50 people who said they'd vote. Don't ask for upvotes — say "tones is live, would love your feedback".
- [ ] Post on X/Bluesky/IG stories with the cover image (`marketing/producthunt/png/01_cover.png`).
- [ ] Reply to **every** PH comment within 30 minutes for the first 6 hours.
- [ ] At ~10 AM PT, post in 2–3 relevant communities (Indie Hackers, r/iosapps).

### Post-launch
- [ ] Add the PH badge to your landing page (~17% signup lift per the data).
- [ ] Write a "lessons from launching #N" post within 7 days — drives the long tail.

---

## 5. Marketing assets in this folder

```
marketing/
├── appstore/                    # 1290 × 2796 (6.9" iPhone, Apple's required size)
│   ├── 01_hero.svg/png
│   ├── 02_tap_to_talk.svg/png
│   ├── 03_auto_play.svg/png
│   ├── 04_inbox.svg/png
│   └── 05_chat.svg/png
├── producthunt/                 # 1270 × 760 (gallery) + 240×240 thumb
│   ├── 01_cover.svg/png
│   ├── 02_pitch.svg/png
│   ├── 03_features.svg/png
│   ├── 04_record.svg/png
│   ├── 05_tape.svg/png
│   ├── 06_inbox.svg/png
│   └── thumbnail.svg/png
└── generate.py                  # regenerate everything from one script
```

To regenerate (e.g. tweak palette/copy):
```
python3 marketing/generate.py
# then re-render PNGs:
./marketing/png.sh   # see "Re-rendering" below
```

### Re-rendering SVG → PNG
PNGs are rendered with Chrome headless because it nails sub-pixel AA at the right aspect ratio. macOS comes with Chrome at the standard path. If you don't have Chrome, install librsvg (`brew install librsvg`) and swap to `rsvg-convert`.

---

## 6. Research notes (sources)

- **Product Hunt #1 playbook:** launch Tue/Wed at 12:01 AM PT, prep the audience for ≥2 months, partner with an established hunter, reply to every comment in the first 6 hours. Skip editing the live page — it resets your trending score.
- **App Store screenshots (2025+):** 6.9" iPhone (1290×2796) is now the *mandatory* baseline; iPad 13" (2064×2752) too. Must be flat JPEG/PNG, RGB, no alpha. Use real in-app UI, not abstract art (rejection risk).
- **Conversion:** users decide in ~7s. First two screenshots are everything. Bright color + high contrast lifts CTR.
- **Voice category competitors:** Marco Polo (video, 1:1, "watch on your time"), Voxer (push-to-talk walkie-talkie), Wispr Flow / Stet (dictation, not chat). Tones' wedge: *no feed, no public profile, auto-play unheard, tap-not-hold*.

Sources:
- [Product Hunt Launch Playbook (Arc)](https://arc.dev/employer-blog/product-hunt-launch-playbook/)
- [Product Hunt Launch Checklist 47 Steps (Flowjam)](https://www.flowjam.com/blog/product-hunt-launch-checklist-47-steps-to-1-in-2025)
- [App Store Screenshots That Convert (AppScreenshotStudio, 2026)](https://medium.com/@AppScreenshotStudio/app-store-screenshots-that-convert-the-2026-design-guide-4438994689d6)
- [App Store screenshot sizes 2025 (SplitMetrics)](https://splitmetrics.com/blog/app-store-screenshots-aso-guide/)
- [Marco Polo App Store](https://apps.apple.com/us/app/marco-polo-video-messenger/id912561374)
- [Voxer Walkie Talkie Messenger](https://apps.apple.com/us/app/voxer-walkie-talkie-messenger/id377304531)
- [Stet on Product Hunt](https://www.hunted.space/dashboard/stet-a-smart-dictation-for-rest-of-us)
