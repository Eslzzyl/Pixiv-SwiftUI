import SwiftUI

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

struct ConflictDialog: View {
    let itemType: ExportItemType
    let onConfirm: (ImportConflictStrategy) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(.orange)

            Text("发现已存在的数据")
                .font(.headline)

            Text("是否要将导入的数据与现有数据 \(itemType.displayName) 合并？")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(spacing: 12) {
                Button {
                    onConfirm(.merge)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle")
                        Text("合并")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundStyle(Color.accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    onConfirm(.replace)
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("覆盖")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.red.opacity(0.1))
                    .foregroundStyle(Color.red)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                Button {
                    onConfirm(.cancel)
                    dismiss()
                } label: {
                    Text("取消")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.secondary.opacity(0.1))
                    .foregroundStyle(Color.secondary)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(.top, 8)
        }
        .padding(24)
        .frame(maxWidth: 320)
        .background(dialogBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(radius: 10)
    }

    private var dialogBackgroundColor: Color {
        #if os(iOS)
        Color(.systemBackground)
        #else
        Color(nsColor: .windowBackgroundColor)
        #endif
    }
}

#Preview {
    ConflictDialog(itemType: .searchHistory) { _ in }
}
