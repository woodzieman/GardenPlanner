import SwiftUI
import AVFoundation
import SwiftData

struct SeedScannerView: View {
    @Environment(\.modelContext) private var modelContext
    @StateObject private var scannerService = BarcodeScannerService()
    @State private var matcherService: BarcodeMatcherService?
    
    @State private var showResult = false
    @State private var lastScannedBarcode: String = ""
    @State private var matchedVariety: Variety?
    
    var onScanComplete: (SeedRecord) -> Void
    
    var body: some View {
        ZStack {
            // Camera Preview
            CameraPreview(session: scannerService.session)
                .ignoresSafeArea()
            
            // Scanner Overlay
            ScannerOverlay()
            
            // Scanning Status / Result Overlay
            VStack {
                if scannerService.isScanning {
                    Text("Align barcode in center")
                        .font(.headline)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.black.opacity(0.7))
                        .cornerRadius(10)
                        .padding(.top, 50)
                }
                
                Spacer()
                
                if showResult {
                    ResultCard(barcode: lastScannedBarcode, variety: matchedVariety)
                        .padding()
                        .transition(.move(edge: .bottom))
                }
            }
        }
        .onAppear {
            matcherService = BarcodeMatcherService(modelContext: modelContext)
            scannerService.setupSession()
        }
        .onDisappear {
            scannerService.stopSession()
        }
        .onChange(of: scannerService.scannedBarcode) { oldValue, newValue in
            if let barcode = newValue {
                handleBarcodeDetected(barcode)
            }
        }
    }
    
    private func handleBarcodeDetected(_ barcode: String) {
        lastScannedBarcode = barcode
        scannerService.isScanning = false
        
        Task {
            if let variety = await matcherService?.match(barcode: barcode) {
                matchedVariety = variety
            } else {
                matchedVariety = nil
            }
            
            await MainActor.run {
                withAnimation {
                    showResult = true
                }
            }
        }
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    
    func makeUIView(context: Context) -> UIView {
        let view = UIView(frame: UIScreen.main.bounds)
        let previewLayer = AVCaptureVideoPreviewLayer(session: session)
        previewLayer.videoGravity = .resizeAspectFill
        view.layer.addSublayer(previewLayer)
        return view
    }
    
    func updateUIView(_ uiView: UIView, context: Context) {
        if let previewLayer = uiView.layer.sublayers?.first as? AVCaptureVideoPreviewLayer {
            previewLayer.frame = uiView.bounds
        }
    }
}

struct ScannerOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .stroke(Color.white.opacity(0.5), lineWidth: 2)
                .frame(width: 250, height: 150)
                .cornerRadius(12)
        }
    }
}

struct ResultCard: View {
    let barcode: String
    let variety: Variety?
    
    @Environment(\.modelContext) private var modelContext
    @State private var isRecording = false
    
    var body: some View {
        VStack(spacing: 16) {
            if let variety = variety {
                Text(variety.name)
                    .font(.title2)
                    .bold()
                Text("Matched variety!")
                    .font(.subheadline)
                    .foregroundColor(.green)
            } else {
                Text("Unknown Product")
                    .font(.title2)
                    .bold()
                Text("No matching plant found in database.")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            
            Text("Barcode: \(barcode)")
                .font(.caption)
                .monospaced()
            
            Button {
                saveSeed()
            } label: {
                if isRecording {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Save Seed")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRecording)
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(20)
    }
    
    private func saveSeed() {
        isRecording = true
        let matcher = BarcodeMatcherService(modelContext: modelContext)
        let record = matcher.recordSeed(barcode: barcode, variety: variety)
        
        // Simulate delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isRecording = false
            print("Seed record saved: \(record.barcode)")
            // In real app, we'd notify parent. For now, we just finish.
        }
    }
}
