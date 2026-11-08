import CoreMedia
import ScreenCaptureKit

@MainActor
final class PinSession {
    let id = UUID()
    let pick: PickableWindow
    private(set) var originalFrame: NSRect
    private(set) var parkedFrame: NSRect?
    private let capture = WindowCapture()
    private var windowController: PinWindowController?
    private var isStopping = false
    private var onUnpin: ((PinSession) -> Void)?

    var menuLabel: String { pick.menuLabel }

    var record: ParkedWindowRecord? {
        guard let parkedFrame else { return nil }
        return ParkedWindowRecord(
            windowID: pick.windowID,
            pid: pick.pid,
            ownerName: pick.ownerName,
            title: pick.title,
            originalX: originalFrame.origin.x,
            originalY: originalFrame.origin.y,
            width: originalFrame.width,
            height: originalFrame.height,
            parkedX: parkedFrame.origin.x,
            parkedY: parkedFrame.origin.y
        )
    }

    static func make(pick: PickableWindow, onUnpin: @escaping (PinSession) -> Void) async throws -> PinSession {
        guard PermissionGate.hasScreenRecording else { throw PinError.screenRecordingDenied }
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
        guard let window = content.windows.first(where: { $0.windowID == pick.windowID }) else {
            throw PinError.windowUnavailable
        }
        let session = PinSession(pick: pick)
        session.onUnpin = onUnpin
        let measured = AXWindowLookup.frame(pid: pick.pid, windowID: pick.windowID) ?? pick.cocoaFrame
        session.originalFrame = measured
        try await session.capture.start(window: window, frame: measured)
        let controller = PinWindowController(frame: measured, label: pick.menuLabel)
        controller.onUnpin = { [weak session] in
            guard let session else { return }
            onUnpin(session)
        }
        session.windowController = controller
        session.capture.onFrame = { [weak controller] sampleBuffer in
            controller?.enqueue(sampleBuffer)
        }
        session.capture.onStopped = { [weak session] _ in
            guard let session, !session.isStopping else { return }
            onUnpin(session)
        }
        controller.show()
        if let parked = SourceWindowParker.park(pid: pick.pid, windowID: pick.windowID, fallbackFrame: measured) {
            session.originalFrame = parked.original
            session.parkedFrame = parked.parked
        }
        return session
    }

    private init(pick: PickableWindow) {
        self.pick = pick
        self.originalFrame = pick.cocoaFrame
    }

    func show() {
        windowController?.orderFront()
    }

    var restoreFrame: NSRect {
        let pinFrame = windowController?.pinFrame ?? originalFrame
        return DisplayGeometry.frameAlignedToTopLeft(of: pinFrame, size: originalFrame.size)
    }

    func stop(restoreTo frame: NSRect) {
        guard !isStopping else { return }
        isStopping = true
        capture.onFrame = nil
        capture.onStopped = nil
        capture.stop()
        windowController?.close()
        windowController = nil
        _ = SourceWindowParker.restore(pid: pick.pid, windowID: pick.windowID, to: frame)
    }
}
