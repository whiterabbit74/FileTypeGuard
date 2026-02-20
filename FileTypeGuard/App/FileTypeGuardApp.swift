import AppKit
import SwiftUI

private enum AppWindowID {
    static let main = "main-window"
}

final class FileTypeGuardAppDelegate: NSObject, NSApplicationDelegate {
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}

@main
struct FileTypeGuardApp: App {
    @NSApplicationDelegateAdaptor(FileTypeGuardAppDelegate.self) private var appDelegate
    @StateObject private var appCoordinator = AppCoordinator()

    var body: some Scene {
        Window("FileTypeGuard", id: AppWindowID.main) {
            MainView()
                .environmentObject(appCoordinator)
                .onAppear {
                    appCoordinator.handleMainWindowAppear()
                }
        }
        .defaultSize(width: 900, height: 600)

        MenuBarExtra(
            "FileTypeGuard",
            systemImage: "lock.shield.fill",
            isInserted: Binding(
                get: { appCoordinator.isMenuBarIconVisible },
                set: { _ in
                    // Avoid a two-way feedback loop from SwiftUI menu bar internals.
                }
            )
        ) {
            MenuBarMenuView()
                .environmentObject(appCoordinator)
        }
        .menuBarExtraStyle(.menu)
    }
}

/// 应用协调器
/// 负责管理监控和保护引擎的生命周期
@MainActor
final class AppCoordinator: ObservableObject {

    // MARK: - Properties

    private let monitor: FileAssociationMonitor
    private let protectionEngine: ProtectionEngine
    private let notificationService = NotificationService.shared
    private let configManager = ConfigurationManager.shared
    private var shouldHideInitialMainWindow = false
    private var hasExpandedMainWindowOnLaunch = false
    private var pendingValidationWorkItem: DispatchWorkItem?
    private let validationDebounceInterval: TimeInterval = 0.35
    private var isValidationInProgress = false
    private var needsValidationRerun = false

    @Published var isMonitoring = false
    @Published var appDisplayMode: AppDisplayMode = .dockOnly
    @Published var isMenuBarIconVisible = false

    // MARK: - Initialization

    init() {
        // 获取用户配置
        let preferences = configManager.getPreferences()
        let interval = preferences.checkInterval

        // 初始化监控器和保护引擎
        self.monitor = FileAssociationMonitor(pollingInterval: interval)
        self.protectionEngine = ProtectionEngine()
        self.appDisplayMode = preferences.appDisplayMode
        self.isMenuBarIconVisible = preferences.appDisplayMode.showsMenuBarIcon
        self.shouldHideInitialMainWindow = preferences.appDisplayMode == .menuBarOnly

        // 设置回调
        setupCallbacks()
        applyDisplayMode(preferences.appDisplayMode)

        // 请求通知权限
        Task {
            await notificationService.requestAuthorization()
        }

        // 如果配置了自动启动监控，则启动
        if preferences.monitoringEnabled {
            startMonitoring()
        }
    }

    // MARK: - Public Methods

    /// 启动监控
    func startMonitoring() {
        guard !isMonitoring else { return }

        monitor.startMonitoring()
        isMonitoring = true

        print("✅ AppCoordinator: 监控已启动")
    }

    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }

        monitor.stopMonitoring()
        isMonitoring = false

        print("✅ AppCoordinator: 监控已停止")
    }

    /// 手动触发检查
    func checkNow() {
        requestValidation(immediate: true)
    }

    func updateDisplayMode(_ mode: AppDisplayMode) {
        applyDisplayMode(mode)
    }

    func handleMainWindowAppear() {
        if shouldHideInitialMainWindow {
            shouldHideInitialMainWindow = false

            DispatchQueue.main.async { [weak self] in
                guard let self = self, self.appDisplayMode == .menuBarOnly else { return }
                if let visibleWindow = NSApp.windows.first(where: \.isVisible) {
                    visibleWindow.orderOut(nil)
                }
            }
            return
        }

        guard !hasExpandedMainWindowOnLaunch else { return }
        hasExpandedMainWindowOnLaunch = true

        DispatchQueue.main.async {
            guard let visibleWindow = NSApp.windows.first(where: \.isVisible) else { return }
            guard let targetFrame = visibleWindow.screen?.visibleFrame ?? NSScreen.main?.visibleFrame else { return }
            visibleWindow.setFrame(targetFrame, display: true, animate: false)
        }
    }

    func openMainWindow(using openWindow: OpenWindowAction) {
        shouldHideInitialMainWindow = false
        openWindow(id: AppWindowID.main)
        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Private Methods

    private func applyDisplayMode(_ mode: AppDisplayMode) {
        if appDisplayMode != mode {
            appDisplayMode = mode
        }
        if isMenuBarIconVisible != mode.showsMenuBarIcon {
            isMenuBarIconVisible = mode.showsMenuBarIcon
        }

        let targetPolicy: NSApplication.ActivationPolicy = mode.showsDockIcon ? .regular : .accessory
        if NSApp.activationPolicy() != targetPolicy {
            NSApp.setActivationPolicy(targetPolicy)
        }
    }

    /// 设置监控和保护引擎的回调
    private func setupCallbacks() {
        // 监控器检测到变化时，触发保护引擎验证所有规则
        monitor.onDetectedChange = { [weak self] in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.requestValidation()
            }
        }

        // 保护引擎恢复成功回调
        protectionEngine.onRecoverySuccess = { [weak self] uti, oldApp, newApp in
            guard let self = self else { return }

            print("✅ 恢复成功: \(uti)")
            print("   旧应用: \(oldApp)")
            print("   新应用: \(newApp)")

            // 获取显示名称
            Task { @MainActor in
                if let rule = ConfigurationManager.shared.getProtectionRules().first(where: { $0.fileType.uti == uti }) {
                    let oldAppInfo = Application.from(bundleID: oldApp)
                    let newAppInfo = Application.from(bundleID: newApp)

                    // 发送成功通知
                    if ConfigurationManager.shared.getPreferences().showNotifications {
                        self.notificationService.send(.associationRestored(
                            fileType: uti,
                            fileTypeName: rule.fileType.displayName,
                            fromApp: oldAppInfo?.name ?? oldApp,
                            toApp: newAppInfo?.name ?? newApp
                        ))
                    }
                }
            }
        }

        // 保护引擎恢复失败回调
        protectionEngine.onRecoveryFailure = { [weak self] uti, error in
            guard let self = self else { return }

            print("❌ 恢复失败: \(uti)")
            print("   错误: \(error.localizedDescription)")

            // 获取显示名称
            Task { @MainActor in
                if let rule = ConfigurationManager.shared.getProtectionRules().first(where: { $0.fileType.uti == uti }) {
                    // 发送失败通知
                    if ConfigurationManager.shared.getPreferences().showNotifications {
                        self.notificationService.send(.recoveryFailed(
                            fileType: uti,
                            fileTypeName: rule.fileType.displayName,
                            error: error.localizedDescription
                        ))
                    }
                }
            }
        }
    }

    /// 把频繁的触发事件合并，避免主线程被连续检查压垮。
    private func requestValidation(immediate: Bool = false) {
        pendingValidationWorkItem?.cancel()

        if immediate {
            runValidationIfNeeded()
            return
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.runValidationIfNeeded()
        }
        pendingValidationWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + validationDebounceInterval, execute: workItem)
    }

    private func runValidationIfNeeded() {
        if isValidationInProgress {
            needsValidationRerun = true
            return
        }

        isValidationInProgress = true
        protectionEngine.validateAllRules()
        isValidationInProgress = false

        if needsValidationRerun {
            needsValidationRerun = false
            requestValidation()
        }
    }
}
