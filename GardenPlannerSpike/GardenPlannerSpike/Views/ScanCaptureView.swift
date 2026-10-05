import SwiftUI
import ARKit
import RealityKit
import UIKit

/// The capture UI for the LiDAR spike.
/// Shows a live camera preview with a guidance overlay,
/// lets the user start/stop scanning, and displays progress.
struct ScanCaptureView: View {
    @ObservedObject var scanner: LiDARScanner
    @Environment(\.dismiss) private var dismiss
    
    private let captureButtonSize: CGFloat = 80
    
    var body: some View {
        VStack {
            // Camera preview / guidance view
            CameraPreviewView(scanner: scanner)
                .frame(height: 300)
                .background(.black)
            
            Divider()
            
            // Status and controls
            VStack(spacing: 16) {
                statusLabel
                
                if scanner.status == .capturing {
                    progressIndicator
                }
                
                Spacer()
                
                // Action buttons
                HStack(spacing: 24) {
                    // Cancel
                    Button {
                        Task {
                            await scanner.stopCapture()
                            dismiss()
                        }
                    } label: {
                        Text("Cancel")
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(.gray)
                            .cornerRadius(10)
                    }
                    
                    // Scan/Stop toggle
                    scanButton
                }
            }
            .padding()
        }
        .navigationTitle("Capture Scan")
        .navigationBarTitleDisplayMode(.inline)
    }
    
    // MARK: - Status label

    private var statusLabel: some View {
        switch scanner.status {
        case .idle:
            Text("Tap \"Start Scan\", then walk slowly around your garden\nfor 10–20 seconds. Cover all edges of planting areas.")
                .font(.headline)
                
        case .capturing:
            Text("📸 Scanning — walk around your garden space...")
                .font(.headline)
                
        case .processing:
            Text("🔍 Processing point cloud and building 2D map...")
                .font(.headline)
                
        case .ready:
            Text("✅ Scan complete!")
                .font(.headline)
                
        case .error(let message):
            Text("❌ Error: \(message)")
                .font(.headline)
        }
    }
    
    // MARK: - Progress indicator

    private var progressIndicator: some View {
        VStack(spacing: 4) {
            ProgressView(value: scanner.progress)
                .progressViewStyle(LinearProgressViewStyle())
                .padding(.horizontal)
            
            Text(String(format: "%.0f%% complete", scanner.progress * 100))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
    
    // MARK: - Scan button (toggle start/stop)

    private var scanButton: some View {
        Button {
            Task {
                switch scanner.status {
                case .idle:
                    await scanner.startCapture()
                case .capturing:
                    await scanner.stopCapture()
                    // After processing, show the map
                    if scanner.status == .ready {
                        // The map view is shown in the parent
                    }
                default:
                    break
                }
            }
        } label: {
            ZStack {
                Circle()
                    .fill(scanner.status == .capturing ? Color.red : Color.blue)
                    .frame(width: captureButtonSize, height: captureButtonSize)
                
                Image(systemName: scanner.status == .capturing ? "stop.fill" : "record.circle.fill")
                    .font(.title)
                    .foregroundColor(.white)
            }
        }
        .disabled(scanner.status == .processing)
    }
}

// MARK: - Camera preview overlay

/// A UIViewRepresentable that shows the ARKit camera preview
/// with an overlay showing scan coverage and guidance.
struct CameraPreviewView: UIViewRepresentable {
    @ObservedObject var scanner: LiDARScanner
    
    func makeUIView(context: Context) -> ARView {
        let arView = ARView(frame: .zero)
        
        // iOS 27: use frameSemantics instead of removed sceneReconstruction / supportedScenes
        let configuration = ARWorldTrackingConfiguration()
        configuration.worldAlignment = .gravity
        
        // Enable scene depth if available (LiDAR or stereo)
        if ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth]) {
            configuration.frameSemantics = [.sceneDepth]
            print("✅ Scene depth enabled")
        } else {
            print("⚠ No depth data available")
        }
        
        // Add an overlay showing capture guidance
        let overlayView = GuidanceOverlayView()
        arView.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.leadingAnchor.constraint(equalTo: arView.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: arView.trailingAnchor),
            overlayView.topAnchor.constraint(equalTo: arView.topAnchor),
            overlayView.bottomAnchor.constraint(equalTo: arView.bottomAnchor)
        ])
        
        // Start the session (non-throwing in simulator)
        arView.session.run(configuration)
        print("Session started")
        
        return arView
    }
    
    func updateUIView(_ uiView: ARView, context: Context) {}
}

/// Simple overlay showing capture guidance text.
class GuidanceOverlayView: UIView {
    private let label: UILabel = {
        let l = UILabel()
        l.text = "🎯 Walk slowly around the garden\nCover all planting areas\nKeep your phone at waist height"
        l.font = UIFont.systemFont(ofSize: 14)
        l.textColor = .white
        l.textAlignment = .center
        l.numberOfLines = 0
        l.alpha = 0.8
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = .clear
        self.addSubview(self.label)
        
        NSLayoutConstraint.activate([
            self.label.centerXAnchor.constraint(equalTo: self.centerXAnchor),
            self.label.centerYAnchor.constraint(equalTo: self.centerYAnchor)
        ])
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

// MARK: - Previews (for SwiftUI previews — no LiDAR on simulator)

#if DEBUG
struct ScanCaptureView_Previews: PreviewProvider {
    static var previews: some View {
        ScanCaptureView(scanner: LiDARScanner())
    }
}
#endif
