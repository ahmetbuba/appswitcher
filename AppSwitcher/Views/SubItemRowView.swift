import SwiftUI

struct SubItemRowView: View {
    let item: WindowItem
    let isBrowserTab: Bool
    var isSelected: Bool = false
    let onSelect: () -> Void
    @State private var isHovered = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 8) {
                // Left accent line
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.accentColor.opacity(item.isNewTab ? 0.8 : 0.5))
                    .frame(width: 2, height: 14)

                Image(systemName: item.isNewTab ? "plus.circle" : (isBrowserTab ? "globe" : "macwindow"))
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundColor(item.isNewTab ? .accentColor : .secondary)
                    .frame(width: 13)

                Text(item.title)
                    .font(.system(size: 12, weight: item.isNewTab ? .medium : .regular))
                    .foregroundColor(item.isNewTab ? .accentColor : .primary.opacity(0.85))
                    .lineLimit(1)
                    .truncationMode(.tail)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected
                      ? Color.accentColor.opacity(0.18)
                      : isHovered ? Color.accentColor.opacity(0.08) : Color.clear)
        )
        .onHover { isHovered = $0 }
    }
}
