import SwiftUI
#if canImport(VisionKit)
import VisionKit
#endif
#if canImport(UIKit)
import UIKit
#endif

#if canImport(VisionKit) && canImport(UIKit)
/// Native document camera scanner wrapper using Apple's VisionKit VNDocumentCameraViewController.
public struct VNDocumentScannerView: UIViewControllerRepresentable {
    public var onScanCompleted: (UIImage) -> Void
    public var onCancel: () -> Void

    public init(
        onScanCompleted: @escaping (UIImage) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.onScanCompleted = onScanCompleted
        self.onCancel = onCancel
    }

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    public func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    public class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: VNDocumentScannerView

        init(_ parent: VNDocumentScannerView) {
            self.parent = parent
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            if scan.pageCount > 0 {
                let image = scan.imageOfPage(at: 0)
                parent.onScanCompleted(image)
            } else {
                parent.onCancel()
            }
        }

        public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.onCancel()
        }

        public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            parent.onCancel()
        }
    }
}
#endif
