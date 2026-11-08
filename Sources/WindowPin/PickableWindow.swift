import AppKit

struct PickableWindow: Identifiable {
    let windowID: CGWindowID
    let pid: pid_t
    let ownerName: String
    let title: String
    let cocoaFrame: NSRect

    var id: CGWindowID { windowID }

    var menuLabel: String {
        let owner = ownerName.isEmpty ? "Window" : ownerName
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty || trimmed == owner {
            return owner
        }
        return "\(owner) — \(trimmed)"
    }
}
