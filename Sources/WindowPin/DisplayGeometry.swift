import AppKit

enum DisplayGeometry {
    /// Height of the primary display. Quartz global coordinates start at its top-left.
    static var primaryHeight: CGFloat {
        let primary = NSScreen.screens.first { $0.frame.origin == .zero }
        return (primary ?? NSScreen.screens.first)?.frame.height ?? 0
    }

    static func cocoaRect(fromQuartz rect: CGRect) -> NSRect {
        NSRect(
            x: rect.origin.x,
            y: primaryHeight - rect.origin.y - rect.height,
            width: rect.width,
            height: rect.height
        )
    }

    static func quartzPoint(fromCocoa point: NSPoint) -> CGPoint {
        CGPoint(x: point.x, y: primaryHeight - point.y)
    }

    static func backingScale(for frame: NSRect) -> CGFloat {
        let center = NSPoint(x: frame.midX, y: frame.midY)
        let screen = NSScreen.screens.first { $0.frame.contains(center) } ?? NSScreen.main
        return screen?.backingScaleFactor ?? 2
    }

    /// Keeps a window on a visible screen without changing its size unless it is larger than that screen.
    static func clampedOnScreen(_ frame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first { $0.visibleFrame.intersects(frame) }
            ?? NSScreen.screens.first { $0.frame.intersects(frame) }
            ?? NSScreen.main
        guard let screen else { return frame }
        let visible = screen.visibleFrame
        var result = frame
        if result.width > visible.width { result.size.width = visible.width }
        if result.height > visible.height { result.size.height = visible.height }
        if result.maxX > visible.maxX { result.origin.x = visible.maxX - result.width }
        if result.minX < visible.minX { result.origin.x = visible.minX }
        if result.maxY > visible.maxY { result.origin.y = visible.maxY - result.height }
        if result.minY < visible.minY { result.origin.y = visible.minY }
        return result
    }

    static func frameAlignedToTopLeft(of pinFrame: NSRect, size: NSSize) -> NSRect {
        let frame = NSRect(
            x: pinFrame.minX,
            y: pinFrame.maxY - size.height,
            width: size.width,
            height: size.height
        )
        return clampedOnScreen(frame)
    }
}
