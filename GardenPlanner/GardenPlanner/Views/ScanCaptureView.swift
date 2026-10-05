import SwiftUI
import SwiftData
import ARKit
import RealityKit

/// Scan capture UI for LiDAR mapping.
/// Camera preview is a placeholder (see HANDOFF); the capture pipeline
/// (`LiDARScanner`) is real, and completed scans are saved to the garden.

struct ScanCaptureView: View {
    @StateObject private var scanner = LiDARScanner()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var hasSavedScan = false
    @State private var saveMessage: String?
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                // Camera placeholder (would be ARKit camera preview on real device)
                ZStack {
                    Color.black
                        .frame(height: 200)
                    
                    Image(systemName: "scan")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    
                    Text("Point at your garden and walk slowly around")
                        .font(.caption)
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                .cornerRadius(12)
                
                // Status
                statusLabel
                
                if let message = saveMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.green)
                        .multilineTextAlignment(.center)
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 20) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Cancel")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    
                    Button {
                        switch scanner.status {
                        case .capturing:
                            Task { await scanner.stopCapture() }
                        case .idle, .error:
                            Task { await scanner.startCapture() }
                        case .processing, .ready:
                            // Nothing to do yet
                            return
                        }
                    } label: {
                        let isStop = scanner.status == .capturing
                        Text(isStop ? "Stop Scan" : "Start Scan")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(isStop ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    .disabled(scanner.status == .processing || scanner.status == .ready)
                }
            }
            .padding()
            .navigationTitle("LiDAR Scan")
            .navigationBarTitleDisplayMode(.inline)
            .onChange(of: scanner.status) { _, newValue in
                if case .ready = newValue, !hasSavedScan {
                    saveScan()
                }
            }
        }
    }
    
    /// Persist the processed scan (boundary + heightmap) to the first garden.
    private func saveScan() {
        guard let map = scanner.processedMap else { return }
        
        let scan = Scan(
            capturedDate: Date(),
            meshURL: nil,
            heightmapData: map.heightmap,
            boundary: map.boundary,
            processed: true
        )
        
        let garden = try? modelContext.fetch(FetchDescriptor<Garden>(
            sortBy: [SortDescriptor(\Garden.createdDate)]
        )).first
        
        if let garden = garden {
            garden.scans.append(scan)
            garden.lastScanDate = scan.capturedDate
        } else {
            modelContext.insert(scan)
        }
        
        try? modelContext.save()
        hasSavedScan = true
        saveMessage = "Scan saved to your garden (\(String(format: "%.1f", map.approximateArea)) m²). Edit it in the Layout tab."
    }
    
    @ViewBuilder
    private var statusLabel: some View {
        switch scanner.status {
        case .idle:
            Text("Tap Start to begin scanning your garden space")
                .font(.caption)
                .foregroundColor(.secondary)
        case .capturing:
            VStack(spacing: 4) {
                Text("📸 Scanning...")
                    .font(.headline)
                    .foregroundColor(.white)
                ProgressView(value: scanner.progress)
            }
        case .processing:
            Text("🔍 Processing...")
                .font(.headline)
                .foregroundColor(.white)
        case .ready:
            Text("✅ Scan complete! \(scanner.pointCloud.count) points captured.")
                .font(.headline)
                .foregroundColor(.green)
        case .error(let message):
            Text("Error: \(message)")
                .font(.caption)
                .foregroundColor(.red)
                .multilineTextAlignment(.center)
        }
    }
}
