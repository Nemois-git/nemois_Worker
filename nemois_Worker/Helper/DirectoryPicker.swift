
//
//  DirectoryPicker.swift
//  nemois_Worker
//
//  Created by nemois on 10/14/25.
//

import SwiftUI
internal import UniformTypeIdentifiers

#if os(macOS)
// macOS에서는 NSOpenPanel을 사용하여 폴더를 선택합니다.
func showDirectoryPicker(completion: @escaping (URL?) -> Void) {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.title = "Select a folder to store AI models"

    if openPanel.runModal() == .OK {
        completion(openPanel.url)
    } else {
        completion(nil)
    }
}

#elseif os(iOS)
// iOS에서는 UIDocumentPickerViewController를 사용합니다.
// SwiftUI에서 이를 사용하기 위해 UIViewControllerRepresentable을 구현합니다.
struct DirectoryPicker: UIViewControllerRepresentable {
    @Binding var isPresented: Bool
    let onSelect: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        // .folder 타입을 사용하여 폴더 선택 모드로 설정합니다.
        let controller = UIDocumentPickerViewController(forOpeningContentTypes: [.folder])
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var parent: DirectoryPicker

        init(_ parent: DirectoryPicker) {
            self.parent = parent
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                parent.onSelect(url)
            }
            parent.isPresented = false
        }
        
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            parent.isPresented = false
        }
    }
}

// SwiftUI 뷰에서 더 쉽게 사용할 수 있도록 View extension을 추가합니다.
extension View {
    func directoryPicker(isPresented: Binding<Bool>, onSelect: @escaping (URL) -> Void) -> some View {
        self.sheet(isPresented: isPresented) {
            DirectoryPicker(isPresented: isPresented, onSelect: onSelect)
        }
    }
}
#endif
