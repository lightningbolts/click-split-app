import SwiftUI
import PhotosUI
#if canImport(VisionKit)
import VisionKit
#endif

/// Main receipt scanning flow container handling camera / photo picking and extraction.
public struct ReceiptScannerSheet: View {
    public var members: [SplitGroupMember]
    public var onItemsReady: ([ExpenseItemDraft], Decimal, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.appEnvironment) private var environment

    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    @State private var processingImageCount = 0
    @State private var recognizedItems: [ExpenseItemDraft]?
    @State private var recognizedMerchant: String?
    @State private var recognizedTax: Decimal = 0
    @State private var recognizedTip: Decimal = 0
    @State private var errorMessage: String?
    @State private var showCamera = false

    private let scanService = ReceiptScanService()

    public init(
        members: [SplitGroupMember],
        onItemsReady: @escaping ([ExpenseItemDraft], Decimal, String?) -> Void
    ) {
        self.members = members
        self.onItemsReady = onItemsReady
    }

    public var body: some View {
        NavigationStack {
            ZStack {
                if let items = recognizedItems {
                    ReceiptReviewView(
                        members: members,
                        initialItems: items,
                        initialTax: recognizedTax,
                        initialTip: recognizedTip,
                        onApply: { configuredItems, total in
                            onItemsReady(configuredItems, total, recognizedMerchant)
                            dismiss()
                        }
                    )
                } else {
                    scanLauncherView
                }

                if isProcessing {
                    ZStack {
                        Color.black.opacity(0.4).ignoresSafeArea()
                        VStack(spacing: SplitSpacing.md) {
                            ProgressView()
                                .scaleEffect(1.4)
                                .tint(SplitColors.white)

                            Text(processingImageCount > 1 ? "Analyzing \(processingImageCount) Receipt Photos..." : "Analyzing Receipt...")
                                .font(SplitTypography.button)
                                .foregroundColor(SplitColors.white)
                        }
                        .padding(SplitSpacing.xxl)
                        .background(SplitColors.ink)
                        .cornerRadius(SplitSpacing.cornerRadius)
                    }
                }
            }
            .navigationTitle(recognizedItems != nil ? "Review Receipt" : "Receipt Scanner")
            .splitInlineTitleDisplayMode()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(recognizedItems != nil ? "Back" : "Cancel") {
                        if recognizedItems != nil {
                            recognizedItems = nil
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(SplitColors.ink)
                }
            }
            #if canImport(VisionKit) && canImport(UIKit)
            .fullScreenCover(isPresented: $showCamera) {
                VNDocumentScannerView(
                    onScanCompleted: { scannedImages in
                        showCamera = false
                        processImages(scannedImages)
                    },
                    onCancel: {
                        showCamera = false
                    }
                )
            }
            #endif
        }
    }

    private var scanLauncherView: some View {
        VStack(spacing: SplitSpacing.xl) {
            Spacer()

            // Viewfinder Icon Graphic
            ZStack {
                RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                    .fill(SplitColors.paperDim)
                    .frame(width: 120, height: 120)
                    .overlay(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .stroke(SplitColors.ink, lineWidth: SplitSpacing.borderWidth)
                    )
                    .background(
                        RoundedRectangle(cornerRadius: SplitSpacing.cornerRadius)
                            .fill(SplitColors.ink)
                            .offset(x: SplitSpacing.shadowOffset, y: SplitSpacing.shadowOffset)
                    )

                Image(systemName: "doc.viewfinder")
                    .font(.system(size: 54))
                    .foregroundColor(SplitColors.green)
            }

            VStack(spacing: SplitSpacing.xs) {
                Text("Scan Your Receipt")
                    .font(SplitTypography.amountLarge)
                    .foregroundColor(SplitColors.ink)

                Text("Capture or choose up to 10 photos for long receipts. Keep the pages in top-to-bottom order and include a little overlap between photos.")
                    .font(SplitTypography.body)
                    .foregroundColor(SplitColors.inkSoft)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, SplitSpacing.lg)
            }

            if let errorMessage {
                Text(errorMessage)
                    .font(SplitTypography.caption)
                    .foregroundColor(SplitColors.red)
                    .padding(.horizontal, SplitSpacing.lg)
            }

            Spacer()

            VStack(spacing: SplitSpacing.md) {
                #if canImport(VisionKit) && canImport(UIKit)
                if VNDocumentCameraViewController.isSupported {
                    SplitButton("Open Camera Scanner", icon: "camera", variant: .primary) {
                        SplitHaptics.impact(.medium)
                        showCamera = true
                    }
                }
                #endif

                // Photos Picker for Simulator and Library Upload
                PhotosPicker(
                    selection: $selectedPhotoItems,
                    maxSelectionCount: 10,
                    selectionBehavior: .ordered,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: SplitSpacing.sm) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose Up to 10 Photos")
                    }
                    .font(SplitTypography.button)
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(
                    SplitPressableButtonStyle(
                        backgroundColor: SplitColors.paperDim,
                        foregroundColor: SplitColors.ink,
                        borderColor: SplitColors.ink,
                        shadowOffset: SplitSpacing.shadowOffsetSmall
                    )
                )
                .onChange(of: selectedPhotoItems) { _, newItems in
                    guard !newItems.isEmpty else { return }
                    Task {
                        #if canImport(UIKit)
                        var images: [UIImage] = []
                        for item in newItems.prefix(10) {
                            if let data = try? await item.loadTransferable(type: Data.self),
                               let image = UIImage(data: data) {
                                images.append(image)
                            }
                        }
                        selectedPhotoItems = []
                        processImages(images)
                        #endif
                    }
                }

                // Demo / Mock Extraction for Instant Simulator Testing
                Button(action: {
                    SplitHaptics.impact(.light)
                    simulateDemoReceipt()
                }) {
                    Text("Or Try with Sample Receipt")
                        .font(SplitTypography.caption)
                        .foregroundColor(SplitColors.grey)
                        .underline()
                }
                .padding(.top, SplitSpacing.xs)
            }
            .padding(.horizontal, SplitSpacing.lg)
            .padding(.bottom, SplitSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(SplitColors.paper.ignoresSafeArea())
    }

    #if canImport(UIKit)
    private func processImages(_ images: [UIImage]) {
        let compressedImages = images.prefix(10).compactMap {
            ReceiptScanService.compressImage($0)
        }

        guard !compressedImages.isEmpty else {
            errorMessage = "Could not read the selected receipt photos."
            SplitHaptics.notify(.error)
            return
        }

        isProcessing = true
        processingImageCount = compressedImages.count
        errorMessage = nil

        Task {
            do {
                let token = environment.sessionStore.authToken
                let result = try await scanService.extractReceipt(
                    imageDatas: compressedImages,
                    authToken: token
                )
                let drafts = result.items.map {
                    ExpenseItemDraft(label: $0.label, price: $0.price, assignedTo: nil)
                }
                isProcessing = false
                processingImageCount = 0
                SplitHaptics.notify(.success)
                self.recognizedMerchant = result.merchant
                self.recognizedItems = drafts
                self.recognizedTax = result.tax ?? 0
                self.recognizedTip = result.tip ?? 0
            } catch {
                isProcessing = false
                processingImageCount = 0
                self.errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }
    #endif

    private func simulateDemoReceipt() {
        let mockResult = ReceiptScanService.mockExtractionFallback()
        self.recognizedMerchant = mockResult.merchant
        self.recognizedItems = mockResult.items.map {
            ExpenseItemDraft(label: $0.label, price: $0.price, assignedTo: nil)
        }
        self.recognizedTax = mockResult.tax ?? 0
        self.recognizedTip = mockResult.tip ?? 0
    }
}
