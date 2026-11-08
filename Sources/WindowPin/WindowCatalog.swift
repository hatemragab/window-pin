import AppKit

enum WindowCatalog {
    private static let skippedOwners: Set<String> = [
        "Window Server",
        "Dock",
        "Control Center",
        "Notification Center",
        "SystemUIServer",
        AppIdentity.name,
    ]

    static func onScreenWindows(excludingPID: pid_t = ProcessInfo.processInfo.processIdentifier) -> [PickableWindow] {
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return []
        }
        var windows: [PickableWindow] = []
        for info in raw {
            guard let window = makeWindow(from: info, excludingPID: excludingPID) else { continue }
            windows.append(window)
        }
        return windows.sorted {
            $0.menuLabel.localizedCaseInsensitiveCompare($1.menuLabel) == .orderedAscending
        }
    }

    static func window(at cocoaPoint: NSPoint, excludingPID: pid_t = ProcessInfo.processInfo.processIdentifier) -> PickableWindow? {
        let point = DisplayGeometry.quartzPoint(fromCocoa: cocoaPoint)
        guard let raw = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        for info in raw {
            guard let window = makeWindow(from: info, excludingPID: excludingPID) else { continue }
            let quartzFrame = quartzBounds(from: info)
            if quartzFrame?.contains(point) == true {
                return window
            }
        }
        return nil
    }

    private static func makeWindow(from info: [String: Any], excludingPID: pid_t) -> PickableWindow? {
        let layer = number(info[kCGWindowLayer as String]) ?? 0
        guard layer == 0 else { return nil }
        let alpha = double(info[kCGWindowAlpha as String]) ?? 1
        guard alpha > 0.01 else { return nil }
        guard let windowID = number(info[kCGWindowNumber as String]).map({ CGWindowID($0) }) else { return nil }
        guard let pidValue = number(info[kCGWindowOwnerPID as String]) else { return nil }
        let pid = pid_t(pidValue)
        guard pid != excludingPID else { return nil }
        let owner = info[kCGWindowOwnerName as String] as? String ?? ""
        guard !skippedOwners.contains(owner) else { return nil }
        guard let quartz = quartzBounds(from: info) else { return nil }
        guard quartz.width >= 80, quartz.height >= 80 else { return nil }
        let title = info[kCGWindowName as String] as? String ?? ""
        return PickableWindow(
            windowID: windowID,
            pid: pid,
            ownerName: owner,
            title: title,
            cocoaFrame: DisplayGeometry.cocoaRect(fromQuartz: quartz)
        )
    }

    private static func quartzBounds(from info: [String: Any]) -> CGRect? {
        guard let bounds = info[kCGWindowBounds as String] as? NSDictionary else { return nil }
        return CGRect(dictionaryRepresentation: bounds)
    }

    private static func number(_ value: Any?) -> Int? {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return nil
    }

    private static func double(_ value: Any?) -> Double? {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return nil
    }
}
