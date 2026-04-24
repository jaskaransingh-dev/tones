import SwiftUI

// MARK: - Tones design system
// Minimalist palette: warm neutral background, single coral accent,
// fresh green for "live/voice" moments. Everything else is monochrome.

extension Color {
    // Background & surfaces
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.93)   // primary bg
    static let warmSand  = Color(red: 0.96, green: 0.93, blue: 0.87)   // muted card

    // Text
    static let warmDark  = Color(red: 0.10, green: 0.09, blue: 0.08)   // headlines
    static let warmBrown = Color(red: 0.36, green: 0.30, blue: 0.26)   // body / secondary

    // Brand accent (coral) — used sparingly
    static let warmCoral  = Color(red: 0.98, green: 0.43, blue: 0.36)
    static let warmPeach  = Color(red: 1.00, green: 0.86, blue: 0.79)  // soft coral surface

    // Live / voice green — only for active recording / unread
    static let callGreen  = Color(red: 0.16, green: 0.72, blue: 0.42)
    static let softGreen  = Color(red: 0.30, green: 0.78, blue: 0.54)

    // Legacy aliases (kept so existing views compile)
    static let warmRose     = Color(red: 0.95, green: 0.75, blue: 0.73)
    static let warmLavender = Color(red: 0.82, green: 0.72, blue: 0.88)
}

// MARK: - Spacing / radius / type tokens

enum TonesSpacing {
    static let xs: CGFloat  = 4
    static let s: CGFloat   = 8
    static let m: CGFloat   = 14
    static let l: CGFloat   = 22
    static let xl: CGFloat  = 32
}

enum TonesRadius {
    static let chip: CGFloat   = 12
    static let card: CGFloat   = 18
    static let modal: CGFloat  = 24
}

// MARK: - Background

struct WarmBackground: View {
    var body: some View {
        ZStack {
            Color.warmCream.ignoresSafeArea()

            // Single soft coral wash, top-left. Calmer & more minimalist than
            // the previous multi-blob gradient.
            GeometryReader { geo in
                Circle()
                    .fill(Color.warmPeach.opacity(0.32))
                    .frame(width: geo.size.width * 1.1)
                    .blur(radius: 100)
                    .offset(x: -geo.size.width * 0.4, y: -geo.size.height * 0.35)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}
