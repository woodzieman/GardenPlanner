import SwiftUI
import ARKit

@main
struct GardenPlannerSpikeApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    checkLiDARCapability()
                }
        }
    }
}

// MARK: - Main Content View (Phase 0 Spike Entry Point)
struct ContentView: View {
    @StateObject private var scanner = LiDARScanner()
    @State private var showingScan = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "scan")
                        .font(.system(size: 64))
                        .foregroundStyle(.secondary)
                    
                    Text("LiDAR Scan Spike")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text("Phase 0: Does outdoor LiDAR → 2D map +\nheightmap produce a usable layout?")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 32)
                
                VStack(spacing: 16) {
                    // Capability status
                    HStack {
                        Image(systemName: scanner.hasLiDAR ? "checkmark.circle.fill" : "xcircle.circle.fill")
                            .foregroundStyle(scanner.hasLiDAR ? .green : .orange)
                        Text(scanner.hasLiDAR ? "LiDAR available" : "LiDAR not detected")
                            .font(.caption)
                    }
                    
                    HStack {
                        Image(systemName: scanner.isDepthAvailable ? "eye.fill" : "eye.slash")
                            .foregroundStyle(scanner.isDepthAvailable ? .green : .orange)
                        Text(scanner.isDepthAvailable ? "Depth data available" : "Depth data unavailable")
                            .font(.caption)
                    }
                    
                    if !scanner.hasLiDAR {
                        Text("⚠ This device does not have a LiDAR scanner.\nThe spike will test what we can do with\nstandard camera + ARKit instead.")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                            .padding(8)
                            .background(.orange.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(.quaternary.opacity(0.3))
                .cornerRadius(12)
                
                Spacer()
                
                Button {
                    withAnimation {
                        showingScan = true
                    }
                } label: {
                    Text("Start Scan Capture")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(.blue)
                        .cornerRadius(12)
                }
                .padding(.horizontal)
            }
            .navigationTitle("Garden Scan Spike")
            .sheet(isPresented: $showingScan) {
                ScanCaptureView(scanner: scanner)
                    .onDisappear {
                        withAnimation {
                            showingScan = false
                        }
                    }
            }
        }
    }
}

// MARK: - LiDAR capability check (prints to console for the spike)
private func checkLiDARCapability() {
    #if os(iOS)
    let configuration = ARWorldTrackingConfiguration()
    configuration.sceneReconstruction = .localMapped
    
    if ARWorldTrackingConfiguration.supportedScenes.contains(.depthWith9DOF) {
        print("✅ LiDAR scanner detected — depth capture available")
    } else if ARWorldTrackingConfiguration.supportedScenes.contains(.deviceDepth) {
        print("⚠ No LiDAR, but device depth (stereo/tonel) available")
    } else {
        print("❌ No depth/LiDAR support on this device")
    }
    
    // Check for iPhone Air (single camera, no LiDAR)
    if UIDevice.current.hasIPhoneAir {
        print("⚠ iPhone Air detected — single camera, no LiDAR")
        print("   Fallback path (manual map editor) will be the core path")
    }
    #endif
}

// MARK: - UIDevice extension for iPhone Air detection
private extension UIDevice {
    var hasIPhoneAir: Bool {
        var sysinfo = utsname()
        uname(&sysinfo)
        let machine = String(bytes: Data(bytes: &sysinfo.machine, count: Int(_SYS_NAMELEN)))
            .trimmingCharacters(in: .controlCharacters)
        return machine == "iPhone18,1" || machine == "iPhone18,2"
    }
}
