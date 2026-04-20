# Tune — Audio-only messaging

Minimal end-to-end sample: iOS app + Cloudflare Pages Functions + KV + R2.

## iOS App

- SwiftUI, Swift Concurrency, no third-party deps.
- Tap a chat: auto-plays last tune (voice message), immediately starts recording your reply; tap anywhere to stop and send.

### Required Info.plist keys

Add to your target Info tab (or Info.plist):

- Privacy - Microphone Usage Description (`NSMicrophoneUsageDescription`): "Tune uses the mic to record tunes."
- App Transport Security Settings -> Allow Arbitrary Loads = YES (or configure your real HTTPS domain and remove this).

### Configure API base URL

Edit `APIClient.swift` and set your Pages domain:

```swift
init(baseURL: URL = URL(string: "https://<your-pages>.pages.dev")!, session: URLSession = .shared)
