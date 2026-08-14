// DSHRemoteApp.swift — app entry: notification permission, root view, URL scheme.

import SwiftUI
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    /// Foreground presentation: banners still show while the app is open.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .list]
    }

    /// Notification tap: jump straight to the session it belongs to.
    func userNotificationCenter(_ center: UNUserNotificationCenter,
                                didReceive response: UNNotificationResponse) async {
        guard let sessionId = response.notification.request.content.userInfo["sessionId"] as? String else { return }
        await MainActor.run {
            AppState.live?.selectedSessionId = sessionId
        }
    }
}

@main
struct DSHRemoteApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @State private var state = AppState()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            RootView(state: state)
                .task {
                    AppState.live = state
                    requestNotificationPermission()
                }
                .onOpenURL { url in
                    handlePairingURL(url)
                }
                .onChange(of: scenePhase) { _, phase in
                    // 回到前台：SSE 可能已假死，强制重建事件流
                    if phase == .active, state.isConnected {
                        state.reconnectStream()
                        Task { await state.refresh() }
                    }
                }
        }
    }

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// dshremote://pair?host=...&port=...&token=...
    private func handlePairingURL(_ url: URL) {
        guard let config = PairingURL.parse(url) else { return }
        state.config = config
        state.disconnect()
        state.connect()
    }
}
