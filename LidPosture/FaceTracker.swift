import AVFoundation
import Vision

/// One face measurement in normalized image coordinates (Vision: origin bottom-left).
struct FaceSample {
    let centerY: Double     // 0…1, vertical position of the face center
    let size: Double        // 0…1, face box width — proxy for distance to screen
    let timestamp: Date
}

/// Runs the built-in camera at low resolution and detects the largest face
/// a couple of times per second to keep CPU and battery use low.
final class FaceTracker: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    var onSample: ((FaceSample?) -> Void)?
    var interval: TimeInterval = 0.5   // ~2 fps of analysis

    private let session = AVCaptureSession()
    private let queue = DispatchQueue(label: "LidPosture.FaceTracker")
    private var lastProcessed = Date.distantPast
    private var configured = false

    enum TrackerError: Error { case noCamera, accessDenied }

    func start() async throws {
        let granted = await AVCaptureDevice.requestAccess(for: .video)
        guard granted else { throw TrackerError.accessDenied }
        if !configured { try configure() }
        queue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        queue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    private func configure() throws {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera], mediaType: .video, position: .unspecified)
        guard let camera = discovery.devices.first ?? AVCaptureDevice.default(for: .video) else {
            throw TrackerError.noCamera
        }
        session.beginConfiguration()
        session.sessionPreset = .vga640x480
        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: queue)
        if session.canAddOutput(output) { session.addOutput(output) }
        session.commitConfiguration()
        configured = true
    }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        let now = Date()
        guard now.timeIntervalSince(lastProcessed) >= interval,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        lastProcessed = now

        let request = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up)
        try? handler.perform([request])

        guard let face = request.results?.max(by: { $0.boundingBox.width < $1.boundingBox.width }) else {
            onSample?(nil)
            return
        }
        let box = face.boundingBox
        onSample?(FaceSample(centerY: Double(box.midY), size: Double(box.width), timestamp: now))
    }
}
