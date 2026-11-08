import ApplicationServices
import AppKit
import Darwin

enum AXWindowLookup {
    private typealias GetWindowID = @convention(c) (AXUIElement, UnsafeMutablePointer<CGWindowID>) -> AXError

    private static let getWindowID: GetWindowID? = {
        guard let symbol = dlsym(UnsafeMutableRawPointer(bitPattern: -2), "_AXUIElementGetWindow") else {
            return nil
        }
        return unsafeBitCast(symbol, to: GetWindowID.self)
    }()

    static func windowID(of element: AXUIElement) -> CGWindowID? {
        guard let getWindowID else { return nil }
        var identifier: CGWindowID = 0
        guard getWindowID(element, &identifier) == .success else { return nil }
        return identifier
    }

    static func element(pid: pid_t, windowID: CGWindowID) -> AXUIElement? {
        windows(pid: pid).first { self.windowID(of: $0) == windowID }
    }

    static func windows(pid: pid_t) -> [AXUIElement] {
        let application = AXUIElementCreateApplication(pid)
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(application, kAXWindowsAttribute as CFString, &raw) == .success,
              let raw else {
            return []
        }
        if let elements = raw as? [AXUIElement] {
            return elements
        }
        guard CFGetTypeID(raw) == CFArrayGetTypeID() else { return [] }
        let array = raw as! CFArray
        let count = CFArrayGetCount(array)
        var elements: [AXUIElement] = []
        elements.reserveCapacity(count)
        for index in 0..<count {
            guard let pointer = CFArrayGetValueAtIndex(array, index) else { continue }
            elements.append(unsafeBitCast(pointer, to: AXUIElement.self))
        }
        return elements
    }

    static func frame(of element: AXUIElement) -> NSRect? {
        guard let origin = point(element, kAXPositionAttribute as CFString),
              let size = size(element, kAXSizeAttribute as CFString) else {
            return nil
        }
        return NSRect(origin: origin, size: size)
    }

    static func frame(pid: pid_t, windowID: CGWindowID) -> NSRect? {
        guard let element = element(pid: pid, windowID: windowID) else { return nil }
        return frame(of: element)
    }

    @discardableResult
    static func setFrame(_ frame: NSRect, of element: AXUIElement) -> Bool {
        unminimize(element)
        var size = frame.size
        var origin = frame.origin
        guard let sizeValue = AXValueCreate(.cgSize, &size),
              let originValue = AXValueCreate(.cgPoint, &origin) else {
            return false
        }
        let sizeError = AXUIElementSetAttributeValue(element, kAXSizeAttribute as CFString, sizeValue)
        let originError = AXUIElementSetAttributeValue(element, kAXPositionAttribute as CFString, originValue)
        return sizeError == .success && originError == .success
    }

    static func raise(_ element: AXUIElement, pid: pid_t) {
        AXUIElementSetAttributeValue(element, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementPerformAction(element, kAXRaiseAction as CFString)
        let application = AXUIElementCreateApplication(pid)
        AXUIElementSetAttributeValue(application, kAXFrontmostAttribute as CFString, kCFBooleanTrue)
        NSRunningApplication(processIdentifier: pid)?.activate(from: .current, options: [.activateAllWindows])
    }

    private static func unminimize(_ element: AXUIElement) {
        AXUIElementSetAttributeValue(element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
    }

    private static func point(_ element: AXUIElement, _ attribute: CFString) -> CGPoint? {
        guard let value = copyValue(element, attribute) else { return nil }
        var point = CGPoint.zero
        guard AXValueGetValue(value, .cgPoint, &point) else { return nil }
        return point
    }

    private static func size(_ element: AXUIElement, _ attribute: CFString) -> CGSize? {
        guard let value = copyValue(element, attribute) else { return nil }
        var size = CGSize.zero
        guard AXValueGetValue(value, .cgSize, &size) else { return nil }
        return size
    }

    private static func copyValue(_ element: AXUIElement, _ attribute: CFString) -> AXValue? {
        var raw: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute, &raw) == .success, let raw else {
            return nil
        }
        guard CFGetTypeID(raw) == AXValueGetTypeID() else { return nil }
        return unsafeBitCast(raw, to: AXValue.self)
    }
}
