import CoreMedia
import Foundation
import ScreenCaptureKit

final class WindowCapture: NSObject, SCStreamOutput, SCStreamDelegate {
    var onFrame: ((CMSampleBuffer) -> Void)?
    var onStopped: ((Error) -> Void)?

    private var stream: SCStream?
    private let queue = DispatchQueue(label: "com.hatemragap.windowpin.capture", qos: .userInteractive)
    private var intentionalStop = false

    func start(window: SCWindow, frame: NSRect) async throws {
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let configuration = Self.configuration(for: frame)
        let stream = SCStream(filter: filter, configuration: configuration, delegate: self)
        try stream.addStreamOutput(self, type: .screen, sampleHandlerQueue: queue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() {
        intentionalStop = true
        let stream = self.stream
        self.stream = nil
        guard let stream else { return }
        stream.stopCapture { _ in }
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .screen, CMSampleBufferIsValid(sampleBuffer), CMSampleBufferGetImageBuffer(sampleBuffer) != nil else {
            return
        }
        let frame = Self.displayImmediately(sampleBuffer)
        DispatchQueue.main.async { [weak self] in
            self?.onFrame?(frame)
        }
    }

    func stream(_ stream: SCStream, didStopWithError error: Error) {
        guard !intentionalStop else { return }
        DispatchQueue.main.async { [weak self] in
            self?.onStopped?(error)
        }
    }

    private static func configuration(for frame: NSRect) -> SCStreamConfiguration {
        let scale = DisplayGeometry.backingScale(for: frame)
        var pixelWidth = Int((frame.width * scale).rounded())
        var pixelHeight = Int((frame.height * scale).rounded())
        let longest = max(pixelWidth, pixelHeight)
        let cap = 2048
        if longest > cap, longest > 0 {
            let factor = Double(cap) / Double(longest)
            pixelWidth = Int((Double(pixelWidth) * factor).rounded())
            pixelHeight = Int((Double(pixelHeight) * factor).rounded())
        }
        let configuration = SCStreamConfiguration()
        configuration.width = even(pixelWidth)
        configuration.height = even(pixelHeight)
        configuration.scalesToFit = true
        configuration.showsCursor = false
        configuration.queueDepth = 3
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.minimumFrameInterval = CMTime(value: 1, timescale: 60)
        configuration.captureResolution = .nominal
        return configuration
    }

    private static func even(_ value: Int) -> Int {
        let positive = max(2, value)
        return positive - (positive % 2)
    }

    private static func displayImmediately(_ sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        var copy: CMSampleBuffer?
        guard CMSampleBufferCreateCopy(allocator: kCFAllocatorDefault, sampleBuffer: sampleBuffer, sampleBufferOut: &copy) == noErr,
              let copy else {
            return sampleBuffer
        }
        if let attachments = CMSampleBufferGetSampleAttachmentsArray(copy, createIfNecessary: true) as? [NSMutableDictionary],
           let dictionary = attachments.first {
            dictionary[kCMSampleAttachmentKey_DisplayImmediately as String] = true
        }
        return copy
    }
}
