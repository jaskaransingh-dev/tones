import SwiftUI

extension Color {
    static let warmCream = Color(red: 0.99, green: 0.97, blue: 0.94)
    static let warmPeach = Color(red: 1.0, green: 0.86, blue: 0.79)
    static let warmCoral = Color(red: 0.96, green: 0.45, blue: 0.38)
    static let warmRose = Color(red: 0.95, green: 0.75, blue: 0.73)
    static let warmSand = Color(red: 0.96, green: 0.93, blue: 0.88)
    static let warmBrown = Color(red: 0.35, green: 0.28, blue: 0.24)
    static let warmDark = Color(red: 0.12, green: 0.10, blue: 0.09)
    static let callGreen = Color(red: 0.16, green: 0.68, blue: 0.38)
    static let softGreen = Color(red: 0.28, green: 0.74, blue: 0.50)
    static let warmLavender = Color(red: 0.82, green: 0.72, blue: 0.88)
}

struct WarmBackground: View {
    var body: some View {
        ZStack {
            Color.warmCream.ignoresSafeArea()
            GeometryReader { geo in
                ZStack {
                    Circle()
                        .fill(Color.warmPeach.opacity(0.4))
                        .frame(width: geo.size.width * 0.9)
                        .blur(radius: 80)
                        .offset(x: -geo.size.width * 0.35, y: -geo.size.height * 0.3)
                    Circle()
                        .fill(Color.warmRose.opacity(0.2))
                        .frame(width: geo.size.width * 0.75)
                        .blur(radius: 90)
                        .offset(x: geo.size.width * 0.4, y: geo.size.height * 0.35)
                    Circle()
                        .fill(Color.warmLavender.opacity(0.08))
                        .frame(width: geo.size.width * 0.5)
                        .blur(radius: 70)
                        .offset(x: geo.size.width * 0.1, y: -geo.size.height * 0.15)
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
        }
    }
}