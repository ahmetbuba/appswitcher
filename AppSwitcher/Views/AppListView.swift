import SwiftUI
import AppKit

struct VisualEffectView: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let v = NSVisualEffectView()
        v.material = .menu
        v.blendingMode = .behindWindow
        v.state = .active
        return v
    }
    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct AppListView: View {
    var isSpotlight: Bool = false
    @StateObject private var model = AppSwitcherModel()
    @ObservedObject private var hiddenStore = HiddenAppsStore.shared
    @State private var searchText = ""
    @State private var selectedIndex = 0
    @State private var expandedAppIndex: Int? = nil
    @State private var selectedSubIndex = 0
    @State private var showingHidden = false
    @State private var keyMonitor: Any?
    @State private var axGranted = AccessibilityHelper.isAccessibilityGranted()
    @State private var axTimer: Timer?

    private var isSubNavActive: Bool { expandedAppIndex != nil }

    private var filtered: [RunningApp] {
        searchText.isEmpty
            ? model.apps
            : model.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        ZStack {
            VisualEffectView().ignoresSafeArea()

            VStack(spacing: 0) {
                HStack(spacing: 7) {
                    if !showingHidden {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("Search apps…", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                            .disableAutocorrection(true)

                        if !searchText.isEmpty {
                            Button(action: { searchText = "" }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    } else {
                        Image(systemName: "eye.slash")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                        Text("Hidden Apps")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                        Spacer()
                    }

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            showingHidden.toggle()
                            searchText = ""
                            selectedIndex = 0
                            expandedAppIndex = nil
                        }
                    }) {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: showingHidden ? "eye" : "eye.slash")
                                .font(.system(size: 13))
                                .foregroundColor(showingHidden ? .accentColor : .secondary)
                            if !showingHidden && !hiddenStore.hidden.isEmpty {
                                Text("\(hiddenStore.hidden.count)")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Color.accentColor))
                                    .offset(x: 7, y: -5)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .help(showingHidden ? "Back to app list" : "Manage hidden apps")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(RoundedRectangle(cornerRadius: 8).fill(Color.primary.opacity(0.06)))
                .padding(.horizontal, 10)
                .padding(.top, 10)
                .padding(.bottom, 8)

                Divider().opacity(0.4)

                if showingHidden {
                    HiddenAppsView(store: hiddenStore)
                } else if filtered.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: searchText.isEmpty ? "app.dashed" : "magnifyingglass")
                            .font(.system(size: 24, weight: .light))
                            .foregroundColor(.secondary)
                        Text(searchText.isEmpty ? "No running apps" : "No results for \"\(searchText)\"")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 28)
                } else {
                    ScrollViewReader { proxy in
                        ScrollView(.vertical, showsIndicators: false) {
                            LazyVStack(spacing: 2) {
                                ForEach(filtered) { app in
                                    let index = filtered.firstIndex(where: { $0.id == app.id }) ?? 0
                                    AppRowView(
                                        app: app,
                                        model: model,
                                        isSelected: selectedIndex == index && !isSubNavActive,
                                        isExpanded: Binding(
                                            get: { expandedAppIndex == index },
                                            set: { newVal in
                                                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                                                    expandedAppIndex = newVal ? index : nil
                                                    selectedSubIndex = 0
                                                }
                                            }
                                        ),
                                        selectedSubIndex: expandedAppIndex == index ? selectedSubIndex : nil
                                    )
                                    .id(app.id)
                                }
                            }
                            .padding(.vertical, 6)
                            .padding(.horizontal, 6)
                        }
                        .frame(minHeight: 440)
                        .onChange(of: selectedIndex) { idx in
                            let apps = filtered
                            guard idx < apps.count else { return }
                            withAnimation { proxy.scrollTo(apps[idx].id, anchor: .center) }
                        }
                    }
                }

                if !axGranted {
                    Divider().opacity(0.4)
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                        Text("Accessibility access needed for window titles")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Allow") {
                            AccessibilityHelper.requestAccessibilityPermission()
                            startAxPolling()
                        }
                            .font(.system(size: 11, weight: .medium))
                            .buttonStyle(.plain)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: isSpotlight ? 680 : 340)
        .frame(maxHeight: min((NSScreen.main?.visibleFrame.height ?? 800) * 0.85, isSpotlight ? 860 : 760))
        .clipShape(RoundedRectangle(cornerRadius: isSpotlight ? 14 : 0))
        .onAppear {
            model.refresh()
            selectedIndex = 0
            startKeyMonitor()
            axGranted = AccessibilityHelper.isAccessibilityGranted()
            if !axGranted { startAxPolling() }
        }
        .onDisappear {
            stopKeyMonitor()
            axTimer?.invalidate()
            axTimer = nil
        }
        .onChange(of: searchText) { _ in
            selectedIndex = 0
            expandedAppIndex = nil
        }
    }

    // MARK: - Accessibility polling

    private func startAxPolling() {
        axTimer?.invalidate()
        axTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            if AccessibilityHelper.isAccessibilityGranted() {
                axGranted = true
                axTimer?.invalidate()
                axTimer = nil
                model.refresh()
            }
        }
    }

    // MARK: - Key monitor

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [model] event in
            guard !showingHidden else { return event }
            let list = searchText.isEmpty
                ? model.apps
                : model.apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }

            switch event.keyCode {
            case 124: // → Right — expand sub-items
                if !isSubNavActive {
                    guard selectedIndex < list.count else { return nil }
                    let app = list[selectedIndex]
                    if !app.windows.isEmpty {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            expandedAppIndex = selectedIndex
                            selectedSubIndex = 0
                        }
                    }
                }
                return nil

            case 123: // ← Left — collapse back to app list
                if isSubNavActive {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        expandedAppIndex = nil
                    }
                }
                return nil

            case 125: // ↓
                if isSubNavActive, let expIdx = expandedAppIndex, expIdx < list.count {
                    let subCount = list[expIdx].windows.count
                    selectedSubIndex = min(selectedSubIndex + 1, subCount - 1)
                } else {
                    selectedIndex = min(selectedIndex + 1, list.count - 1)
                }
                return nil

            case 126: // ↑
                if isSubNavActive {
                    if selectedSubIndex > 0 {
                        selectedSubIndex -= 1
                    } else {
                        // Back to app list when pressing up on first sub-item
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            expandedAppIndex = nil
                        }
                    }
                } else {
                    selectedIndex = max(selectedIndex - 1, 0)
                }
                return nil

            case 36, 76: // Return / numpad Enter
                if isSubNavActive, let expIdx = expandedAppIndex, expIdx < list.count {
                    let subItems = list[expIdx].windows
                    guard selectedSubIndex < subItems.count else { return nil }
                    model.focusItem(subItems[selectedSubIndex], in: list[expIdx])
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                } else {
                    guard !list.isEmpty, selectedIndex < list.count else { return nil }
                    model.activate(list[selectedIndex])
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                }
                return nil

            case 53: // Escape
                if isSubNavActive {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        expandedAppIndex = nil
                    }
                } else {
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                }
                return nil

            default:
                return event
            }
        }
    }

    private func stopKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }
}

// MARK: - Hidden apps

struct HiddenAppsView: View {
    @ObservedObject var store: HiddenAppsStore

    var body: some View {
        if store.hidden.isEmpty {
            VStack(spacing: 6) {
                Image(systemName: "eye.slash").font(.system(size: 24, weight: .light)).foregroundColor(.secondary)
                Text("No hidden apps").font(.system(size: 12)).foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity).padding(.vertical, 28)
        } else {
            ScrollView(.vertical, showsIndicators: false) {
                LazyVStack(spacing: 2) {
                    ForEach(store.hidden.sorted(by: { $0.value < $1.value }), id: \.key) { bundleID, name in
                        HiddenAppRowView(bundleID: bundleID, name: name, icon: store.icon(for: bundleID)) {
                            store.unhide(bundleID: bundleID)
                        }
                    }
                }
                .padding(.vertical, 6).padding(.horizontal, 6)
            }
            .frame(minHeight: 440)
        }
    }
}

struct HiddenAppRowView: View {
    let bundleID: String
    let name: String
    let icon: NSImage
    let onUnhide: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 11) {
            Image(nsImage: icon).resizable().interpolation(.high)
                .frame(width: 28, height: 28).cornerRadius(6)
                .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1).opacity(0.6)
            Text(name).font(.system(size: 13, weight: .medium)).foregroundColor(.primary.opacity(0.6)).lineLimit(1)
            Spacer(minLength: 6)
            Button(action: onUnhide) {
                Text("Unhide").font(.system(size: 11, weight: .medium)).foregroundColor(.accentColor)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.1)))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 8).fill(isHovered ? Color.primary.opacity(0.05) : Color.clear))
        .onHover { isHovered = $0 }
    }
}
