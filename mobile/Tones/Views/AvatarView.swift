import SwiftUI

struct AvatarView: View {
    let urlString: String?
    let initial: String
    let size: CGFloat

    @State private var avatarImage: UIImage?

    var body: some View {
        ZStack {
            if let uiImage = avatarImage {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: size, height: size)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Color.warmPeach)
                    .frame(width: size, height: size)
                Text(initial)
                    .font(.system(size: size * 0.38, weight: .light))
                    .foregroundStyle(Color.warmCoral)
            }
        }
        .onAppear { loadAvatar() }
        .onChange(of: urlString) { _, _ in loadAvatar() }
    }

    private func loadAvatar() {
        guard let urlString, !urlString.isEmpty, urlString != "none" else {
            avatarImage = nil
            return
        }
        if urlString.hasPrefix("data:") {
            let parts = urlString.split(separator: ",", maxSplits: 1)
            guard parts.count == 2,
                  let data = Data(base64Encoded: String(parts[1])),
                  let image = UIImage(data: data) else {
                avatarImage = nil
                return
            }
            avatarImage = image
        } else {
            guard let url = URL(string: urlString) else { return }
            Task {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    if let image = UIImage(data: data) {
                        await MainActor.run { avatarImage = image }
                    }
                } catch {
                    await MainActor.run { avatarImage = nil }
                }
            }
        }
    }
}