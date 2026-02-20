import Foundation
import AppKit

/// 文件关联监控器
/// 整合多种监控机制：文件监控、轮询监控、应用激活触发
final class FileAssociationMonitor {

    // MARK: - Properties

    private let databaseWatcher = LaunchServicesDatabaseWatcher()
    private let pollingMonitor: PollingMonitor
    private var isMonitoring = false

    /// 检测到变化的回调
    var onDetectedChange: (() -> Void)?

    // MARK: - Initialization

    init(pollingInterval: TimeInterval = 30.0) {
        self.pollingMonitor = PollingMonitor(interval: pollingInterval)
        setupCallbacks()
        setupApplicationObserver()
    }

    // MARK: - Public Methods

    /// 开始监控
    func startMonitoring() {
        guard !isMonitoring else {
            print("⚠️  监控已在运行中")
            return
        }

        print("🚀 启动文件关联监控...")

        // 1. 启动时立即检查一次
        checkNow()

        // 2. 启动文件监控
        databaseWatcher.startWatching()

        // 3. 启动轮询监控
        pollingMonitor.startPolling()

        isMonitoring = true
        print("✅ 文件关联监控已全部启动")
    }

    /// 停止监控
    func stopMonitoring() {
        guard isMonitoring else { return }

        databaseWatcher.stopWatching()
        pollingMonitor.stopPolling()

        isMonitoring = false
        print("✅ 文件关联监控已全部停止")
    }

    /// 立即执行检查
    func checkNow() {
        onDetectedChange?()
    }

    // MARK: - Private Methods

    /// 设置各监控器的回调
    private func setupCallbacks() {
        // 文件监控回调
        databaseWatcher.onChange = { [weak self] in
            guard let self = self else { return }
            print("📝 文件监控检测到变化")
            self.onDetectedChange?()
        }

        // 轮询监控回调
        pollingMonitor.onCheck = { [weak self] in
            guard let self = self else { return }
            self.onDetectedChange?()
        }
    }

    /// 设置应用激活监听
    private func setupApplicationObserver() {
        // 监听新应用启动（安装后首次启动常常会修改文件关联）
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didLaunchApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let self = self, self.isMonitoring else { return }

            if let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication {
                print("🚀 新应用启动: \(app.localizedName ?? "Unknown")")
                // 延迟检查，给应用注册文件关联的时间
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                    self.onDetectedChange?()
                }
            }
        }
    }
}
