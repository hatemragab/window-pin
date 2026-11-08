import Foundation

enum PinError: LocalizedError {
    case screenRecordingDenied
    case accessibilityDenied
    case windowUnavailable
    case captureFailed(String)

    var errorDescription: String? {
        switch self {
        case .screenRecordingDenied:
            return "Window Pin needs Screen Recording permission to show a live view. Allow it in System Settings, then open Window Pin again."
        case .accessibilityDenied:
            return "Window Pin needs Accessibility permission to move the original window aside while it is pinned."
        case .windowUnavailable:
            return "That window is not available to capture. Try another window, or grant Screen Recording and open Window Pin again."
        case .captureFailed(let message):
            return message
        }
    }
}
