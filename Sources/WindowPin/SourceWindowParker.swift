import AppKit

enum SourceWindowParker {
    /// Moves the window so only a sliver stays on the leftmost display.
    /// A fully hidden Chromium window often pauses video; a 1-point sliver keeps it rendering.
    static func park(pid: pid_t, windowID: CGWindowID, fallbackFrame: NSRect) -> (original: NSRect, parked: NSRect)? {
        guard let element = AXWindowLookup.element(pid: pid, windowID: windowID) else { return nil }
        let original = AXWindowLookup.frame(of: element) ?? fallbackFrame
        let minX = NSScreen.screens.map(\.frame.minX).min() ?? 0
        let parked = NSRect(
            x: minX - original.width + 1,
            y: original.origin.y,
            width: original.width,
            height: original.height
        )
        guard AXWindowLookup.setFrame(parked, of: element) else { return nil }
        return (original, parked)
    }

    @discardableResult
    static func restore(pid: pid_t, windowID: CGWindowID, to frame: NSRect) -> Bool {
        guard let element = AXWindowLookup.element(pid: pid, windowID: windowID) else { return false }
        let moved = AXWindowLookup.setFrame(frame, of: element)
        AXWindowLookup.raise(element, pid: pid)
        return moved
    }

    /// Puts a window back if this app quit while the window was still parked.
    static func restoreIfStillParked(_ record: ParkedWindowRecord) -> Bool {
        let pid = pid_t(record.pid)
        guard NSRunningApplication(processIdentifier: pid) != nil else {
            return true
        }
        let element = AXWindowLookup.element(pid: pid, windowID: CGWindowID(record.windowID))
            ?? matchingParkedElement(pid: pid, record: record)
        guard let element else { return false }
        guard let frame = AXWindowLookup.frame(of: element) else { return false }
        let parked = record.parkedOrigin
        let nearParkedSpot = abs(frame.origin.x - parked.x) < 40 && abs(frame.origin.y - parked.y) < 40
        guard nearParkedSpot else { return true }
        return AXWindowLookup.setFrame(record.originalFrame, of: element)
    }

    private static func matchingParkedElement(pid: pid_t, record: ParkedWindowRecord) -> AXUIElement? {
        AXWindowLookup.windows(pid: pid).first { element in
            guard let frame = AXWindowLookup.frame(of: element) else { return false }
            let sameSize = abs(frame.width - record.width) < 8 && abs(frame.height - record.height) < 8
            let sameSpot = abs(frame.origin.x - record.parkedX) < 40 && abs(frame.origin.y - record.parkedY) < 40
            let sameTitle = record.title.isEmpty || copyTitle(element) == record.title
            return sameSize && sameSpot && sameTitle
        }
    }

    private static func copyTitle(_ element: AXUIElement) -> String {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXTitleAttribute as CFString, &raw) == .success,
              let title = raw as? String else {
            return ""
        }
        return title
    }
}
