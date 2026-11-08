import Foundation

struct ParkedWindowRecord: Codable, Equatable {
    var windowID: UInt32
    var pid: Int32
    var ownerName: String
    var title: String
    var originalX: Double
    var originalY: Double
    var width: Double
    var height: Double
    var parkedX: Double
    var parkedY: Double

    var originalFrame: NSRect {
        NSRect(x: originalX, y: originalY, width: width, height: height)
    }

    var parkedOrigin: NSPoint {
        NSPoint(x: parkedX, y: parkedY)
    }
}
