import SwiftUI
import Combine
import UserNotifications

@main
struct TonesApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var authService = AuthService.shared
    @StateObject private var notificationRouter = NotificationRouter.shared
    
    init() {
        setupAppearance()
    }
    
    var body: some Scene {
        WindowGroup {
            NavigationStack {
                Group {
                    if let user = authService.currentUser {
                        if !user.hasUsername {
                            SetUsernameView()
                        } else if !user.hasCompletedOnboarding {
                            SetProfilePictureView()
                        } else {
                            HomeView()
                        }
                    } else {
                        WelcomeView()
                    }
                }
            }
            .environmentObject(authService)
            .onChange(of: notificationRouter.pendingChatId) { _, newChatId in
                if newChatId != nil {
                    notificationRouter.pendingChatId = nil
                }
            }
        }
    }
    
    private func setupAppearance() {
        let coralUIColor = UIColor(red: 1.0, green: 0.6, blue: 0.55, alpha: 1.0)
        UINavigationBar.appearance().tintColor = coralUIColor
        UITextField.appearance(whenContainedInInstancesOf: [UITextField.self]).tintColor = coralUIColor
        let tabBarAppearance = UITabBarAppearance()
        tabBarAppearance.configureWithDefaultBackground()
        UITabBar.appearance().standardAppearance = tabBarAppearance
    }
}

class NotificationRouter: ObservableObject {
    static let shared = NotificationRouter()
    @Published var pendingChatId: String? = nil
    
    private init() {}
}

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    application.registerForRemoteNotifications()
                }
            }
        }
        return true
    }
    
    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AuthService.shared.didRegisterForRemoteNotifications(deviceToken: deviceToken)
    }
    
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("Failed to register for remote notifications: \(error)")
    }
    
    @MainActor func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        let userInfo = response.notification.request.content.userInfo
        if let chatId = userInfo["chatId"] as? String {
            NotificationRouter.shared.pendingChatId = chatId
        }
        completionHandler()
    }
    
    @MainActor func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}