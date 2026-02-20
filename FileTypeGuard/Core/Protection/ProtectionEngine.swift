import Foundation
import AppKit

/// 保护引擎
/// 核心功能：检测文件关联变化并自动恢复
final class ProtectionEngine {

    // MARK: - Properties

    private let configManager = ConfigurationManager.shared
    private let lsManager = LaunchServicesManager.shared
    private let logger = EventLogger.shared
    private var recoveryTasks: [String: DispatchWorkItem] = [:]  // UTI -> 恢复任务
    private var runningValidations: Set<String> = []
    private let queue = DispatchQueue(label: "com.filetypeprotector.protection", qos: .userInitiated)

    /// 最大重试次数
    private let maxRetries = 3

    /// 恢复成功回调
    var onRecoverySuccess: ((String, String, String) -> Void)?  // (uti, oldApp, newApp)

    /// 恢复失败回调
    var onRecoveryFailure: ((String, Error) -> Void)?  // (uti, error)

    // MARK: - Error Types

    enum ProtectionError: Error {
        case ruleNotFound
        case ruleDisabled
        case recoveryFailed(String)
        case maxRetriesExceeded

        var localizedDescription: String {
            switch self {
            case .ruleNotFound:
                return "未找到保护规则"
            case .ruleDisabled:
                return "保护规则已禁用"
            case .recoveryFailed(let message):
                return "恢复失败: \(message)"
            case .maxRetriesExceeded:
                return "已达到最大重试次数"
            }
        }
    }

    // MARK: - Public Methods

    /// 验证并恢复指定 UTI 的文件关联
    /// - Parameter uti: 文件类型的 UTI
    func validateAndRecover(uti: String) {
        queue.async { [weak self] in
            guard let self = self else { return }
            guard !self.runningValidations.contains(uti) else {
                return
            }

            self.runningValidations.insert(uti)
            defer { self.runningValidations.remove(uti) }

            do {
                try self._validateAndRecover(uti: uti)
            } catch {
                print("❌ 验证和恢复失败: \(error)")
                DispatchQueue.main.async {
                    self.onRecoveryFailure?(uti, error)
                }
            }
        }
    }

    /// 验证所有保护规则
    func validateAllRules() {
        let rules = configManager.getProtectionRules()
        print("🔍 开始验证所有保护规则，共 \(rules.count) 个")

        for rule in rules {
            guard rule.isEnabled else {
                continue
            }
            validateAndRecover(uti: rule.fileType.uti)
        }
    }

    /// 取消指定 UTI 的待执行恢复任务
    /// - Parameter uti: 文件类型的 UTI
    func cancelRecovery(uti: String) {
        queue.async { [weak self] in
            self?.recoveryTasks[uti]?.cancel()
            self?.recoveryTasks.removeValue(forKey: uti)
            print("🚫 已取消 \(uti) 的恢复任务")
        }
    }

    // MARK: - Private Methods

    /// 内部验证和恢复方法（在队列中执行）
    private func _validateAndRecover(uti: String) throws {
        // 1. 获取保护规则
        guard let rule = findRule(for: uti) else {
            throw ProtectionError.ruleNotFound
        }

        guard rule.isEnabled else {
            throw ProtectionError.ruleDisabled
        }

        // 2. 读取当前文件关联（主 UTI）
        let currentBundleID = try lsManager.getDefaultApplication(for: uti)
        let expectedBundleID = rule.expectedApplication.bundleID

        // 3. 检查主 UTI 是否需要恢复
        var needsRecovery = (currentBundleID != expectedBundleID)

        // 4. 检查所有动态 UTI 是否也被修改
        if shouldManageDynamicUTIs(for: uti), let ext = rule.fileType.extensions.first {
            let allUTIs = lsManager.findAllUTIs(forExtension: ext)
            for dynUTI in allUTIs {
                if dynUTI == uti { continue }
                let dynApp = try? lsManager.getDefaultApplication(for: dynUTI)
                if dynApp != nil && dynApp != expectedBundleID {
                    print("⚠️  动态 UTI \(dynUTI) 被设置为: \(dynApp ?? "nil")，期望: \(expectedBundleID)")
                    needsRecovery = true
                }
            }
        }

        if !needsRecovery {
            print("✅ \(uti) 的文件关联正常: \(expectedBundleID)")
            return
        }

        print("⚠️  检测到 \(uti) 的文件关联被修改:")
        print("   期望: \(expectedBundleID)")
        print("   当前: \(currentBundleID ?? "nil")")

        // 记录检测事件
        let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
        logger.logDetected(
            fileType: uti,
            fileTypeName: rule.fileType.displayName,
            fromApp: currentBundleID,
            fromAppName: currentApp?.name,
            toApp: expectedBundleID,
            toAppName: rule.expectedApplication.name
        )

        // 5. 根据策略执行恢复
        let preferences = configManager.getPreferences()
        let strategy = preferences.recoveryStrategy

        switch strategy {
        case .immediate:
            try performRecovery(
                uti: uti,
                expectedBundleID: expectedBundleID,
                currentBundleID: currentBundleID,
                preferredExtension: rule.fileType.extensions.first
            )

        case .delayed:
            scheduleDelayedRecovery(
                uti: uti,
                expectedBundleID: expectedBundleID,
                currentBundleID: currentBundleID,
                preferredExtension: rule.fileType.extensions.first,
                delay: strategy.delaySeconds
            )

        case .askUser:
            print("⏸️  询问用户模式暂未实现，跳过恢复")
        }
    }

    /// 执行恢复操作（带重试）
    private func performRecovery(
        uti: String,
        expectedBundleID: String,
        currentBundleID: String?,
        preferredExtension: String?,
        retryCount: Int = 0
    ) throws {
        do {
            // 优先使用规则里记录的扩展名，避免误改其他类型（例如 markdown 的动态 UTI）
            if shouldManageDynamicUTIs(for: uti), let ext = preferredExtension, !ext.isEmpty {
                try lsManager.setDefaultApplicationForExtension(
                    expectedBundleID,
                    extension: ext,
                    primaryUTI: uti
                )
            } else {
                // 回退到仅设置主 UTI
                try lsManager.setDefaultApplication(expectedBundleID, for: uti)
            }

            // 验证是否成功
            let verifiedBundleID = try lsManager.getDefaultApplication(for: uti)

            if verifiedBundleID == expectedBundleID {
                print("✅ 成功恢复 \(uti) 的文件关联: \(expectedBundleID)")

                // 记录恢复成功
                if let rule = findRule(for: uti) {
                    let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
                    logger.logRestored(
                        fileType: uti,
                        fileTypeName: rule.fileType.displayName,
                        fromApp: currentBundleID,
                        fromAppName: currentApp?.name,
                        toApp: expectedBundleID,
                        toAppName: rule.expectedApplication.name
                    )
                }

                DispatchQueue.main.async {
                    self.onRecoverySuccess?(uti, currentBundleID ?? "unknown", expectedBundleID)
                }
            } else {
                throw ProtectionError.recoveryFailed("验证失败，当前值: \(verifiedBundleID ?? "nil")")
            }

        } catch {
            print("❌ 恢复失败 (\(retryCount + 1)/\(maxRetries)): \(error)")

            // 记录恢复失败
            if retryCount == maxRetries - 1, let rule = findRule(for: uti) {
                let currentApp = currentBundleID.flatMap { Application.from(bundleID: $0) }
                logger.logRestoreFailed(
                    fileType: uti,
                    fileTypeName: rule.fileType.displayName,
                    fromApp: currentBundleID,
                    fromAppName: currentApp?.name,
                    toApp: expectedBundleID,
                    toAppName: rule.expectedApplication.name,
                    error: error
                )
            }

            // 重试逻辑
            if retryCount < maxRetries - 1 {
                let retryDelay: TimeInterval = 1.0 * Double(retryCount + 1)  // 递增延迟
                print("⏳ 将在 \(retryDelay) 秒后重试...")

                Thread.sleep(forTimeInterval: retryDelay)
                try performRecovery(
                    uti: uti,
                    expectedBundleID: expectedBundleID,
                    currentBundleID: currentBundleID,
                    preferredExtension: preferredExtension,
                    retryCount: retryCount + 1
                )
            } else {
                throw ProtectionError.maxRetriesExceeded
            }
        }
    }

    /// 计划延迟恢复
    private func scheduleDelayedRecovery(
        uti: String,
        expectedBundleID: String,
        currentBundleID: String?,
        preferredExtension: String?,
        delay: TimeInterval
    ) {
        // 取消现有任务
        recoveryTasks[uti]?.cancel()

        // 创建新任务
        let task = DispatchWorkItem { [weak self] in
            guard let self = self else { return }

            do {
                print("⏰ 延迟恢复任务开始: \(uti)")
                try self.performRecovery(
                    uti: uti,
                    expectedBundleID: expectedBundleID,
                    currentBundleID: currentBundleID,
                    preferredExtension: preferredExtension
                )
            } catch {
                print("❌ 延迟恢复失败: \(error)")
                DispatchQueue.main.async {
                    self.onRecoveryFailure?(uti, error)
                }
            }

            // 清理任务
            self.recoveryTasks.removeValue(forKey: uti)
        }

        recoveryTasks[uti] = task
        queue.asyncAfter(deadline: .now() + delay, execute: task)

        print("⏳ 已计划在 \(delay) 秒后恢复 \(uti)")
    }

    /// 查找指定 UTI 的保护规则
    private func findRule(for uti: String) -> ProtectionRule? {
        let rules = configManager.getProtectionRules()
        return rules.first { $0.fileType.uti == uti }
    }

    /// 仅对特定 UTI 做动态 UTI 管理，避免对 public.* 通用类型产生冲突循环
    private func shouldManageDynamicUTIs(for uti: String) -> Bool {
        !uti.hasPrefix("public.")
    }

    // MARK: - Smart Strategy Selection

    /// 智能选择恢复策略（基于上下文）
    func selectStrategy(for uti: String) -> RecoveryStrategy {
        // 检测前台应用
        if let frontApp = NSWorkspace.shared.frontmostApplication,
           let bundleID = frontApp.bundleIdentifier {

            // 如果是系统设置，可能是用户手动修改，使用延迟策略
            if bundleID == "com.apple.systempreferences" || bundleID == "com.apple.Settings" {
                print("🤔 检测到系统设置在前台，使用延迟恢复策略")
                return .delayed
            }
        }

        // 默认使用配置的策略
        return configManager.getPreferences().recoveryStrategy
    }
}
