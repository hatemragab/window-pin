import AppKit
import CoreMedia

@MainActor
final class PinWindowController: NSWindowController, NSWindowDelegate {
    var onUnpin: (() -> Void)?

    private let videoView = PinVideoView(frame: .zero)
    private let unpinButton = NSButton()
    private let aspectRatio: CGFloat
    private var resizeAnchor: NSPoint?
    private var resizeStartFrame: NSRect = .zero

    init(frame: NSRect, label: String) {
        let width = max(frame.width, 1)
        let height = max(frame.height, 1)
        aspectRatio = width / height
        let window = NSWindow(
            contentRect: frame,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.delegate = self
        window.title = label
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        window.isMovable = false
        window.isReleasedWhenClosed = false
        window.contentView = makeContent(label: label)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show() {
        window?.setFrame(window?.frame ?? .zero, display: true)
        window?.orderFrontRegardless()
    }

    var pinFrame: NSRect {
        window?.frame ?? .zero
    }

    func enqueue(_ sampleBuffer: CMSampleBuffer) {
        videoView.enqueue(sampleBuffer)
    }

    func orderFront() {
        window?.orderFrontRegardless()
    }

    private func makeContent(label: String) -> NSView {
        let content = PinContentView(frame: .zero)
        content.onMouseDown = { [weak self] event in
            self?.handleMouseDown(event)
        }
        content.wantsLayer = true
        content.layer?.shadowColor = NSColor.black.cgColor
        content.layer?.shadowOpacity = 0.35
        content.layer?.shadowRadius = 16
        content.layer?.shadowOffset = CGSize(width: 0, height: -4)

        videoView.wantsLayer = true
        videoView.layer?.cornerRadius = 12
        videoView.layer?.masksToBounds = true
        videoView.layer?.borderWidth = 1
        videoView.layer?.borderColor = NSColor.white.withAlphaComponent(0.28).cgColor
        videoView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(videoView)

        let image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "Unpin")
        unpinButton.image = image
        unpinButton.bezelStyle = .circular
        unpinButton.isBordered = false
        unpinButton.imagePosition = .imageOnly
        unpinButton.contentTintColor = .white
        unpinButton.toolTip = "Unpin \(label)"
        unpinButton.target = self
        unpinButton.action = #selector(unpin)
        unpinButton.wantsLayer = true
        unpinButton.layer?.backgroundColor = NSColor.systemRed.cgColor
        unpinButton.layer?.cornerRadius = 13
        unpinButton.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(unpinButton)

        NSLayoutConstraint.activate([
            videoView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            videoView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            videoView.topAnchor.constraint(equalTo: content.topAnchor),
            videoView.bottomAnchor.constraint(equalTo: content.bottomAnchor),
            unpinButton.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -8),
            unpinButton.topAnchor.constraint(equalTo: content.topAnchor, constant: 8),
            unpinButton.widthAnchor.constraint(equalToConstant: 26),
            unpinButton.heightAnchor.constraint(equalToConstant: 26),
        ])
        return content
    }

    private func handleMouseDown(_ event: NSEvent) {
        guard let window, let content = window.contentView else { return }
        let local = content.convert(event.locationInWindow, from: nil)
        let inCorner = local.x > content.bounds.width - 22 && local.y < 22
        if inCorner {
            resizeAnchor = NSEvent.mouseLocation
            resizeStartFrame = window.frame
            trackResize()
        } else if !hitUnpinButton(event) {
            window.performDrag(with: event)
        }
    }

    private func hitUnpinButton(_ event: NSEvent) -> Bool {
        guard let content = window?.contentView else { return false }
        let local = content.convert(event.locationInWindow, from: nil)
        return unpinButton.frame.contains(local)
    }

    private func trackResize() {
        NSCursor.crosshair.push()
        while let event = window?.nextEvent(matching: [.leftMouseDragged, .leftMouseUp]) {
            if event.type == .leftMouseUp { break }
            guard let anchor = resizeAnchor, let window else { break }
            let mouse = NSEvent.mouseLocation
            let deltaX = mouse.x - anchor.x
            var width = max(180, resizeStartFrame.width + deltaX)
            var height = width / aspectRatio
            if height < 120 {
                height = 120
                width = height * aspectRatio
            }
            var frame = resizeStartFrame
            frame.origin.y = resizeStartFrame.maxY - height
            frame.size = NSSize(width: width, height: height)
            window.setFrame(frame, display: true)
        }
        NSCursor.pop()
        resizeAnchor = nil
    }

    @objc private func unpin() {
        onUnpin?()
    }
}

private final class PinContentView: NSView {
    var onMouseDown: ((NSEvent) -> Void)?

    override func hitTest(_ point: NSPoint) -> NSView? {
        guard let hit = super.hitTest(point) else { return nil }
        if hit is NSButton { return hit }
        return self
    }

    override func mouseDown(with event: NSEvent) {
        onMouseDown?(event)
    }
}
