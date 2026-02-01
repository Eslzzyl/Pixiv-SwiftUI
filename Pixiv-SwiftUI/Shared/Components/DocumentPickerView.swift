import SwiftUI
import UniformTypeIdentifiers

#if os(iOS)
import UIKit

struct DocumentPickerView: UIViewControllerRepresentable {
    let tempURL: URL
    let filename: String
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [tempURL], asCopy: false)
        picker.delegate = context.coordinator
        picker.shouldShowFileExtensions = true
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let parent: DocumentPickerView

        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            print("[DocumentPicker] 用户已选择保存位置: \(urls.first?.path ?? "unknown")")
            // 文件已被系统自动保存到选择的位置
            parent.dismiss()
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            print("[DocumentPicker] 用户取消保存")
            parent.dismiss()
        }
    }
}

#endif
