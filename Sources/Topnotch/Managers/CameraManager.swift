import AVFoundation
import CoreImage
import Combine

/// Drives the built-in camera for the Mirror widget.
///
/// Frames are converted to CGImages and published rather than shown through an
/// `AVCaptureVideoPreviewLayer`. The preview layer renders nothing inside this panel —
/// it's a borderless, non-opaque window whose SwiftUI content is mask-clipped to the
/// notch shape, and the video layer won't composite through that. Publishing frames
/// makes the preview ordinary SwiftUI content, which clips and fades like everything else.
///
/// The session only runs while the Mirror tab is actually on screen — the camera
/// indicator light is a privacy signal, so leaving it lit while the notch is collapsed
/// or another tab is showing would be wrong.
final class CameraManager: NSObject, ObservableObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    enum Status: Equatable {
        case idle
        case running
        case denied
        case unavailable
    }

    @Published private(set) var status: Status = .idle
    @Published private(set) var frame: CGImage?

    private let session = AVCaptureSession()
    private let output = AVCaptureVideoDataOutput()
    private let queue = DispatchQueue(label: "com.mike.topnotch.camera")
    private let context = CIContext(options: [.useSoftwareRenderer: false])
    private var configured = false

    func start() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            configureAndRun()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    if granted {
                        self?.configureAndRun()
                    } else {
                        self?.status = .denied
                    }
                }
            }
        default:
            status = .denied
        }
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
            DispatchQueue.main.async {
                self.frame = nil
                if self.status == .running { self.status = .idle }
            }
        }
    }

    private func configureAndRun() {
        queue.async { [weak self] in
            guard let self else { return }

            if !self.configured {
                self.session.beginConfiguration()
                self.session.sessionPreset = .hd1280x720

                guard let device = AVCaptureDevice.default(for: .video),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async { self.status = .unavailable }
                    return
                }
                self.session.addInput(input)

                self.output.videoSettings = [
                    kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
                ]
                self.output.alwaysDiscardsLateVideoFrames = true
                self.output.setSampleBufferDelegate(self, queue: self.queue)
                if self.session.canAddOutput(self.output) { self.session.addOutput(self.output) }

                self.session.commitConfiguration()
                self.configured = true
            }

            if !self.session.isRunning { self.session.startRunning() }
            DispatchQueue.main.async { self.status = .running }
        }
    }

    func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let buffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let image = CIImage(cvImageBuffer: buffer)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return }
        DispatchQueue.main.async { [weak self] in
            guard self?.status == .running else { return }
            self?.frame = cgImage
        }
    }
}
