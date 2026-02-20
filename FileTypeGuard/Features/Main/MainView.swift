import SwiftUI

/// 主窗口视图
struct MainView: View {

    // MARK: - State

    @State private var selectedTab: NavigationTab = .list
    @State private var protectedTypesDisplayMode: ProtectedTypesDisplayMode = .mindMap
    @State private var themeMode: ThemeMode = .system
    @State private var refreshTrigger = 0

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            detailView
        }
        .preferredColorScheme(themeMode.colorScheme)
        .background(Color(nsColor: .controlBackgroundColor))
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 10) {
            modeButton(.mindMap, icon: "point.3.connected.trianglepath.dotted", help: "Mind map")
            modeButton(.list, icon: "list.bullet", help: "List")
            Spacer()
                .frame(width: 14)

            toolbarIconButton(
                systemImage: "plus",
                isActive: selectedTab == .add,
                help: String(localized: "add_protection_type")
            ) {
                selectedTab = .add
            }
            toolbarIconButton(
                systemImage: "list.bullet.rectangle.portrait",
                isActive: selectedTab == .logs,
                help: String(localized: "logs")
            ) {
                selectedTab = .logs
            }
            toolbarIconButton(
                systemImage: "arrow.clockwise",
                isActive: false,
                help: String(localized: "refresh_list")
            ) {
                selectedTab = .list
                refreshTrigger &+= 1
            }

            Spacer()

            toolbarIconButton(
                systemImage: themeMode.icon,
                isActive: false,
                help: themeMode.helpText
            ) {
                themeMode = themeMode.next
            }
            toolbarIconButton(
                systemImage: "gearshape",
                isActive: selectedTab == .settings,
                help: String(localized: "settings")
            ) {
                selectedTab = .settings
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Color(nsColor: .windowBackgroundColor)
                .overlay(
                    Rectangle()
                        .fill(Color(nsColor: .separatorColor).opacity(0.35))
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    private func modeButton(_ mode: ProtectedTypesDisplayMode, icon: String, help: String) -> some View {
        let isActive = selectedTab == .list && protectedTypesDisplayMode == mode

        return Button {
            selectedTab = .list
            protectedTypesDisplayMode = mode
        } label: {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 42, height: 34)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private func toolbarIconButton(
        systemImage: String,
        isActive: Bool,
        help: String,
        action: @escaping () -> Void
    ) -> some View {
        return Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .frame(width: 42, height: 34)
                .foregroundStyle(isActive ? Color.accentColor : Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isActive ? Color.accentColor.opacity(0.18) : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .help(help)
    }

    // MARK: - Detail View

    @ViewBuilder
    private var detailView: some View {
        switch selectedTab {
        case .list:
            ProtectedTypesView(
                displayMode: $protectedTypesDisplayMode,
                onOpenAddPage: {
                    selectedTab = .add
                },
                refreshTrigger: refreshTrigger
            )
        case .add:
            FileTypePickerView(
                isPresented: .constant(true),
                embeddedMode: true
            ) {
                selectedTab = .list
            }
        case .logs:
            LogsView()
        case .settings:
            SettingsView()
        }
    }
}

// MARK: - Navigation Tab

enum NavigationTab: String, CaseIterable {
    case list
    case add
    case logs
    case settings

    var title: String {
        switch self {
        case .list:
            return String(localized: "protected_types")
        case .add:
            return String(localized: "add_protection_type")
        case .logs:
            return String(localized: "logs")
        case .settings:
            return String(localized: "settings")
        }
    }
}

enum ThemeMode: String, CaseIterable {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var icon: String {
        switch self {
        case .system:
            return "circle.lefthalf.filled"
        case .light:
            return "sun.max"
        case .dark:
            return "moon"
        }
    }

    var helpText: String {
        switch self {
        case .system:
            return "Theme: System"
        case .light:
            return "Theme: Light"
        case .dark:
            return "Theme: Dark"
        }
    }

    var next: ThemeMode {
        switch self {
        case .system:
            return .light
        case .light:
            return .dark
        case .dark:
            return .system
        }
    }
}

// MARK: - Preview

#Preview {
    MainView()
        .environmentObject(AppCoordinator())
        .frame(width: 900, height: 600)
}
