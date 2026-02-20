import AppKit
import SwiftUI

/// Protection types screen.
/// Default mode is a mind-map style canvas; users can switch to a classic list.
struct ProtectedTypesView: View {
    @Binding var displayMode: ProtectedTypesDisplayMode
    var onOpenAddPage: (() -> Void)?
    var refreshTrigger: Int

    @StateObject private var viewModel = ProtectedTypesViewModel()
    @StateObject private var pointerTracker = ZoomPointerTracker()
    @State private var selectedRule: ProtectionRule?
    @State private var zoomScale: CGFloat = 1.0
    @State private var cameraCenter: CGPoint = .zero
    @State private var canvasDragStartCenter: CGPoint = .zero
    @State private var zoomGestureStartScale: CGFloat = 1.0
    @State private var isCanvasDragInFlight = false
    @State private var isZoomGestureInFlight = false
    @State private var hasConfiguredViewport = false
    @State private var hasRestoredPersistedNodePositions = false
    @State private var isCenterControlsVisible = false
    @State private var isAddFromMapSheetPresented = false
    @State private var preferredSideForNextAddedApp: MindMapSide?
    @State private var appNodeIDsBeforeAddFromMap: Set<String> = []
    @State private var knownAppNodeIDs: Set<String> = []
    @State private var nodeOverrides: [String: CGPoint] = [:]
    @State private var dragStartPositions: [String: CGPoint] = [:]
    @State private var isNodeDragInFlight = false

    private let minZoom: CGFloat = 0.45
    private let maxZoom: CGFloat = 2.6

    init(
        displayMode: Binding<ProtectedTypesDisplayMode> = .constant(.mindMap),
        onOpenAddPage: (() -> Void)? = nil,
        refreshTrigger: Int = 0
    ) {
        self._displayMode = displayMode
        self.onOpenAddPage = onOpenAddPage
        self.refreshTrigger = refreshTrigger
    }

    var body: some View {
        Group {
            if viewModel.protectionRules.isEmpty {
                emptyState
            } else {
                contentView
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .controlBackgroundColor))
        .onAppear {
            viewModel.loadRules()
        }
        .onChange(of: refreshTrigger) { _ in
            viewModel.loadRules()
        }
        .sheet(isPresented: $isAddFromMapSheetPresented, onDismiss: {
            viewModel.loadRules()
            let currentAppIDs = Set(appGroups.map { "app-\($0.app.bundleID)" })
            if currentAppIDs == appNodeIDsBeforeAddFromMap {
                preferredSideForNextAddedApp = nil
            }
        }) {
            FileTypePickerView(isPresented: $isAddFromMapSheetPresented)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
            persistNodeOverrides()
        }
    }

    @ViewBuilder
    private var contentView: some View {
        switch displayMode {
        case .mindMap:
            mindMapView
        case .list:
            rulesList
        }
    }

    private var rulesList: some View {
        List {
            ForEach(appGroups, id: \.app.bundleID) { group in
                appBindingRow(group)
                    .contextMenu {
                        appGroupContextMenu(for: group.rules)
                    }
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12))
                    .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    private func appBindingRow(_ group: AppGroup) -> some View {
        let extensions = normalizedExtensions(for: group.rules)
        let isDisabled = !group.rules.contains(where: { $0.isEnabled })
        let extensionsText = extensions.joined(separator: ", ")

        return HStack(alignment: .top, spacing: 12) {
            appCardIcon(for: group.app)
                .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 7) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(group.app.name)
                        .font(.system(size: 15, weight: .semibold))
                        .lineLimit(1)

                    if isDisabled {
                        Text(String(localized: "disabled"))
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule()
                                    .fill(Color.secondary.opacity(0.12))
                            )
                    }
                }

                Text(extensionsText)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(nsColor: .windowBackgroundColor).opacity(0.98))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    isDisabled ? Color.secondary.opacity(0.38) : Color.blue.opacity(0.20),
                    style: StrokeStyle(lineWidth: 1, dash: isDisabled ? [5, 4] : [])
                )
        )
        .shadow(color: Color.black.opacity(0.05), radius: 4, y: 1)
    }

    @ViewBuilder
    private func appCardIcon(for app: Application) -> some View {
        if let icon = app.getIcon() {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.42), lineWidth: 0.9)
                )
                .shadow(color: Color.black.opacity(0.15), radius: 5, y: 2)
        } else {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.blue.opacity(0.14))
                Image(systemName: "app.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.blue)
            }
        }
    }

    private func normalizedExtensions(for rules: [ProtectionRule]) -> [String] {
        let values = rules
            .flatMap(\.fileType.extensions)
            .compactMap { raw -> String? in
                let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { return nil }
                return trimmed.hasPrefix(".") ? trimmed.lowercased() : ".\(trimmed.lowercased())"
            }

        return Array(Set(values))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private var mindMapView: some View {
        GeometryReader { proxy in
            let groups = appGroups
            let layout = buildLayout(for: groups)
            let viewport = proxy.size
            let displayScale = zoomScale
            let displayCameraCenter = currentCameraCenter(for: layout)
            let transformOffset = viewportTransformOffset(
                viewport: viewport,
                cameraCenter: displayCameraCenter,
                zoom: displayScale
            )

            ZStack(alignment: .center) {
                mapBackground(canvas: layout.canvas)

                mindMapCanvas(layout: layout)
                    .frame(width: layout.canvas.width, height: layout.canvas.height, alignment: .topLeading)
            }
            .frame(width: layout.canvas.width, height: layout.canvas.height, alignment: .topLeading)
            .scaleEffect(displayScale, anchor: .topLeading)
            .offset(transformOffset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .contentShape(Rectangle())
            .gesture(canvasPanGesture(layout: layout, viewport: viewport))
            .simultaneousGesture(canvasZoomGesture(layout: layout, viewport: viewport))
            .onContinuousHover(coordinateSpace: .local) { phase in
                if case .active(let location) = phase {
                    pointerTracker.location = location
                }
            }
            .background(
                ScrollWheelPanCaptureView { translation in
                    handleScrollPan(
                        translation: translation,
                        layout: layout,
                        viewport: viewport
                    )
                }
            )
            .onAppear {
                handleLayoutChange(layout)
                restorePersistedNodePositionsIfNeeded(layout)
                syncViewport(layout: layout, viewport: viewport)
            }
            .onChange(of: layout.nodeIDSignature) { _ in
                handleLayoutChange(layout)
                restorePersistedNodePositionsIfNeeded(layout)
                syncViewport(layout: layout, viewport: viewport)
            }
            .onChange(of: proxy.size) { nextSize in
                syncViewport(layout: layout, viewport: nextSize)
            }
            .animation(.easeOut(duration: 0.18), value: isCenterControlsVisible)
        }
    }

    private func mapBackground(canvas: CGSize) -> some View {
        Color(nsColor: .windowBackgroundColor)
            .opacity(0.001)
            .frame(width: canvas.width, height: canvas.height)
    }

    private func mindMapCanvas(layout: MindMapLayout) -> some View {
        let nodeByID = Dictionary(uniqueKeysWithValues: layout.allNodes.map { ($0.id, $0) })
        let resolvedPositions = resolvedNodePositions(for: layout)
        let centerPosition = resolvedPositions[layout.centerNode.id] ?? layout.centerNode.position
        let rulesByID = Dictionary(uniqueKeysWithValues: viewModel.protectionRules.map { ($0.id.uuidString.lowercased(), $0) })
        let appRulesByBundleID = Dictionary(uniqueKeysWithValues: appGroups.map { ($0.app.bundleID, $0.rules) })
        let appIsDisabledByBundleID = appRulesByBundleID.mapValues { rules in
            !rules.contains(where: { $0.isEnabled })
        }

        return ZStack(alignment: .topLeading) {
            ForEach(layout.links) { link in
                if let fromNode = nodeByID[link.fromNodeID], let toNode = nodeByID[link.toNodeID] {
                    let sides = resolvedSides(
                        for: link,
                        nodeByID: nodeByID,
                        resolvedPositions: resolvedPositions
                    )
                    let from = anchorPoint(for: fromNode, side: sides.from, resolvedPositions: resolvedPositions)
                    let to = anchorPoint(for: toNode, side: sides.to, resolvedPositions: resolvedPositions)
                    let geometry = linkGeometry(from: from, to: to, fromSide: sides.from, toSide: sides.to)
                    let isDisabled = !link.isEnabled

                    geometry.path
                        .stroke(
                            isDisabled
                                ? Color.secondary.opacity(link.style == .centerToApp ? 0.28 : 0.35)
                                : (link.style == .centerToApp
                                    ? Color.accentColor.opacity(0.45)
                                    : Color.accentColor.opacity(0.35)),
                            style: link.style == .centerToApp
                                ? StrokeStyle(
                                    lineWidth: 1.3,
                                    lineCap: .round,
                                    dash: isDisabled ? [4, 6] : [5, 5]
                                )
                                : StrokeStyle(
                                    lineWidth: isDisabled ? 1.2 : 1.45,
                                    lineCap: .round,
                                    dash: isDisabled ? [3.5, 4.5] : []
                                )
                        )

                    if link.style == .appToFormat {
                        let angle = atan2(
                            geometry.endPoint.y - geometry.endControl.y,
                            geometry.endPoint.x - geometry.endControl.x
                        )
                        arrowHead(at: geometry.endPoint, angle: angle)
                            .fill(
                                isDisabled
                                    ? Color.secondary.opacity(0.52)
                                    : Color.accentColor.opacity(0.52)
                            )
                    }

                    anchorDot(
                        at: from,
                        color: isDisabled ? Color.secondary.opacity(0.36) : Color.accentColor.opacity(0.48)
                    )
                    anchorDot(
                        at: to,
                        color: isDisabled ? Color.secondary.opacity(0.44) : Color.accentColor.opacity(0.62)
                    )
                }
            }

            centerNodeWithControls(
                node: layout.centerNode
            )
            .position(centerPosition)

            ForEach(layout.appNodes) { node in
                let isDisabled = node.appBundleID.flatMap { appIsDisabledByBundleID[$0] } ?? false
                appNode(node, isDisabled: isDisabled)
                    .frame(width: node.size.width, height: node.size.height)
                    .position(resolvedPositions[node.id] ?? node.position)
                    .contextMenu {
                        appNodeContextMenu(node: node, appRulesByBundleID: appRulesByBundleID)
                    }
                    .gesture(
                        nodeDragGesture(
                            node: node,
                            currentPosition: resolvedPositions[node.id] ?? node.position,
                            canvas: layout.canvas
                        )
                    )
            }

            ForEach(layout.formatNodes) { node in
                let isDisabled = isFormatNodeDisabled(id: node.id, rulesByID: rulesByID)
                formatNode(node, isDisabled: isDisabled)
                    .frame(width: node.size.width, height: node.size.height)
                    .position(resolvedPositions[node.id] ?? node.position)
                    .contextMenu {
                        if let rule = ruleForFormatNode(id: node.id, rulesByID: rulesByID) {
                            ruleContextMenu(for: rule)
                        }
                    }
                    .gesture(
                        nodeDragGesture(
                            node: node,
                            currentPosition: resolvedPositions[node.id] ?? node.position,
                            canvas: layout.canvas
                        )
                    )
            }
        }
    }

    @ViewBuilder
    private func appNodeContextMenu(node: MindMapNode, appRulesByBundleID: [String: [ProtectionRule]]) -> some View {
        if let bundleID = node.appBundleID,
           let rules = appRulesByBundleID[bundleID],
           !rules.isEmpty {
            appGroupContextMenu(for: rules)
        }
    }

    @ViewBuilder
    private func appGroupContextMenu(for rules: [ProtectionRule]) -> some View {
        let sortedRules = rules.sorted { $0.fileType.localizedDisplayName < $1.fileType.localizedDisplayName }
        let hasEnabled = sortedRules.contains(where: { $0.isEnabled })
        let hasDisabled = sortedRules.contains(where: { !$0.isEnabled })

        if sortedRules.count == 1, let singleRule = sortedRules.first {
            ruleContextMenu(for: singleRule)
        } else {
            Menu(String(localized: "edit")) {
                ForEach(sortedRules) { rule in
                    Button(rule.displayName) {
                        selectedRule = rule
                    }
                }
            }

            if hasEnabled {
                Button("\(String(localized: "disable")) all") {
                    viewModel.setRules(sortedRules, isEnabled: false)
                }
            }

            if hasDisabled {
                Button("\(String(localized: "enable")) all") {
                    viewModel.setRules(sortedRules, isEnabled: true)
                }
            }

            Divider()

            Button("\(String(localized: "delete")) all", role: .destructive) {
                viewModel.deleteRules(sortedRules)
            }
        }
    }

    @ViewBuilder
    private func ruleContextMenu(for rule: ProtectionRule) -> some View {
        Button(String(localized: "edit")) {
            selectedRule = rule
        }

        Button(rule.isEnabled ? String(localized: "disable") : String(localized: "enable")) {
            viewModel.toggleRule(rule)
        }

        Divider()

        Button(String(localized: "delete"), role: .destructive) {
            viewModel.deleteRule(rule)
        }
    }

    private func ruleForFormatNode(id nodeID: String, rulesByID: [String: ProtectionRule]) -> ProtectionRule? {
        guard nodeID.hasPrefix("fmt-") else { return nil }
        let rawRuleID = String(nodeID.dropFirst(4)).lowercased()
        return rulesByID[rawRuleID]
    }

    private func isFormatNodeDisabled(id nodeID: String, rulesByID: [String: ProtectionRule]) -> Bool {
        guard let rule = ruleForFormatNode(id: nodeID, rulesByID: rulesByID) else { return false }
        return !rule.isEnabled
    }

    private func centerNodeWithControls(node: MindMapNode) -> some View {
        ZStack {
            centerNode(node)
                .frame(width: node.size.width, height: node.size.height)

            if isCenterControlsVisible {
                sideAddButton(side: .left)
                    .offset(x: -(node.size.width / 2 + 28))
                    .transition(.scale(scale: 0.8).combined(with: .opacity))

                sideAddButton(side: .right)
                    .offset(x: node.size.width / 2 + 28)
                    .transition(.scale(scale: 0.8).combined(with: .opacity))
            }
        }
        .frame(width: node.size.width + 150, height: node.size.height + 24)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.16)) {
                isCenterControlsVisible = hovering
            }
        }
    }

    private func sideAddButton(side: MindMapSide) -> some View {
        Button {
            if let onOpenAddPage {
                onOpenAddPage()
                return
            }
            preferredSideForNextAddedApp = side
            appNodeIDsBeforeAddFromMap = Set(appGroups.map { "app-\($0.app.bundleID)" })
            isAddFromMapSheetPresented = true
        } label: {
            Image(systemName: "plus.circle.fill")
                .font(.title3)
                .foregroundStyle(.white, Color.accentColor)
                .padding(2)
                .background(
                    Circle()
                        .fill(Color(nsColor: .windowBackgroundColor).opacity(0.92))
                )
                .shadow(color: Color.black.opacity(0.14), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }

    private func centerNode(_ node: MindMapNode) -> some View {
        VStack(spacing: 4) {
            Image(systemName: "lock.shield.fill")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Color.blue)

            Text(node.title)
                .font(.headline)
                .fontWeight(.semibold)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(
                    LinearGradient(
                        colors: [Color.blue.opacity(0.24), Color.cyan.opacity(0.17)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.blue.opacity(0.42), lineWidth: 1.2)
        )
        .shadow(color: Color.blue.opacity(0.14), radius: 10, y: 2)
        .contentShape(RoundedRectangle(cornerRadius: 14))
    }

    private func appNode(_ node: MindMapNode, isDisabled: Bool = false) -> some View {
        HStack(spacing: 10) {
            appNodeIcon(node)

            VStack(alignment: .leading, spacing: 3) {
                Text(node.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(1)

                Text(node.subtitle)
                    .font(.system(size: 10, weight: .regular))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if isDisabled {
                    Text(String(localized: "disabled"))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 11)
                .fill(
                    LinearGradient(
                        colors: isDisabled
                            ? [Color.gray.opacity(0.14), Color.gray.opacity(0.08)]
                            : [Color.blue.opacity(0.16), Color.teal.opacity(0.11)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 11)
                .stroke(
                    isDisabled ? Color.secondary.opacity(0.4) : Color.blue.opacity(0.32),
                    style: StrokeStyle(lineWidth: 1, dash: isDisabled ? [4, 3] : [])
                )
        )
        .shadow(color: Color.black.opacity(0.08), radius: 4, y: 1)
        .opacity(isDisabled ? 0.82 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 11))
    }

    @ViewBuilder
    private func appNodeIcon(_ node: MindMapNode) -> some View {
        if let bundleID = node.appBundleID,
           let icon = ApplicationResolver.shared.getApplicationIcon(bundleID: bundleID) {
            Image(nsImage: icon)
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        } else {
            Image(systemName: "app.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.blue)
                .frame(width: 26, height: 26)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.blue.opacity(0.12))
                )
        }
    }

    private func formatNode(_ node: MindMapNode, isDisabled: Bool = false) -> some View {
        HStack(spacing: 7) {
            Image(systemName: isDisabled ? "lock.open.fill" : "lock.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(
                    isDisabled
                        ? Color.secondary
                        : Color(red: 0.58, green: 0.90, blue: 0.60)
                )
                .frame(width: 14, height: 14)
                .background(
                    Circle()
                        .fill(isDisabled ? Color.gray.opacity(0.14) : Color.green.opacity(0.12))
                        .frame(width: 16, height: 16)
                )

            VStack(alignment: .leading, spacing: 1) {
                Text(node.title)
                    .font(.system(size: 11, weight: .semibold))
                    .lineLimit(1)

                Text(isDisabled ? "\(node.subtitle) • \(String(localized: "disabled"))" : node.subtitle)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 9)
                .fill(
                    isDisabled
                        ? Color.gray.opacity(0.08)
                        : Color(nsColor: .windowBackgroundColor).opacity(0.96)
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(
                    isDisabled ? Color.secondary.opacity(0.42) : Color.gray.opacity(0.24),
                    style: StrokeStyle(lineWidth: 1, dash: isDisabled ? [4, 3] : [])
                )
        )
        .shadow(color: Color.black.opacity(0.06), radius: 3, y: 1)
        .opacity(isDisabled ? 0.84 : 1)
        .contentShape(RoundedRectangle(cornerRadius: 9))
    }

    private func anchorDot(at point: CGPoint, color: Color) -> some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .overlay(
                Circle()
                    .stroke(Color(nsColor: .windowBackgroundColor), lineWidth: 1)
            )
            .position(point)
    }

    private func arrowHead(at point: CGPoint, angle: CGFloat) -> Path {
        let size: CGFloat = 9
        let tip = point
        let back = CGPoint(
            x: point.x - cos(angle) * size,
            y: point.y - sin(angle) * size
        )
        let normal = CGPoint(x: -sin(angle), y: cos(angle))
        let wing: CGFloat = size * 0.46
        let left = CGPoint(x: back.x + normal.x * wing, y: back.y + normal.y * wing)
        let right = CGPoint(x: back.x - normal.x * wing, y: back.y - normal.y * wing)

        var path = Path()
        path.move(to: tip)
        path.addLine(to: left)
        path.addLine(to: right)
        path.closeSubpath()
        return path
    }

    private func linkGeometry(from: CGPoint, to: CGPoint, fromSide: MindMapSide, toSide: MindMapSide) -> MindMapLinkGeometry {
        let horizontalDistance = abs(to.x - from.x)
        let bend = max(50, min(220, horizontalDistance * 0.55))

        let control1 = CGPoint(
            x: from.x + (fromSide == .right ? bend : -bend),
            y: from.y
        )
        let control2 = CGPoint(
            x: to.x + (toSide == .left ? -bend : bend),
            y: to.y
        )

        var path = Path()
        path.move(to: from)
        path.addCurve(to: to, control1: control1, control2: control2)

        return MindMapLinkGeometry(
            path: path,
            endPoint: to,
            endControl: control2
        )
    }

    private func resolvedSides(
        for link: MindMapLink,
        nodeByID: [String: MindMapNode],
        resolvedPositions: [String: CGPoint]
    ) -> (from: MindMapSide, to: MindMapSide) {
        guard let fromNode = nodeByID[link.fromNodeID],
              let toNode = nodeByID[link.toNodeID] else {
            return (from: link.fromSide, to: link.toSide)
        }

        let fromPosition = resolvedPositions[fromNode.id] ?? fromNode.position
        let toPosition = resolvedPositions[toNode.id] ?? toNode.position

        switch link.style {
        case .centerToApp, .appToFormat:
            if toPosition.x >= fromPosition.x {
                return (from: .right, to: .left)
            }
            return (from: .left, to: .right)
        }
    }

    private func anchorPoint(for node: MindMapNode, side: MindMapSide, resolvedPositions: [String: CGPoint]) -> CGPoint {
        let center = resolvedPositions[node.id] ?? node.position
        switch side {
        case .left:
            return CGPoint(x: center.x - node.size.width / 2, y: center.y)
        case .right:
            return CGPoint(x: center.x + node.size.width / 2, y: center.y)
        }
    }

    private func clampedPosition(_ point: CGPoint, nodeSize: CGSize, canvas: CGSize) -> CGPoint {
        let horizontalPadding: CGFloat = 10
        let verticalPadding: CGFloat = 10
        let minX = nodeSize.width / 2 + horizontalPadding
        let maxX = canvas.width - nodeSize.width / 2 - horizontalPadding
        let minY = nodeSize.height / 2 + verticalPadding
        let maxY = canvas.height - nodeSize.height / 2 - verticalPadding

        return CGPoint(
            x: min(max(minX, point.x), maxX),
            y: min(max(minY, point.y), maxY)
        )
    }

    private func nodeDragGesture(
        node: MindMapNode,
        currentPosition: CGPoint,
        canvas: CGSize
    ) -> some Gesture {
        DragGesture()
            .onChanged { value in
                isNodeDragInFlight = true

                let startPosition: CGPoint
                if let start = dragStartPositions[node.id] {
                    startPosition = start
                } else {
                    dragStartPositions[node.id] = currentPosition
                    startPosition = currentPosition
                }

                let translated = CGPoint(
                    x: startPosition.x + value.translation.width,
                    y: startPosition.y + value.translation.height
                )
                nodeOverrides[node.id] = clampedPosition(translated, nodeSize: node.size, canvas: canvas)
            }
            .onEnded { _ in
                dragStartPositions.removeValue(forKey: node.id)
                isNodeDragInFlight = false
            }
    }

    private func resolvedNodePositions(for layout: MindMapLayout) -> [String: CGPoint] {
        var positions: [String: CGPoint] = [:]
        for node in layout.allNodes {
            positions[node.id] = clampedPosition(
                nodeOverrides[node.id] ?? node.position,
                nodeSize: node.size,
                canvas: layout.canvas
            )
        }
        return positions
    }

    private func handleLayoutChange(_ layout: MindMapLayout) {
        pruneNodeOverrides(validIDs: Set(layout.nodeIDs))

        let currentAppIDs = Set(layout.appNodes.map(\.id))
        if knownAppNodeIDs.isEmpty {
            knownAppNodeIDs = currentAppIDs
            return
        }

        let newAppNodeIDs = currentAppIDs.subtracting(knownAppNodeIDs)
        if let side = preferredSideForNextAddedApp, !newAppNodeIDs.isEmpty {
            placeNewNodesOnPreferredSide(layout: layout, appNodeIDs: newAppNodeIDs, side: side)
            preferredSideForNextAddedApp = nil
        }

        knownAppNodeIDs = currentAppIDs
    }

    private func placeNewNodesOnPreferredSide(
        layout: MindMapLayout,
        appNodeIDs: Set<String>,
        side: MindMapSide
    ) {
        let nodeByID = Dictionary(uniqueKeysWithValues: layout.allNodes.map { ($0.id, $0) })
        let formatNodesByApp = Dictionary(grouping: layout.links.filter { $0.style == .appToFormat }, by: \.fromNodeID)
            .mapValues { $0.map(\.toNodeID) }
        let centerX = layout.centerNode.position.x

        for appNodeID in appNodeIDs.sorted() {
            guard let appNode = nodeByID[appNodeID] else { continue }

            let currentAppPosition = nodeOverrides[appNodeID] ?? appNode.position
            let targetAppX = centerX + (side == .left ? -300 : 300)
            let targetAppPoint = clampedPosition(
                CGPoint(x: targetAppX, y: currentAppPosition.y),
                nodeSize: appNode.size,
                canvas: layout.canvas
            )
            nodeOverrides[appNodeID] = targetAppPoint

            guard let formatNodeIDs = formatNodesByApp[appNodeID] else { continue }
            for formatNodeID in formatNodeIDs {
                guard let formatNode = nodeByID[formatNodeID] else { continue }

                let currentFormatPoint = nodeOverrides[formatNodeID] ?? formatNode.position
                let verticalOffset = currentFormatPoint.y - appNode.position.y
                let horizontalGap = max(210, abs(currentFormatPoint.x - appNode.position.x))
                let targetFormatX = targetAppPoint.x + (side == .left ? -horizontalGap : horizontalGap)

                let targetFormatPoint = clampedPosition(
                    CGPoint(x: targetFormatX, y: targetAppPoint.y + verticalOffset),
                    nodeSize: formatNode.size,
                    canvas: layout.canvas
                )
                nodeOverrides[formatNodeID] = targetFormatPoint
            }
        }
    }

    private var appGroups: [AppGroup] {
        let grouped = Dictionary(grouping: viewModel.protectionRules, by: { $0.expectedApplication.bundleID })
        return grouped.compactMap { _, rules in
            guard let first = rules.first else { return nil }
            let sortedRules = rules.sorted { $0.fileType.localizedDisplayName < $1.fileType.localizedDisplayName }
            return AppGroup(app: first.expectedApplication, rules: sortedRules)
        }
        .sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
    }

    private func buildLayout(for groups: [AppGroup]) -> MindMapLayout {
        let rowsPerColumn = 6
        let centerNodeSize = CGSize(width: 190, height: 90)
        let appNodeSize = CGSize(width: 232, height: 70)
        let formatNodeSize = CGSize(width: 148, height: 38)
        let centerToAppDistance: CGFloat = 286
        let appToFormatDistance: CGFloat = 304
        let formatColumnSpacing: CGFloat = 168
        let formatRowSpacing: CGFloat = 54
        let appVerticalGap: CGFloat = 50

        let sideAssignment = assignSides(groups)
        let leftGroups = sideAssignment.left
        let rightGroups = sideAssignment.right

        let leftColumns = leftGroups.map { formatColumnCount(for: $0.rules.count, rowsPerColumn: rowsPerColumn) }.max() ?? 1
        let rightColumns = rightGroups.map { formatColumnCount(for: $0.rules.count, rowsPerColumn: rowsPerColumn) }.max() ?? 1
        let maxColumns = max(leftColumns, rightColumns)
        let horizontalOuterPadding: CGFloat = 230

        let halfReach = centerToAppDistance
            + appNodeSize.width / 2
            + appToFormatDistance
            + CGFloat(max(0, maxColumns - 1)) * formatColumnSpacing
            + formatNodeSize.width / 2
            + horizontalOuterPadding

        let sideHeight = max(
            requiredSideHeight(
                groups: leftGroups,
                appNodeSize: appNodeSize,
                formatNodeSize: formatNodeSize,
                rowsPerColumn: rowsPerColumn,
                formatRowSpacing: formatRowSpacing,
                appVerticalGap: appVerticalGap
            ),
            requiredSideHeight(
                groups: rightGroups,
                appNodeSize: appNodeSize,
                formatNodeSize: formatNodeSize,
                rowsPerColumn: rowsPerColumn,
                formatRowSpacing: formatRowSpacing,
                appVerticalGap: appVerticalGap
            )
        )

        let canvas = CGSize(
            width: max(1450, halfReach * 2),
            height: max(860, sideHeight + 220)
        )
        let center = CGPoint(x: canvas.width / 2, y: canvas.height / 2)
        let leftAppX = center.x - centerToAppDistance
        let rightAppX = center.x + centerToAppDistance

        let leftY = distributedYPositions(
            groups: leftGroups,
            canvasHeight: canvas.height,
            topPadding: 110,
            bottomPadding: 110,
            appNodeSize: appNodeSize,
            formatNodeSize: formatNodeSize,
            rowsPerColumn: rowsPerColumn,
            formatRowSpacing: formatRowSpacing,
            appVerticalGap: appVerticalGap
        )
        let rightY = distributedYPositions(
            groups: rightGroups,
            canvasHeight: canvas.height,
            topPadding: 110,
            bottomPadding: 110,
            appNodeSize: appNodeSize,
            formatNodeSize: formatNodeSize,
            rowsPerColumn: rowsPerColumn,
            formatRowSpacing: formatRowSpacing,
            appVerticalGap: appVerticalGap
        )

        var appNodes: [MindMapNode] = []
        var formatNodes: [MindMapNode] = []
        var links: [MindMapLink] = []

        let centerNode = MindMapNode(
            id: "center-filetypeguard",
            title: "FileTypeGuard",
            subtitle: "",
            kind: .center,
            position: center,
            size: centerNodeSize
        )

        for (idx, group) in leftGroups.enumerated() {
            let appPoint = CGPoint(
                x: leftAppX + stableJitter(seed: group.app.bundleID, salt: 11, amplitude: 10),
                y: leftY[idx] + stableJitter(seed: group.app.bundleID, salt: 12, amplitude: 12)
            )
            buildNodesForGroup(
                group: group,
                appPoint: appPoint,
                centerNodeID: centerNode.id,
                isLeft: true,
                appNodeSize: appNodeSize,
                formatNodeSize: formatNodeSize,
                rowsPerColumn: rowsPerColumn,
                appToFormatDistance: appToFormatDistance,
                formatColumnSpacing: formatColumnSpacing,
                formatRowSpacing: formatRowSpacing,
                appNodes: &appNodes,
                formatNodes: &formatNodes,
                links: &links
            )
        }

        for (idx, group) in rightGroups.enumerated() {
            let appPoint = CGPoint(
                x: rightAppX + stableJitter(seed: group.app.bundleID, salt: 13, amplitude: 10),
                y: rightY[idx] + stableJitter(seed: group.app.bundleID, salt: 14, amplitude: 12)
            )
            buildNodesForGroup(
                group: group,
                appPoint: appPoint,
                centerNodeID: centerNode.id,
                isLeft: false,
                appNodeSize: appNodeSize,
                formatNodeSize: formatNodeSize,
                rowsPerColumn: rowsPerColumn,
                appToFormatDistance: appToFormatDistance,
                formatColumnSpacing: formatColumnSpacing,
                formatRowSpacing: formatRowSpacing,
                appNodes: &appNodes,
                formatNodes: &formatNodes,
                links: &links
            )
        }

        return MindMapLayout(
            canvas: canvas,
            centerNode: centerNode,
            appNodes: appNodes,
            formatNodes: formatNodes,
            links: links
        )
    }

    private func buildNodesForGroup(
        group: AppGroup,
        appPoint: CGPoint,
        centerNodeID: String,
        isLeft: Bool,
        appNodeSize: CGSize,
        formatNodeSize: CGSize,
        rowsPerColumn: Int,
        appToFormatDistance: CGFloat,
        formatColumnSpacing: CGFloat,
        formatRowSpacing: CGFloat,
        appNodes: inout [MindMapNode],
        formatNodes: inout [MindMapNode],
        links: inout [MindMapLink]
    ) {
        let appNodeID = "app-\(group.app.bundleID)"
        let appNode = MindMapNode(
            id: appNodeID,
            title: group.app.name,
            subtitle: group.app.bundleID,
            kind: .app,
            position: appPoint,
            size: appNodeSize,
            appBundleID: group.app.bundleID
        )
        appNodes.append(appNode)

        links.append(
            MindMapLink(
                id: "center-\(group.app.bundleID)",
                fromNodeID: centerNodeID,
                toNodeID: appNodeID,
                fromSide: isLeft ? .left : .right,
                toSide: isLeft ? .right : .left,
                style: .centerToApp,
                isEnabled: group.rules.contains(where: { $0.isEnabled })
            )
        )

        let total = group.rules.count
        for (index, rule) in group.rules.enumerated() {
            let column = index / rowsPerColumn
            let row = index % rowsPerColumn
            let remaining = max(0, total - (column * rowsPerColumn))
            let rowsInColumn = max(1, min(rowsPerColumn, remaining))
            let rowOffset = CGFloat(rowsInColumn - 1) / 2

            let lateralJitter = stableJitter(seed: rule.id.uuidString, salt: 51, amplitude: 14)
            let verticalJitter = stableJitter(seed: rule.id.uuidString, salt: 52, amplitude: 12)
            let xOffset = appToFormatDistance + CGFloat(column) * formatColumnSpacing + lateralJitter
            let formatPoint = CGPoint(
                x: appPoint.x + (isLeft ? -xOffset : xOffset),
                y: appPoint.y + (CGFloat(row) - rowOffset) * formatRowSpacing + verticalJitter
            )

            let formatNodeID = "fmt-\(rule.id.uuidString)"
            formatNodes.append(
                MindMapNode(
                    id: formatNodeID,
                    title: rule.fileType.extensionsString,
                    subtitle: rule.fileType.localizedDisplayName,
                    kind: .format,
                    position: formatPoint,
                    size: formatNodeSize
                )
            )

            links.append(
                MindMapLink(
                    id: "appfmt-\(rule.id.uuidString)",
                    fromNodeID: appNodeID,
                    toNodeID: formatNodeID,
                    fromSide: isLeft ? .left : .right,
                    toSide: isLeft ? .right : .left,
                    style: .appToFormat,
                    isEnabled: rule.isEnabled
                )
            )
        }
    }

    private func formatColumnCount(for ruleCount: Int, rowsPerColumn: Int) -> Int {
        max(1, Int(ceil(Double(max(1, ruleCount)) / Double(rowsPerColumn))))
    }

    private func formatClusterHeight(
        ruleCount: Int,
        formatNodeSize: CGSize,
        rowsPerColumn: Int,
        rowSpacing: CGFloat
    ) -> CGFloat {
        let visibleRows = max(1, min(rowsPerColumn, max(1, ruleCount)))
        return CGFloat(visibleRows - 1) * rowSpacing + formatNodeSize.height
    }

    private func requiredSideHeight(
        groups: [AppGroup],
        appNodeSize: CGSize,
        formatNodeSize: CGSize,
        rowsPerColumn: Int,
        formatRowSpacing: CGFloat,
        appVerticalGap: CGFloat
    ) -> CGFloat {
        guard !groups.isEmpty else { return 0 }
        let footprints = groups.map { group in
            max(
                appNodeSize.height,
                formatClusterHeight(
                    ruleCount: group.rules.count,
                    formatNodeSize: formatNodeSize,
                    rowsPerColumn: rowsPerColumn,
                    rowSpacing: formatRowSpacing
                )
            )
        }
        let totalFootprint = footprints.reduce(0, +)
        let totalGaps = appVerticalGap * CGFloat(max(0, footprints.count - 1))
        return totalFootprint + totalGaps
    }

    private func distributedYPositions(
        groups: [AppGroup],
        canvasHeight: CGFloat,
        topPadding: CGFloat,
        bottomPadding: CGFloat,
        appNodeSize: CGSize,
        formatNodeSize: CGSize,
        rowsPerColumn: Int,
        formatRowSpacing: CGFloat,
        appVerticalGap: CGFloat
    ) -> [CGFloat] {
        guard !groups.isEmpty else { return [] }
        let availableHeight = max(1, canvasHeight - topPadding - bottomPadding)
        let rawHeights = groups.map { group in
            max(
                appNodeSize.height,
                formatClusterHeight(
                    ruleCount: group.rules.count,
                    formatNodeSize: formatNodeSize,
                    rowsPerColumn: rowsPerColumn,
                    rowSpacing: formatRowSpacing
                )
            )
        }
        let rawTotal = rawHeights.reduce(0, +) + appVerticalGap * CGFloat(max(0, rawHeights.count - 1))
        let scale = rawTotal > availableHeight ? availableHeight / rawTotal : 1.0
        let scaledGap = appVerticalGap * scale
        let scaledHeights = rawHeights.map { $0 * scale }
        let scaledTotal = scaledHeights.reduce(0, +) + scaledGap * CGFloat(max(0, scaledHeights.count - 1))

        var cursor = topPadding + max(0, (availableHeight - scaledTotal) / 2)
        var result: [CGFloat] = []
        for index in scaledHeights.indices {
            let height = scaledHeights[index]
            result.append(cursor + height / 2)
            cursor += height
            if index < scaledHeights.count - 1 {
                cursor += scaledGap
            }
        }
        return result
    }

    private func stableJitter(seed: String, salt: Int, amplitude: CGFloat) -> CGFloat {
        let value = stableInt(from: seed, salt: salt)
        let normalized = CGFloat(value % 1000) / 999.0
        return (normalized - 0.5) * amplitude * 2
    }

    private func stableInt(from text: String, salt: Int) -> Int {
        var hash = salt &* 16777619
        for scalar in text.unicodeScalars {
            hash = (hash ^ Int(scalar.value)) &* 16777619
        }
        return abs(hash)
    }

    private func assignSides(_ groups: [AppGroup]) -> (left: [AppGroup], right: [AppGroup]) {
        let sorted = groups.sorted { lhs, rhs in
            if lhs.rules.count != rhs.rules.count {
                return lhs.rules.count > rhs.rules.count
            }
            return lhs.app.name.localizedCaseInsensitiveCompare(rhs.app.name) == .orderedAscending
        }

        var left: [AppGroup] = []
        var right: [AppGroup] = []
        var leftWeight = 0
        var rightWeight = 0

        for group in sorted {
            if leftWeight <= rightWeight {
                left.append(group)
                leftWeight += max(1, group.rules.count)
            } else {
                right.append(group)
                rightWeight += max(1, group.rules.count)
            }
        }

        let byName: (AppGroup, AppGroup) -> Bool = { a, b in
            a.app.name.localizedCaseInsensitiveCompare(b.app.name) == .orderedAscending
        }
        return (left.sorted(by: byName), right.sorted(by: byName))
    }

    private func clampedZoom(_ value: CGFloat) -> CGFloat {
        min(maxZoom, max(minZoom, value))
    }

    private func canvasPanGesture(layout: MindMapLayout, viewport: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                guard !isNodeDragInFlight else { return }
                let startCenter: CGPoint
                if isCanvasDragInFlight {
                    startCenter = canvasDragStartCenter
                } else {
                    canvasDragStartCenter = currentCameraCenter(for: layout)
                    isCanvasDragInFlight = true
                    startCenter = canvasDragStartCenter
                }

                let safeZoom = max(zoomScale, 0.001)
                let proposedCenter = CGPoint(
                    x: startCenter.x - value.translation.width / safeZoom,
                    y: startCenter.y - value.translation.height / safeZoom
                )
                cameraCenter = clampedCameraCenter(
                    proposedCenter,
                    viewport: viewport,
                    canvas: layout.canvas,
                    zoom: zoomScale
                )
            }
            .onEnded { _ in
                isCanvasDragInFlight = false
            }
    }

    private func canvasZoomGesture(layout: MindMapLayout, viewport: CGSize) -> some Gesture {
        MagnificationGesture()
            .onChanged { value in
                let startScale: CGFloat
                if isZoomGestureInFlight {
                    startScale = zoomGestureStartScale
                } else {
                    zoomGestureStartScale = zoomScale
                    isZoomGestureInFlight = true
                    startScale = zoomScale
                }

                let nextZoom = clampedZoom(startScale * value)
                applyZoom(
                    nextZoom: nextZoom,
                    previousZoom: zoomScale,
                    layout: layout,
                    viewport: viewport
                )
            }
            .onEnded { value in
                let nextZoom = clampedZoom(zoomGestureStartScale * value)
                applyZoom(
                    nextZoom: nextZoom,
                    previousZoom: zoomScale,
                    layout: layout,
                    viewport: viewport
                )
                isZoomGestureInFlight = false
            }
    }

    private func applyZoom(
        nextZoom: CGFloat,
        previousZoom: CGFloat,
        layout: MindMapLayout,
        viewport: CGSize
    ) {
        guard viewport.width > 1, viewport.height > 1 else {
            zoomScale = nextZoom
            return
        }

        let safePreviousZoom = max(previousZoom, 0.001)
        let viewportCenter = CGPoint(x: viewport.width / 2, y: viewport.height / 2)
        let pivot = pointerTracker.location ?? viewportCenter
        let currentCenter = currentCameraCenter(for: layout)

        // Keep the world point under the cursor stable while zooming.
        let worldAtPivot = CGPoint(
            x: currentCenter.x + (pivot.x - viewportCenter.x) / safePreviousZoom,
            y: currentCenter.y + (pivot.y - viewportCenter.y) / safePreviousZoom
        )
        let safeNextZoom = max(nextZoom, 0.001)
        let proposedCenter = CGPoint(
            x: worldAtPivot.x - (pivot.x - viewportCenter.x) / safeNextZoom,
            y: worldAtPivot.y - (pivot.y - viewportCenter.y) / safeNextZoom
        )

        zoomScale = nextZoom
        cameraCenter = clampedCameraCenter(
            proposedCenter,
            viewport: viewport,
            canvas: layout.canvas,
            zoom: nextZoom
        )
    }

    private func syncViewport(layout: MindMapLayout, viewport: CGSize) {
        guard viewport.width > 1, viewport.height > 1 else { return }

        if !hasConfiguredViewport {
            let initial = initialZoom(layout: layout, viewport: viewport)
            zoomScale = initial
            cameraCenter = layout.centerNode.position
            hasConfiguredViewport = true
        }

        cameraCenter = clampedCameraCenter(
            currentCameraCenter(for: layout),
            viewport: viewport,
            canvas: layout.canvas,
            zoom: zoomScale
        )
    }

    private func initialZoom(layout: MindMapLayout, viewport: CGSize) -> CGFloat {
        let focusNodes = [layout.centerNode] + layout.appNodes
        guard !focusNodes.isEmpty else { return 1 }

        var minX = CGFloat.greatestFiniteMagnitude
        var maxX = -CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxY = -CGFloat.greatestFiniteMagnitude

        for node in focusNodes {
            let halfWidth = node.size.width / 2
            let halfHeight = node.size.height / 2
            minX = min(minX, node.position.x - halfWidth)
            maxX = max(maxX, node.position.x + halfWidth)
            minY = min(minY, node.position.y - halfHeight)
            maxY = max(maxY, node.position.y + halfHeight)
        }

        let padding: CGFloat = 120
        let focusWidth = max(1, (maxX - minX) + padding * 2)
        let focusHeight = max(1, (maxY - minY) + padding * 2)

        let widthFit = viewport.width / focusWidth
        let heightFit = viewport.height / focusHeight
        let fitScale = min(widthFit, heightFit)

        return clampedZoom(min(1.0, fitScale))
    }

    private func currentCameraCenter(for layout: MindMapLayout) -> CGPoint {
        if hasConfiguredViewport {
            return cameraCenter
        }
        return layout.centerNode.position
    }

    private func viewportTransformOffset(
        viewport: CGSize,
        cameraCenter: CGPoint,
        zoom: CGFloat
    ) -> CGSize {
        CGSize(
            width: viewport.width / 2 - cameraCenter.x * zoom,
            height: viewport.height / 2 - cameraCenter.y * zoom
        )
    }

    private func clampedCameraCenter(
        _ center: CGPoint,
        viewport: CGSize,
        canvas: CGSize,
        zoom: CGFloat
    ) -> CGPoint {
        let safeZoom = max(zoom, 0.001)
        let halfViewportWorldWidth = viewport.width / (2 * safeZoom)
        let halfViewportWorldHeight = viewport.height / (2 * safeZoom)

        // Extra space around the canvas for comfortable navigation.
        let horizontalSlack = max(140 / safeZoom, viewport.width * 0.24 / safeZoom)
        let verticalSlack = max(110 / safeZoom, viewport.height * 0.20 / safeZoom)

        let minX = halfViewportWorldWidth - horizontalSlack
        let maxX = canvas.width - halfViewportWorldWidth + horizontalSlack
        let minY = halfViewportWorldHeight - verticalSlack
        let maxY = canvas.height - halfViewportWorldHeight + verticalSlack

        let clampedX: CGFloat
        if minX <= maxX {
            clampedX = min(max(center.x, minX), maxX)
        } else {
            clampedX = canvas.width / 2
        }

        let clampedY: CGFloat
        if minY <= maxY {
            clampedY = min(max(center.y, minY), maxY)
        } else {
            clampedY = canvas.height / 2
        }

        return CGPoint(x: clampedX, y: clampedY)
    }

    private func handleScrollPan(
        translation: CGSize,
        layout: MindMapLayout,
        viewport: CGSize
    ) {
        let safeZoom = max(zoomScale, 0.001)
        let proposedCenter = CGPoint(
            x: currentCameraCenter(for: layout).x - translation.width / safeZoom,
            y: currentCameraCenter(for: layout).y - translation.height / safeZoom
        )
        cameraCenter = clampedCameraCenter(
            proposedCenter,
            viewport: viewport,
            canvas: layout.canvas,
            zoom: zoomScale
        )
    }

    private func pruneNodeOverrides(validIDs: Set<String>) {
        nodeOverrides = nodeOverrides.filter { validIDs.contains($0.key) }
        dragStartPositions = dragStartPositions.filter { validIDs.contains($0.key) }
        if dragStartPositions.isEmpty {
            isNodeDragInFlight = false
        }
    }

    private func restorePersistedNodePositionsIfNeeded(_ layout: MindMapLayout) {
        guard !hasRestoredPersistedNodePositions else { return }
        hasRestoredPersistedNodePositions = true

        let stored = ConfigurationManager.shared.getPreferences().mindMapNodePositions
        guard !stored.isEmpty else { return }

        let nodeByID = Dictionary(uniqueKeysWithValues: layout.allNodes.map { ($0.id, $0) })
        var restored: [String: CGPoint] = [:]

        for (nodeID, savedPosition) in stored {
            guard nodeID != layout.centerNode.id,
                  let node = nodeByID[nodeID] else { continue }

            let point = CGPoint(x: CGFloat(savedPosition.x), y: CGFloat(savedPosition.y))
            restored[nodeID] = clampedPosition(
                point,
                nodeSize: node.size,
                canvas: layout.canvas
            )
        }

        guard !restored.isEmpty else { return }
        nodeOverrides.merge(restored) { _, new in new }
        pruneNodeOverrides(validIDs: Set(layout.nodeIDs))
    }

    private func persistNodeOverrides() {
        var preferences = ConfigurationManager.shared.getPreferences()
        let serialized = nodeOverrides.mapValues { point in
            ConfigurationManager.UserPreferences.MindMapNodePosition(
                x: Double(point.x),
                y: Double(point.y)
            )
        }

        guard preferences.mindMapNodePositions != serialized else { return }
        preferences.mindMapNodePositions = serialized

        do {
            try ConfigurationManager.shared.updatePreferences(preferences)
        } catch {
            print("❌ Failed to persist mind-map node positions: \(error.localizedDescription)")
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "shield.slash")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("no_protection_types")
                .font(.title2)
                .fontWeight(.semibold)

            Text("add_type_hint")
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
    }
}

enum ProtectedTypesDisplayMode {
    case mindMap
    case list
}

private struct AppGroup {
    let app: Application
    let rules: [ProtectionRule]
}

private enum MindMapNodeKind {
    case center
    case app
    case format
}

private enum MindMapSide {
    case left
    case right
}

private enum MindMapLinkStyle {
    case centerToApp
    case appToFormat
}

private struct MindMapLayout {
    let canvas: CGSize
    let centerNode: MindMapNode
    let appNodes: [MindMapNode]
    let formatNodes: [MindMapNode]
    let links: [MindMapLink]

    var allNodes: [MindMapNode] {
        [centerNode] + appNodes + formatNodes
    }

    var nodeIDs: [String] {
        allNodes.map(\.id)
    }

    var nodeIDSignature: String {
        nodeIDs.joined(separator: "|")
    }
}

private struct MindMapNode: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let kind: MindMapNodeKind
    let position: CGPoint
    let size: CGSize
    let appBundleID: String?

    init(
        id: String,
        title: String,
        subtitle: String,
        kind: MindMapNodeKind,
        position: CGPoint,
        size: CGSize,
        appBundleID: String? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
        self.position = position
        self.size = size
        self.appBundleID = appBundleID
    }
}

private struct MindMapLink: Identifiable {
    let id: String
    let fromNodeID: String
    let toNodeID: String
    let fromSide: MindMapSide
    let toSide: MindMapSide
    let style: MindMapLinkStyle
    let isEnabled: Bool
}

private struct MindMapLinkGeometry {
    let path: Path
    let endPoint: CGPoint
    let endControl: CGPoint
}

private final class ZoomPointerTracker: ObservableObject {
    var location: CGPoint?
}

private struct ScrollWheelPanCaptureView: NSViewRepresentable {
    let onScroll: (CGSize) -> Void

    func makeNSView(context: Context) -> ScrollWheelPanNSView {
        let view = ScrollWheelPanNSView()
        view.onScroll = onScroll
        return view
    }

    func updateNSView(_ nsView: ScrollWheelPanNSView, context: Context) {
        nsView.onScroll = onScroll
    }
}

private final class ScrollWheelPanNSView: NSView {
    var onScroll: ((CGSize) -> Void)?
    private var localMonitor: Any?

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        refreshLocalMonitor()
    }

    deinit {
        removeLocalMonitor()
    }

    private func refreshLocalMonitor() {
        removeLocalMonitor()
        guard window != nil else { return }

        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .scrollWheel) { [weak self] event in
            guard let self, self.window != nil else { return event }
            let pointInWindow = event.locationInWindow
            let pointInView = self.convert(pointInWindow, from: nil)

            guard self.bounds.contains(pointInView) else {
                return event
            }

            let isInverted = event.isDirectionInvertedFromDevice
            let dx = isInverted ? event.scrollingDeltaX : -event.scrollingDeltaX
            let dy = isInverted ? event.scrollingDeltaY : -event.scrollingDeltaY
            self.onScroll?(CGSize(width: dx, height: dy))
            return nil
        }
    }

    private func removeLocalMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

// MARK: - Rule Row

struct RuleRow: View {
    let rule: ProtectionRule

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.fill")
                .font(.title2)
                .foregroundStyle(rule.isEnabled ? .blue : .secondary)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(rule.displayName)
                    .font(.body)
                    .fontWeight(.medium)

                Text(rule.fileType.extensionsString)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                if rule.isEnabled {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.green)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "enabled"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    HStack(spacing: 4) {
                        Circle()
                            .fill(.gray)
                            .frame(width: 8, height: 8)
                        Text(String(localized: "disabled"))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let lastVerified = rule.lastVerified {
                    Text(lastVerified, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - ViewModel

@MainActor
final class ProtectedTypesViewModel: ObservableObject {
    @Published var protectionRules: [ProtectionRule] = []

    private let configManager = ConfigurationManager.shared
    private var cancellable: Any?

    init() {
        cancellable = NotificationCenter.default.addObserver(
            forName: .protectionRulesDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.loadRules()
            }
        }
    }

    deinit {
        if let cancellable = cancellable {
            NotificationCenter.default.removeObserver(cancellable)
        }
    }

    func loadRules() {
        protectionRules = configManager.getProtectionRules()
        print("✅ 加载了 \(protectionRules.count) 个保护规则")
    }

    func toggleRule(_ rule: ProtectionRule) {
        var updatedRule = rule
        updatedRule.isEnabled.toggle()

        do {
            try configManager.updateProtectionRule(updatedRule)
            loadRules()
            print("✅ 已\(updatedRule.isEnabled ? "启用" : "禁用")规则: \(rule.displayName)")
        } catch {
            print("❌ 更新规则失败: \(error)")
        }
    }

    func deleteRule(_ rule: ProtectionRule) {
        do {
            try configManager.removeProtectionRule(id: rule.id)
            loadRules()
            print("✅ 已删除规则: \(rule.displayName)")
        } catch {
            print("❌ 删除规则失败: \(error)")
        }
    }

    func setRules(_ rules: [ProtectionRule], isEnabled: Bool) {
        let candidates = rules.filter { $0.isEnabled != isEnabled }
        guard !candidates.isEmpty else { return }

        do {
            for rule in candidates {
                var updatedRule = rule
                updatedRule.isEnabled = isEnabled
                try configManager.updateProtectionRule(updatedRule)
            }
            loadRules()
            print("✅ 已批量\(isEnabled ? "启用" : "禁用")规则: \(candidates.count)")
        } catch {
            print("❌ 批量更新规则失败: \(error)")
            loadRules()
        }
    }

    func deleteRules(_ rules: [ProtectionRule]) {
        guard !rules.isEmpty else { return }

        do {
            for rule in rules {
                try configManager.removeProtectionRule(id: rule.id)
            }
            loadRules()
            print("✅ 已批量删除规则: \(rules.count)")
        } catch {
            print("❌ 批量删除规则失败: \(error)")
            loadRules()
        }
    }
}

#Preview {
    ProtectedTypesView()
        .frame(width: 1000, height: 700)
}
