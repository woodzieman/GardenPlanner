import Foundation
import AVFoundation
import SwiftUI

/// AVCaptureSession is documented thread-safe for start/stop but is not marked
/// Sendable. This box lets the capture queue hold a reference without warnings.
private final class SessionBox: @unchecked Sendable {
    let session: AVCaptureSession
    init(_ session: AVCaptureSession) { self.session = session }
}

/// Camera-based 1D barcode scanner for seed packets (EAN, UPC, Code 128/39).
@MainActor
class BarcodeScannerService: NSObject, ObservableObject {
    @Published var scannedBarcode: String?
    @Published var isScanning = false

    let session = AVCaptureSession()
    private let metadataOutput = AVCaptureMetadataOutput()

    override init() {
        super.init()
    }

    func setupSession() {
        session.beginConfiguration()
        session.sessionPreset = .medium

        guard let device = AVCaptureDevice.default(for: .video) else {
            print("Unable to access video capture device.")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: device)
            if session.canAddInput(input) {
                session.addInput(input)
            }

            if session.canAddOutput(metadataOutput) {
                session.addOutput(metadataOutput)
                metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
                metadataOutput.metadataObjectTypes = [
                    .ean8, .ean13, .code128, .code39, .upce // .upce matches UPC-A packets too
                ]
            }

            session.commitConfiguration()

            // startRunning must happen off the main thread; hand the session to
            // the capture queue through a Sendable box.
            let box = SessionBox(session)
            DispatchQueue.global(qos: .userInitiated).async {
                if !box.session.isRunning {
                    box.session.startRunning()
                }
            }
            isScanning = true
        } catch {
            print("Exception during setup of video capture device: \(error)")
        }
    }

    func stopSession() {
        let box = SessionBox(session)
        DispatchQueue.global(qos: .userInitiated).async {
            if box.session.isRunning {
                box.session.stopRunning()
            }
        }
        isScanning = false
    }
}

// MARK: - AVCaptureMetadataOutputObjectsDelegate

extension BarcodeScannerService: AVCaptureMetadataOutputObjectsDelegate {
    nonisolated func metadataOutput(
        _ output: AVCaptureMetadataOutput,
        didOutput objects: [AVMetadataObject],
        from connection: AVCaptureConnection
    ) {
        guard let object = objects.first as? AVMetadataMachineReadableCodeObject,
              let barcode = object.stringValue else { return }

        Task { @MainActor in
            self.scannedBarcode = barcode
            self.isScanning = false
            self.stopSession()
        }
    }
}
