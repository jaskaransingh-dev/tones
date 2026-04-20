import SwiftUI

@main
struct TuneApp: App {
    @StateObject private var audioSession = AudioSession()
    @AppStorage("tune.userId") private var userId: String = ""

    var body: some Scene {
        WindowGroup {
            if userId.isEmpty {
                UsernameView()
                    .environmentObject(audioSession)
            } else {
                ChatListView()
                    .environmentObject(audioSession)
            }
        }
    }
}
