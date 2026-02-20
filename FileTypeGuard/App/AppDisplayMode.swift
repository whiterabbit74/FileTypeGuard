import Foundation

/// Controls where the app should appear in macOS.
enum AppDisplayMode: String, Codable, CaseIterable, Identifiable {
    case dockOnly
    case menuBarOnly
    case dockAndMenuBar

    var id: String { rawValue }

    var showsDockIcon: Bool {
        switch self {
        case .dockOnly, .dockAndMenuBar:
            return true
        case .menuBarOnly:
            return false
        }
    }

    var showsMenuBarIcon: Bool {
        switch self {
        case .menuBarOnly, .dockAndMenuBar:
            return true
        case .dockOnly:
            return false
        }
    }

    var title: String {
        switch self {
        case .dockOnly:
            return "Dock"
        case .menuBarOnly:
            return "Menu Bar"
        case .dockAndMenuBar:
            return "Dock + Menu Bar"
        }
    }
}
