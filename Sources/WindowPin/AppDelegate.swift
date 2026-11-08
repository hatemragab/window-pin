import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let coordinator = PinCoordinator()
    private var menuBar: MenuBarController?
    private var hotkeys: HotkeyController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        coordinator.restoreOrphanedWindows()
        menuBar = MenuBarController(coordinator: coordinator)
        hotkeys = HotkeyController { [coordinator] in
            coordinator.togglePick()
        }
        if !PermissionGate.isReady {
            PermissionWindowController.shared.show()
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        coordinator.unpinAll()
        return .terminateNow
    }
}
