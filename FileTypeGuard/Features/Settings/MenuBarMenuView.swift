import AppKit
import SwiftUI

/// Menu shown when the status item is visible in the macOS menu bar.
struct MenuBarMenuView: View {
    @EnvironmentObject private var appCoordinator: AppCoordinator
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Open FileTypeGuard") {
            appCoordinator.openMainWindow(using: openWindow)
        }

        Divider()

        Button(appCoordinator.isMonitoring ? "Pause Monitoring" : "Start Monitoring") {
            if appCoordinator.isMonitoring {
                appCoordinator.stopMonitoring()
            } else {
                appCoordinator.startMonitoring()
            }
        }

        Button("Check Now") {
            appCoordinator.checkNow()
        }
        .disabled(!appCoordinator.isMonitoring)

        Divider()

        Button("Quit FileTypeGuard") {
            NSApplication.shared.terminate(nil)
        }
    }
}
