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

    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var isProcessing = false
    @State private var recognizedItems: [ExpenseItemDraft]?
    @State private var recognizedMerchant: String?
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

                            Text("Analyzing Receipt...")
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
                    onScanCompleted: { scannedImage in
                        showCamera = false
                        processImage(scannedImage)
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

                Text("Position the receipt in frame or choose an existing photo. Line items and prices are recognized automatically.")
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
                    selection: $selectedPhotoItem,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack(spacing: SplitSpacing.sm) {
                        Image(systemName: "photo.on.rectangle")
                        Text("Choose from Photo Library")
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
                .onChange(of: selectedPhotoItem) { _, newItem in
                    guard let newItem else { return }
                    Task {
                        if let data = try? await newItem.loadTransferable(type: Data.self) {
                            #if canImport(UIKit)
                            if let img = UIImage(data: data) {
                                processImage(img)
                            }
                            #endif
                        }
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
    private func processImage(_ image: UIImage) {
        guard let compressedData = ReceiptScanService.compressImage(image) else { return }
        isProcessing = true
        errorMessage = nil

        Task {
            do {
                let token = environment.sessionStore.authToken
                let result = try await scanService.extractReceipt(imageData: compressedData, authToken: token)
                let drafts = result.items.map {
                    ExpenseItemDraft(label: $0.label, price: $0.price, assignedTo: nil)
                }
                isProcessing = false
                SplitHaptics.notify(.success)
                self.recognizedMerchant = result.merchant
                self.recognizedItems = drafts
            } catch {
                isProcessing = false
                self.errorMessage = error.localizedDescription
                SplitHaptics.notify(.error)
            }
        }
    }
    #endif

    private func simulateDemoReceipt() {
        let mockResult = ReceiptScanService.mockExtractionFallback()
        self.recognizedMerchant = "Sample Burger Joint"
        self.recognizedItems = mockResult.items.map {
            ExpenseItemDraft(label: $0.label, price: $0.price, assignedTo: nil)
        }
    }
}
