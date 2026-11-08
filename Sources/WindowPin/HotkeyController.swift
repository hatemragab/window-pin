import AppKit

final class HotkeyController {
    private let handler: () -> Void
    private var monitors: [Any] = []

    init(handler: @escaping () -> Void) {
        self.handler = handler
        let mask: NSEvent.EventTypeMask = .keyDown
        if let monitor = NSEvent.addGlobalMonitorForEvents(matching: mask, handler: { [weak self] event in
            self?.handle(event)
        }) {
            monitors.append(monitor)
        }
        if let monitor = NSEvent.addLocalMonitorForEvents(matching: mask, handler: { [weak self] event in
            guard let self else { return event }
            self.handle(event)
            return event
        }) {
            monitors.append(monitor)
        }
    }

    private func handle(_ event: NSEvent) {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let isHotkey = flags.contains(.command) && flags.contains(.control) && event.keyCode == 35
        guard isHotkey else { return }
        handler()
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
    }
}
