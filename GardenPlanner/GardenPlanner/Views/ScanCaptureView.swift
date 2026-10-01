import SwiftUI
import ARKit
import RealityKit

/// Simple scan capture UI for the Phase 0 LiDAR spike.
/// Integrates with the LiDARScanner from the spike module.

struct ScanCaptureView: View {
    @StateObject private var scanner = LiDARScanner()
    @Environment(\.dismiss) private var dismiss
    
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
                        Task {
                            await scanner.startCapture()
                        }
                    } label: {
                        Text(scanner.status == .capturing ? "Stop" : "Start Scan")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(scanner.status == .capturing ? Color.red : Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                }
            }
            .padding()
            .navigationTitle("LiDAR Scan")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private var statusLabel: some View {
        switch scanner.status {
        case .idle:
            Text("Tap Start to begin scanning your garden space")
                .font(.caption)
                .foregroundColor(.secondary)
        case .capturing:
            Text("📸 Scanning...")
                .font(.headline)
                .foregroundColor(.white)
        case .processing:
            Text("🔍 Processing...")
                .font(.headline)
                .foregroundColor(.white)
        case .ready:
            Text("✅ Scan complete! Your map is ready.")
                .font(.headline)
                .foregroundColor(.green)
        case .error(let message):
            Text("Error: \(message)")
                .font(.caption)
                .foregroundColor(.red)
        }
    }
}
