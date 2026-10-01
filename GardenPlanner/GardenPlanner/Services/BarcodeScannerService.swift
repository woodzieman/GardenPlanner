import Foundation
import AVFoundation
import SwiftUI

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

            DispatchQueue.global(qos: .userInitiated).async {
                if !self.session.isRunning {
                    self.session.startRunning()
                }
            }
            isScanning = true
        } catch {
            print("Exception during setup of video capture device: \(error)")
        }
    }

    func stopSession() {
        if session.isRunning {
            session.stopRunning()
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
