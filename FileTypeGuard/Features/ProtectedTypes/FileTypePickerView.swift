import SwiftUI

/// App-first file type picker:
/// select app on the left, then select file type on the right.
struct FileTypePickerView: View {

    // MARK: - Binding

    @Binding var isPresented: Bool
    let embeddedMode: Bool
    let onCompleted: (() -> Void)?

    // MARK: - State

    @State private var selectedCategory: CommonFileTypes.Category = .documents
    @State private var selectedPresetUTIs: Set<String> = []
    @State private var selectedApplication: Application?
    @State private var formatSearchText = ""
    @State private var showingError = false
    @State private var errorMessage = ""
    @FocusState private var isSearchFieldFocused: Bool

    private let typesByCategory = CommonFileTypes.typesByCategory()

    init(
        isPresented: Binding<Bool>,
        embeddedMode: Bool = false,
        onCompleted: (() -> Void)? = nil
    ) {
        self._isPresented = isPresented
        self.embeddedMode = embeddedMode
        self.onCompleted = onCompleted
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            header

            Divider()

            HSplitView {
                leftPanel
                rightPanel
            }

            Divider()
            connectionPreviewSection

            Divider()

            footer
        }
        .frame(
            minWidth: embeddedMode ? 900 : 1040,
            idealWidth: embeddedMode ? 1000 : 1040,
            maxWidth: .infinity,
            minHeight: embeddedMode ? 600 : 680,
            idealHeight: embeddedMode ? 680 : 680,
            maxHeight: .infinity,
            alignment: .topLeading
        )
        .alert(String(localized: "error"), isPresented: $showingError) {
            Button(String(localized: "ok"), role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Text(String(localized: "add_protection_type"))
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            if !embeddedMode {
                Button {
                    isPresented = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
    }

    // MARK: - Left Panel

    private var leftPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "default_app"))
                .font(.title3)
                .fontWeight(.semibold)

            ApplicationPicker(
                fileType: nil,
                selectedApplication: $selectedApplication
            )
        }
        .padding()
        .frame(minWidth: 250, idealWidth: 300, maxWidth: 340, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Right Panel

    private var rightPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "file_type"))
                .font(.title3)
                .fontWeight(.semibold)

            categoryTabs
            selectionActionsRow
            formatSearchRow
            fileTypeGrid

            Spacer(minLength: 0)
        }
        .padding()
        .layoutPriority(1)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - App Selection

    private func selectedAppInfo(_ app: Application) -> some View {
        HStack(spacing: 10) {
            if let icon = app.getIcon() {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .cornerRadius(6)
            } else {
                Image(systemName: "app.fill")
                    .foregroundStyle(.blue)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(app.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)

                Text(app.bundleID)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(10)
        .background(Color.blue.opacity(0.07))
        .cornerRadius(8)
    }

    // MARK: - Connection Preview

    private var connectionPreviewSection: some View {
        let ready = selectedApplication != nil && !selectedFileTypes.isEmpty
        let lineColor: Color = ready ? .accentColor : .secondary.opacity(0.45)

        return VStack(alignment: .leading, spacing: 10) {
            Text("Connection Preview")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 14) {
                appPreviewCard
                    .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)

                VStack(spacing: 6) {
                    HStack(spacing: 8) {
                        Capsule()
                            .fill(lineColor.opacity(0.55))
                            .frame(width: 34, height: 2)
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.title3)
                            .foregroundStyle(lineColor)
                        Capsule()
                            .fill(lineColor.opacity(0.55))
                            .frame(width: 34, height: 2)
                    }

                    Text(ready ? "Link will be created" : "Select app and formats")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 170)

                formatPreviewCard
                    .frame(maxWidth: .infinity, minHeight: 108, alignment: .topLeading)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var appPreviewCard: some View {
        Group {
            if let app = selectedApplication {
                selectedAppInfo(app)
            } else {
                HStack(spacing: 10) {
                    Image(systemName: "app.fill")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "search_app"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .cornerRadius(8)
            }
        }
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    private var formatPreviewCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if selectedFileTypes.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "doc.badge.plus")
                        .foregroundStyle(.secondary)
                    Text(String(localized: "picker_select_format_hint"))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("\(String(localized: "picker_selected_formats")) (\(selectedFileTypes.count))")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(selectedFileTypes, id: \.uti) { fileType in
                            Text(fileType.extensions.joined(separator: ", "))
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 5)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(6)
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.07))
        .cornerRadius(8)
        .padding(8)
        .background(Color.blue.opacity(0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.blue.opacity(0.18), lineWidth: 1)
        )
        .cornerRadius(10)
    }

    // MARK: - Category Tabs

    private var categoryTabs: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(CommonFileTypes.Category.allCases) { category in
                    Button {
                        selectedCategory = category
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: category.icon)
                            Text(category.displayName)
                        }
                        .font(.subheadline)
                        .fontWeight(selectedCategory == category ? .semibold : .regular)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(selectedCategory == category ? Color.accentColor : Color.clear)
                        .foregroundStyle(selectedCategory == category ? .white : .primary)
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var selectionActionsRow: some View {
        HStack {
            Button(String(localized: "picker_select_all_in_category")) {
                for preset in (typesByCategory[selectedCategory] ?? []) {
                    selectedPresetUTIs.insert(preset.uti)
                }
            }
            .buttonStyle(.link)
            .help(String(localized: "picker_select_all_in_category"))

            Button(String(localized: "picker_clear_selected")) {
                selectedPresetUTIs.removeAll()
                formatSearchText = ""
            }
            .buttonStyle(.link)
            .help(String(localized: "picker_clear_selected"))

            Spacer()

            if !selectedFileTypes.isEmpty {
                Text("\(String(localized: "picker_selected")): \(selectedFileTypes.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Format Search

    private var formatSearchRow: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)

            TextField(String(localized: "picker_search_or_extension"), text: $formatSearchText)
                .textFieldStyle(.roundedBorder)
                .focused($isSearchFieldFocused)

            if !formatSearchText.isEmpty {
                Button {
                    formatSearchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - File Type Grid

    private var fileTypeGrid: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 185), spacing: 10)
            ], spacing: 10) {
                ForEach(filteredPresetTypes) { presetType in
                    FileTypeCard(
                        presetType: presetType,
                        isSelected: selectedPresetUTIs.contains(presetType.uti)
                    )
                    .onTapGesture {
                        if selectedPresetUTIs.contains(presetType.uti) {
                            selectedPresetUTIs.remove(presetType.uti)
                        } else {
                            selectedPresetUTIs.insert(presetType.uti)
                        }
                    }
                }
            }
            .padding(.vertical, 4)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Footer

    private var footer: some View {
        HStack {
            if selectedApplication == nil || selectedFileTypes.isEmpty {
                Text(String(localized: "picker_footer_steps"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if !embeddedMode {
                Button(String(localized: "cancel")) {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)
            }

            Button(addButtonTitle) {
                addProtectionRules()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .disabled(!canAddRule)
        }
        .padding()
    }

    // MARK: - Computed

    private var filteredPresetTypes: [CommonFileTypes.PresetFileType] {
        let source = typesByCategory[selectedCategory] ?? []
        let query = formatSearchText.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !query.isEmpty else { return source }

        return CommonFileTypes.allTypes.filter { preset in
            preset.displayName.localizedCaseInsensitiveContains(query) ||
            preset.uti.localizedCaseInsensitiveContains(query) ||
            preset.extensions.contains(where: { $0.localizedCaseInsensitiveContains(query) })
        }
    }

    private var parsedSearchExtension: String? {
        let trimmed = formatSearchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return nil }
        guard !trimmed.contains(" ") else { return nil }
        let normalized = trimmed.hasPrefix(".") ? trimmed : ".\(trimmed)"
        let pattern = "^\\.[a-z0-9][a-z0-9_+\\-]{0,15}$"
        guard normalized.range(of: pattern, options: .regularExpression) != nil else { return nil }
        return normalized
    }

    private var selectedFileTypes: [FileType] {
        var result = CommonFileTypes.allTypes
            .filter { selectedPresetUTIs.contains($0.uti) }
            .map { $0.toFileType() }

        if let ext = parsedSearchExtension,
           let customType = FileType.from(extension: ext) {
            result.append(customType)
        }

        var seen = Set<String>()
        return result.filter { seen.insert($0.uti).inserted }
    }

    private var canAddRule: Bool {
        !selectedFileTypes.isEmpty && selectedApplication != nil
    }

    private var addButtonTitle: String {
        let count = selectedFileTypes.count
        if count <= 1 {
            return String(localized: "add_protection")
        }
        return "\(String(localized: "add_protection")) (\(count))"
    }

    // MARK: - Actions

    private func addProtectionRules() {
        guard let app = selectedApplication else {
            return
        }

        let fileTypes = selectedFileTypes
        guard !fileTypes.isEmpty else { return }

        var failures: [String] = []

        for fileType in fileTypes {
            let rule = ProtectionRule(
                fileType: fileType,
                expectedApplication: app
            )

            do {
                try ConfigurationManager.shared.addProtectionRule(rule)

                if let ext = fileType.extensions.first {
                    try LaunchServicesManager.shared.setDefaultApplicationForExtension(
                        app.bundleID,
                        extension: ext,
                        primaryUTI: fileType.uti
                    )
                } else {
                    try LaunchServicesManager.shared.setDefaultApplication(app.bundleID, for: fileType.uti)
                }
            } catch {
                failures.append("\(fileType.extensions.first ?? fileType.uti): \(error.localizedDescription)")
            }
        }

        if failures.isEmpty {
            if embeddedMode {
                onCompleted?()
            } else {
                isPresented = false
            }
            return
        }

        errorMessage = "\(String(localized: "picker_failed_partial"))\n" + failures.joined(separator: "\n")
        showingError = true
    }
}

// MARK: - File Type Card

struct FileTypeCard: View {
    let presetType: CommonFileTypes.PresetFileType
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: presetType.icon)
                .font(.title)
                .foregroundStyle(isSelected ? .white : .blue)

            Text(presetType.displayName)
                .font(.subheadline)
                .fontWeight(isSelected ? .semibold : .regular)
                .foregroundStyle(isSelected ? .white : .primary)
                .multilineTextAlignment(.center)

            Text(presetType.extensions.joined(separator: ", "))
                .font(.caption2)
                .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 82, maxHeight: 82)
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(isSelected ? Color.accentColor : Color(nsColor: .controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.clear : Color.gray.opacity(0.2), lineWidth: 1)
        )
    }
}

// MARK: - Preview

#Preview {
    FileTypePickerView(isPresented: .constant(true))
}
