import AppKit

@MainActor
final class WindowPickerController: NSWindowController {
    var onSelect: ((PickableWindow) -> Void)?
    var onCancel: (() -> Void)?

    private let overlay = PickerOverlayView(frame: .zero)
    private var previousPID: pid_t?

    init() {
        let union = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
        let window = PickerPanel(contentRect: union, styleMask: [.borderless], backing: .buffered, defer: false)
        super.init(window: window)
        window.level = .screenSaver
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.ignoresMouseEvents = false
        window.hidesOnDeactivate = false
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.contentView = overlay
        overlay.frame = NSRect(origin: .zero, size: union.size)
        overlay.onMouseDown = { [weak self] in
            self?.selectCurrent()
        }
        overlay.onCancel = { [weak self] in
            self?.cancel()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func begin() {
        guard let window else { return }
        previousPID = NSWorkspace.shared.frontmostApplication?.processIdentifier
        let union = NSScreen.screens.reduce(NSRect.null) { $0.union($1.frame) }
        window.setFrame(union, display: true)
        overlay.refreshHighlight()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(overlay)
        NSCursor.crosshair.push()
    }

    func cancel() {
        NSCursor.pop()
        window?.orderOut(nil)
        reactivatePreviousApp()
        onCancel?()
    }

    private func selectCurrent() {
        let selected = overlay.highlighted
        NSCursor.pop()
        window?.orderOut(nil)
        reactivatePreviousApp()
        if let selected {
            onSelect?(selected)
        }
    }

    private func reactivatePreviousApp() {
        guard let previousPID, previousPID != ProcessInfo.processInfo.processIdentifier else { return }
        NSRunningApplication(processIdentifier: previousPID)?.activate(from: .current, options: [.activateAllWindows])
    }
}

private final class PickerPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class PickerOverlayView: NSView {
    var onMouseDown: (() -> Void)?
    var onCancel: (() -> Void)?
    private(set) var highlighted: PickableWindow?
    private let hint = NSTextField(labelWithString: "Click a window to pin it on top. Press Esc to cancel.")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        hint.font = .systemFont(ofSize: 15, weight: .semibold)
        hint.textColor = .white
        hint.wantsLayer = true
        hint.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.62).cgColor
        hint.layer?.cornerRadius = 10
        hint.alignment = .center
        addSubview(hint)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.acceptsMouseMovedEvents = true
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach(removeTrackingArea)
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeAlways, .inVisibleRect],
            owner: self,
            userInfo: nil
        ))
    }

    override func layout() {
        super.layout()
        placeHint()
    }

    private func placeHint() {
        guard let window else { return }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main
        guard let screen else { return }
        let visible = window.convertFromScreen(screen.visibleFrame)
        let width: CGFloat = 480
        let height: CGFloat = 36
        hint.frame = NSRect(
            x: visible.midX - width / 2,
            y: visible.maxY - 64,
            width: width,
            height: height
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.black.withAlphaComponent(0.18).setFill()
        dirtyRect.fill()
        guard let highlighted, let window else { return }
        let local = window.convertFromScreen(highlighted.cocoaFrame)
        if let context = NSGraphicsContext.current {
            context.saveGraphicsState()
            context.compositingOperation = .clear
            local.fill()
            context.restoreGraphicsState()
        }
        NSColor.systemBlue.setStroke()
        let path = NSBezierPath(roundedRect: local.insetBy(dx: 2, dy: 2), xRadius: 8, yRadius: 8)
        path.lineWidth = 4
        path.stroke()
    }

    override func mouseMoved(with event: NSEvent) {
        refreshHighlight()
    }

    override func mouseDown(with event: NSEvent) {
        refreshHighlight()
        onMouseDown?()
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onCancel?()
        }
    }

    override func cancelOperation(_ sender: Any?) {
        onCancel?()
    }

    func refreshHighlight() {
        highlighted = WindowCatalog.window(at: NSEvent.mouseLocation)
        placeHint()
        needsDisplay = true
    }
}
