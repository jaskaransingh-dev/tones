import SwiftUI
import UserNotifications

@main
struct TonesApp: App {
    @StateObject private var authService = AuthService.shared
    
    init() {
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Group {
                    if let user = authService.currentUser {
                        if user.hasUsername {
                            HomeView()
                        } else {
                            SetUsernameView()
                        }
                    } else {
                        WelcomeView()
                    }
                }
            }
            .environmentObject(authService)
        }
    }
    
    private func setupAppearance() {
        let coralUIColor = UIColor(red: 1.0, green: 0.6, blue: 0.55, alpha: 1.0)
        UINavigationBar.appearance().tintColor = coralUIColor
        UITextField.appearance(whenContainedInInstancesOf: [UITextField.self]).tintColor = coralUIColor
    }
}