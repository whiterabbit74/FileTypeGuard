import Foundation
import AppKit

/// 应用信息解析器
/// 负责根据 Bundle ID 获取应用的详细信息
final class ApplicationResolver {

    // MARK: - Singleton

    static let shared = ApplicationResolver()
    private init() {}
    private let iconCache = NSCache<NSString, NSImage>()

    // MARK: - Error Types

    enum ResolverError: Error {
        case applicationNotFound
        case invalidBundleID
        case bundleLoadFailed

        var localizedDescription: String {
            switch self {
            case .applicationNotFound:
                return "未找到应用"
            case .invalidBundleID:
                return "无效的 Bundle ID"
            case .bundleLoadFailed:
                return "无法加载应用信息"
            }
        }
    }

    // MARK: - Application Info

    /// 应用信息结构
    struct ApplicationInfo {
        let bundleID: String
        let name: String
        let path: URL
        let version: String?
        let icon: NSImage?

        var displayName: String {
            return name
        }
    }

    // MARK: - Public Methods

    /// 根据 Bundle ID 解析应用信息
    /// - Parameter bundleID: 应用的 Bundle ID
    /// - Returns: 应用信息，如果应用不存在则返回 nil
    func resolveApplication(bundleID: String) -> ApplicationInfo? {
        guard !bundleID.isEmpty else {
            return nil
        }

        // 使用 NSWorkspace 查找应用路径
        guard let appURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) else {
            return nil
        }

        // 获取应用名称
        let appName = getApplicationName(at: appURL, bundleID: bundleID)

        // 获取版本号
        let version = getApplicationVersion(at: appURL)

        // 获取图标
        let icon = getApplicationIcon(at: appURL)

        return ApplicationInfo(
            bundleID: bundleID,
            name: appName,
            path: appURL,
            version: version,
            icon: icon
        )
    }

    /// 批量解析多个应用信息
    /// - Parameter bundleIDs: Bundle ID 数组
    /// - Returns: 应用信息数组（过滤掉不存在的应用）
    func resolveApplications(bundleIDs: [String]) -> [ApplicationInfo] {
        return bundleIDs.compactMap { resolveApplication(bundleID: $0) }
    }

    /// 检查应用是否已安装
    /// - Parameter bundleID: 应用的 Bundle ID
    /// - Returns: 是否已安装
    func isApplicationInstalled(bundleID: String) -> Bool {
        guard !bundleID.isEmpty else {
            return false
        }

        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) != nil
    }

    /// 获取应用路径
    /// - Parameter bundleID: 应用的 Bundle ID
    /// - Returns: 应用路径 URL
    func getApplicationPath(bundleID: String) -> URL? {
        guard !bundleID.isEmpty else {
            return nil
        }

        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
    }

    /// 获取应用图标
    /// - Parameter bundleID: 应用的 Bundle ID
    /// - Returns: 应用图标
    func getApplicationIcon(bundleID: String) -> NSImage? {
        guard !bundleID.isEmpty else {
            return nil
        }

        if let cached = iconCache.object(forKey: bundleID as NSString) {
            return cached
        }

        guard let appURL = getApplicationPath(bundleID: bundleID),
              let icon = getApplicationIcon(at: appURL) else {
            return nil
        }

        iconCache.setObject(icon, forKey: bundleID as NSString)
        return icon
    }

    // MARK: - Private Helper Methods

    /// 从应用路径获取应用名称
    private func getApplicationName(at url: URL, bundleID: String) -> String {
        // 尝试从 Bundle 获取显示名称
        if let bundle = Bundle(url: url),
           let displayName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String,
           !displayName.isEmpty {
            return displayName
        }

        // 尝试从 Bundle 获取名称
        if let bundle = Bundle(url: url),
           let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String,
           !name.isEmpty {
            return name
        }

        // 使用文件名（去掉 .app 后缀）
        let fileName = url.deletingPathExtension().lastPathComponent
        if !fileName.isEmpty {
            return fileName
        }

        // 最后使用 Bundle ID
        return bundleID
    }

    /// 从应用路径获取版本号
    private func getApplicationVersion(at url: URL) -> String? {
        guard let bundle = Bundle(url: url) else {
            return nil
        }

        // 尝试获取短版本号
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
            return version
        }

        // 尝试获取完整版本号
        if let version = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
            return version
        }

        return nil
    }

    /// 从应用路径获取图标
    private func getApplicationIcon(at url: URL) -> NSImage? {
        return NSWorkspace.shared.icon(forFile: url.path)
    }

    /// 获取应用的本地化名称
    /// - Parameter bundleID: 应用的 Bundle ID
    /// - Returns: 本地化名称
    func getLocalizedName(bundleID: String) -> String? {
        guard let appURL = getApplicationPath(bundleID: bundleID),
              let bundle = Bundle(url: appURL) else {
            return nil
        }

        return bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String
            ?? bundle.localizedInfoDictionary?["CFBundleName"] as? String
    }
}

// MARK: - Convenience Extensions

extension ApplicationResolver.ApplicationInfo {

    /// 应用的完整描述
    var fullDescription: String {
        var desc = name
        if let version = version {
            desc += " (\(version))"
        }
        desc += " - \(bundleID)"
        return desc
    }

    /// 应用路径的字符串表示
    var pathString: String {
        return path.path
    }
}

// MARK: - Equatable & Hashable

extension ApplicationResolver.ApplicationInfo: Equatable, Hashable {

    static func == (lhs: ApplicationResolver.ApplicationInfo, rhs: ApplicationResolver.ApplicationInfo) -> Bool {
        return lhs.bundleID == rhs.bundleID
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(bundleID)
    }
}

// MARK: - CustomStringConvertible

extension ApplicationResolver.ApplicationInfo: CustomStringConvertible {

    var description: String {
        return "\(name) (\(bundleID))"
    }
}
