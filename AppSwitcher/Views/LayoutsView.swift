import SwiftUI
import AppKit

struct LayoutsView: View {
    @StateObject private var store = WindowLayoutStore.shared
    @State private var isSavingNew = false
    @State private var newLayoutName = ""
    @State private var restoreResult: LayoutRestoreResult? = nil
    @State private var resultTimer: Timer? = nil
    @State private var renamingID: UUID? = nil
    @State private var renameText = ""

    private var fingerprint: MonitorFingerprint { WindowLayoutStore.currentFingerprint() }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 10) {
                Image(systemName: "rectangle.3.group")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.accentColor)
                VStack(alignment: .leading, spacing: 1) {
                    Text("Window Layouts")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Save and restore window arrangements")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            Divider()

            // Suggested layout banner
            if let suggested = store.suggestedLayout {
                HStack(spacing: 8) {
                    Image(systemName: "wand.and.stars")
                        .font(.system(size: 12))
                        .foregroundColor(.accentColor)
                    Text("\"\(suggested.name)\" matches your current monitors.")
                        .font(.system(size: 12))
                        .foregroundColor(.primary)
                    Spacer()
                    Button("Restore Now") {
                        performRestore(suggested)
                    }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 9)
                .background(Color.accentColor.opacity(0.08))

                Divider()
            }

            // Restore result feedback
            if let result = restoreResult {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.green)
                    Text(result.summary)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 7)
                .background(Color.green.opacity(0.07))

                Divider()
            }

            // Layout list
            if store.layouts.isEmpty && !isSavingNew {
                VStack(spacing: 8) {
                    Image(systemName: "rectangle.dashed")
                        .font(.system(size: 28, weight: .light))
                        .foregroundColor(.secondary)
                    Text("No saved layouts")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                    Text("Save your current window arrangement to restore it later.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 260)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView(.vertical, showsIndicators: false) {
                    LazyVStack(spacing: 1) {
                        ForEach(store.layouts) { layout in
                            if renamingID == layout.id {
                                RenameRowView(
                                    text: $renameText,
                                    onCommit: {
                                        let trimmed = renameText.trimmingCharacters(in: .whitespaces)
                                        if !trimmed.isEmpty {
                                            store.rename(id: layout.id, name: trimmed)
                                        }
                                        renamingID = nil
                                    },
                                    onCancel: { renamingID = nil }
                                )
                            } else {
                                LayoutRowView(
                                    layout: layout,
                                    isCurrent: layout.fingerprint == fingerprint,
                                    onRestore: { performRestore(layout) },
                                    onUpdate: { store.update(layout) },
                                    onRename: {
                                        renameText = layout.name
                                        renamingID = layout.id
                                    },
                                    onDelete: { store.delete(id: layout.id) }
                                )
                            }
                        }
                    }
                    .padding(.vertical, 6)
                }
            }

            Spacer(minLength: 0)
            Divider()

            // Footer
            if isSavingNew {
                HStack(spacing: 8) {
                    TextField("Layout name…", text: $newLayoutName)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12))
                        .onSubmit { commitSave() }
                    Button("Save") { commitSave() }
                        .font(.system(size: 11, weight: .medium))
                        .buttonStyle(.borderedProminent)
                        .disabled(newLayoutName.trimmingCharacters(in: .whitespaces).isEmpty)
                    Button("Cancel") {
                        isSavingNew = false
                        newLayoutName = ""
                    }
                    .font(.system(size: 11))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            } else {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Current")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.secondary)
                        Text(fingerprint.label)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    Spacer()
                    Button {
                        newLayoutName = ""
                        isSavingNew = true
                    } label: {
                        Label("Save Layout", systemImage: "plus")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .frame(width: 520, height: 480)
    }

    private func commitSave() {
        let name = newLayoutName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { return }
        store.saveNew(name: name)
        isSavingNew = false
        newLayoutName = ""
    }

    private func performRestore(_ layout: WindowLayout) {
        let result = store.restore(layout)
        withAnimation(.easeIn(duration: 0.2)) {
            restoreResult = result
        }
        resultTimer?.invalidate()
        resultTimer = Timer.scheduledTimer(withTimeInterval: 4.0, repeats: false) { _ in
            DispatchQueue.main.async {
                withAnimation(.easeOut(duration: 0.3)) {
                    self.restoreResult = nil
                }
            }
        }
    }
}

// MARK: - Layout row

struct LayoutRowView: View {
    let layout: WindowLayout
    let isCurrent: Bool
    let onRestore: () -> Void
    let onUpdate: () -> Void
    let onRename: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: layout.updatedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(spacing: 12) {
            // Match indicator
            Circle()
                .fill(isCurrent ? Color.green : Color.secondary.opacity(0.3))
                .frame(width: 7, height: 7)

            VStack(alignment: .leading, spacing: 2) {
                Text(layout.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                HStack(spacing: 4) {
                    Text(layout.fingerprint.label)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("\(layout.windows.count) win")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text("·")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                    Text(relativeDate)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            HStack(spacing: 6) {
                Button("Restore") { onRestore() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.accentColor.opacity(0.1)))

                Button("Update") { onUpdate() }
                    .font(.system(size: 11, weight: .medium))
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(RoundedRectangle(cornerRadius: 5).fill(Color.primary.opacity(0.06)))

                Menu {
                    Button("Rename…") { onRename() }
                    Divider()
                    Button(role: .destructive) { onDelete() } label: {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                        .frame(width: 24, height: 24)
                        .background(RoundedRectangle(cornerRadius: 5).fill(isHovered ? Color.primary.opacity(0.06) : Color.clear))
                }
                .menuStyle(.borderlessButton)
                .menuIndicator(.hidden)
                .fixedSize()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color.primary.opacity(0.04) : Color.clear)
                .padding(.horizontal, 6)
        )
        .onHover { isHovered = $0 }
    }
}

// MARK: - Rename row

struct RenameRowView: View {
    @Binding var text: String
    let onCommit: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            TextField("Layout name…", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
                .onSubmit { onCommit() }

            Button("Save") { onCommit() }
                .font(.system(size: 11, weight: .medium))
                .buttonStyle(.borderedProminent)
                .disabled(text.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("Cancel") { onCancel() }
                .font(.system(size: 11))
                .buttonStyle(.plain)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
    }
}
