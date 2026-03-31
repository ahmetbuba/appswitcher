import SwiftUI

struct AppRowView: View {
    let app: RunningApp
    let model: AppSwitcherModel
    var isSelected: Bool = false
    @Binding var isExpanded: Bool
    var selectedSubIndex: Int? = nil
    @ObservedObject private var hiddenStore = HiddenAppsStore.shared
    @State private var isHovered = false

    private var hasSubItems: Bool { displayCount > 1 }

    // Tab/window count excluding the "New Tab" sentinel
    private var displayCount: Int {
        app.windows.filter { !$0.isNewTab }.count
    }

    var body: some View {
        VStack(spacing: 0) {
            // Main row
            Button(action: {
                let realWindows = app.windows.filter { !$0.isNewTab }
                if realWindows.count == 1 {
                    model.focusItem(realWindows[0], in: app)
                    closePopover()
                } else if hasSubItems {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        isExpanded.toggle()
                    }
                } else {
                    model.activate(app)
                    closePopover()
                }
            }) {
                HStack(spacing: 11) {
                    // App icon
                    Image(nsImage: app.icon)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 28, height: 28)
                        .cornerRadius(6)
                        .shadow(color: .black.opacity(0.12), radius: 1.5, x: 0, y: 1)

                    // App name
                    Text(app.name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer(minLength: 6)

                    // Right side: count badge + chevron
                    if hasSubItems {
                        HStack(spacing: 5) {
                            Text(app.isBrowser
                                 ? "\(displayCount) tab\(displayCount == 1 ? "" : "s")"
                                 : "\(displayCount) win\(displayCount == 1 ? "" : "s")")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2.5)
                                .background(Capsule().fill(Color.primary.opacity(0.07)))

                            Image(systemName: "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundColor(.secondary.opacity(0.6))
                                .frame(width: 10)
                                .rotationEffect(.degrees(isExpanded ? 90 : 0))
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected
                          ? Color.accentColor.opacity(0.18)
                          : isHovered ? Color.accentColor.opacity(0.1) : Color.clear)
            )
            .onHover { isHovered = $0 }
            .contextMenu {
                if let bundleID = app.nsApp.bundleIdentifier {
                    Button {
                        hiddenStore.hide(bundleID: bundleID, name: app.name)
                        model.refresh()
                    } label: {
                        Label("Hide from List", systemImage: "eye.slash")
                    }
                }
            }

            // Sub-items
            if isExpanded && hasSubItems {
                VStack(spacing: 1) {
                    ForEach(Array(app.windows.enumerated()), id: \.element.id) { idx, item in
                        SubItemRowView(
                            item: item,
                            isBrowserTab: item.isBrowserTab,
                            isSelected: selectedSubIndex == idx
                        ) {
                            model.focusItem(item, in: app)
                            closePopover()
                        }
                    }
                }
                .padding(.leading, 14)
                .padding(.bottom, 4)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func closePopover() {
        NotificationCenter.default.post(name: .closePopover, object: nil)
    }
}

extension Notification.Name {
    static let closePopover = Notification.Name("com.appswitcher.closePopover")
    static let panelDidOpen = Notification.Name("com.appswitcher.panelDidOpen")
}
