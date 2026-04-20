import SwiftUI

@main
struct TonesApp: App {
    @StateObject private var authService = AuthService.shared

    init() {
        setupAppearance()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if authService.currentUser != nil {
                    HomeView()
                } else {
                    WelcomeView()
                }
            }
            .environmentObject(authService)
        }
    }

    private func setupAppearance() {
        let yellow = UIColor(red: 1.0, green: 0.867, blue: 0, alpha: 1.0)
        UINavigationBar.appearance().tintColor = UIColor.black
        UITextField.appearance(whenContainedInInstancesOf: [UITextField.self]).tintColor = UIColor.black
    }
}