import SwiftUI

/// 应用选择器组件
/// 显示本机所有已安装应用，推荐应用（能打开该文件类型的）排在前面
struct ApplicationPicker: View {

    // MARK: - Properties

    let fileType: FileType?
    @Binding var selectedApplication: Application?

    // MARK: - State

    @State private var recommendedApps: [Application] = []
    @State private var otherApps: [Application] = []
    @State private var isLoading = false
    @State private var searchText = ""
    @State private var loadedUTI: String = ""
    @State private var hasLoadedAtLeastOnce = false
    @State private var sortMode: ApplicationSortMode = .recentlyUpdated
    @State private var appModifiedDates: [String: Date] = [:]

    // MARK: - Body

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // 搜索栏
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField(String(localized: "search_app"), text: $searchText)
                    .textFieldStyle(.roundedBorder)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            HStack {
                Text(String(localized: "sort_by"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Picker(String(localized: "sort_by"), selection: $sortMode) {
                    ForEach(ApplicationSortMode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer()
            }

            // 应用列表
            if isLoading {
                loadingView
            } else if sortedRecommended.isEmpty && sortedOther.isEmpty {
                emptyView
            } else {
                applicationList
            }
        }
        .onAppear {
            loadIfNeeded()
        }
        .onChange(of: fileType?.uti) { _ in
            loadIfNeeded()
        }
    }

    // MARK: - Load Guard

    /// 只在 UTI 真正变化时才重新加载
    private func loadIfNeeded() {
        let currentUTI = fileType?.uti ?? ""
        guard !hasLoadedAtLeastOnce || currentUTI != loadedUTI else { return }
        hasLoadedAtLeastOnce = true
        loadedUTI = currentUTI
        loadAllApplications()
    }

    // MARK: - Application List

    private var applicationList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                // 推荐应用分组
                if !sortedRecommended.isEmpty {
                    sectionHeader(String(localized: "recommended_apps"), subtitle: String(localized: "can_open_this_type"))

                    ForEach(sortedRecommended) { app in
                        appRow(app, isRecommended: true)
                    }
                }

                // 其他应用分组
                if !sortedOther.isEmpty {
                    sectionHeader(String(localized: "other_apps"), subtitle: String(localized: "all_installed_apps"))

                    ForEach(sortedOther) { app in
                        appRow(app, isRecommended: false)
                    }
                }
            }
        }
        .frame(maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
    }

    // MARK: - Section Header

    private func sectionHeader(_ title: String, subtitle: String) -> some View {
        HStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text("·")
                .foregroundStyle(.tertiary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 12)
        .padding(.bottom, 4)
    }

    // MARK: - App Row

    private func appRow(_ app: Application, isRecommended: Bool) -> some View {
        let isSelected = selectedApplication?.id == app.id

        return HStack(spacing: 12) {
            // 应用图标
            if let icon = app.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                Image(systemName: "app.fill")
                    .font(.title2)
                    .foregroundStyle(.blue)
                    .frame(width: 28, height: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(app.name)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .regular)

                    if isRecommended {
                        Text("recommended")
                            .font(.system(size: 9))
                            .padding(.horizontal, 4)
                            .padding(.vertical, 1)
                            .background(Color.green.opacity(0.15))
                            .foregroundStyle(.green)
                            .cornerRadius(3)
                    }
                }

                Text(app.bundleID)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.blue)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedApplication = app
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("loading_app_list")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Empty View

    private var emptyView: some View {
        VStack(spacing: 8) {
            Image(systemName: "app.dashed")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text("no_apps_found")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }

    // MARK: - Filtered

    private var sortedRecommended: [Application] {
        sortApps(filterApps(recommendedApps))
    }

    private var sortedOther: [Application] {
        sortApps(filterApps(otherApps))
    }

    private func filterApps(_ apps: [Application]) -> [Application] {
        guard !searchText.isEmpty else { return apps }
        return apps.filter { app in
            app.name.localizedCaseInsensitiveContains(searchText) ||
            app.bundleID.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func sortApps(_ apps: [Application]) -> [Application] {
        switch sortMode {
        case .recommended, .nameAscending:
            return apps.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedAscending
            }
        case .nameDescending:
            return apps.sorted { lhs, rhs in
                lhs.name.localizedCaseInsensitiveCompare(rhs.name) == .orderedDescending
            }
        case .recentlyUpdated:
            return apps.sorted { lhs, rhs in
                modifiedDate(for: lhs) > modifiedDate(for: rhs)
            }
        case .oldestUpdated:
            return apps.sorted { lhs, rhs in
                modifiedDate(for: lhs) < modifiedDate(for: rhs)
            }
        }
    }

    private func modifiedDate(for app: Application) -> Date {
        appModifiedDates[app.bundleID] ?? .distantPast
    }

    // MARK: - Load

    private func loadAllApplications() {
        isLoading = true

        Task {
            let lsm = LaunchServicesManager.shared

            // 获取推荐应用（能打开此文件类型的）
            var recommendedBundleIDs = Set<String>()
            if let ft = fileType {
                recommendedBundleIDs = Set(lsm.getAvailableApplications(for: ft.uti))
            }

            // 获取所有已安装应用
            let allBundleIDs = lsm.getAllInstalledApplications()

            var recommended: [Application] = []
            var other: [Application] = []

            for bundleID in allBundleIDs {
                guard let app = Application.from(bundleID: bundleID) else { continue }
                appModifiedDates[bundleID] = applicationModifiedDate(at: app.pathURL)

                if recommendedBundleIDs.contains(bundleID) {
                    recommended.append(app)
                } else {
                    other.append(app)
                }
            }

            // 把不在 allBundleIDs 中但在推荐列表中的也加上
            let allBundleIDSet = Set(allBundleIDs)
            for bundleID in recommendedBundleIDs {
                if !allBundleIDSet.contains(bundleID) {
                    if let app = Application.from(bundleID: bundleID) {
                        appModifiedDates[bundleID] = applicationModifiedDate(at: app.pathURL)
                        recommended.append(app)
                    }
                }
            }

            recommended.sort()
            other.sort()

            await MainActor.run {
                recommendedApps = recommended
                otherApps = other
                isLoading = false

                // 只在没有选中应用时，自动选中当前默认应用
                if selectedApplication == nil,
                   let ft = fileType,
                   let defaultBundleID = try? lsm.getDefaultApplication(for: ft.uti) {
                    let all = recommended + other
                    if let defaultApp = all.first(where: { $0.bundleID == defaultBundleID }) {
                        selectedApplication = defaultApp
                    }
                }

                print("✅ 加载了 \(recommended.count) 个推荐应用, \(other.count) 个其他应用")
            }
        }
    }

    private func applicationModifiedDate(at url: URL) -> Date {
        guard let values = try? url.resourceValues(forKeys: [.contentModificationDateKey]),
              let date = values.contentModificationDate else {
            return .distantPast
        }
        return date
    }
}

private enum ApplicationSortMode: String, CaseIterable, Identifiable {
    case recommended
    case nameAscending
    case nameDescending
    case recentlyUpdated
    case oldestUpdated

    var id: String { rawValue }

    var title: String {
        switch self {
        case .recommended:
            return String(localized: "sort_recommended")
        case .nameAscending:
            return String(localized: "sort_name_asc")
        case .nameDescending:
            return String(localized: "sort_name_desc")
        case .recentlyUpdated:
            return String(localized: "sort_recently_updated")
        case .oldestUpdated:
            return String(localized: "sort_oldest_updated")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack {
        ApplicationPicker(
            fileType: FileType(
                uti: "com.adobe.pdf",
                extensions: [".pdf"],
                displayName: "PDF Document"
            ),
            selectedApplication: .constant(nil)
        )
    }
    .padding()
    .frame(width: 500, height: 600)
}
