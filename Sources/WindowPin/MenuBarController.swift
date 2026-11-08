import AppKit

@MainActor
final class MenuBarController: NSObject, NSMenuDelegate {
    private let coordinator: PinCoordinator
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private var listedWindows: [PickableWindow] = []

    init(coordinator: PinCoordinator) {
        self.coordinator = coordinator
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        super.init()
        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "pin.fill", accessibilityDescription: AppIdentity.name)
            image?.isTemplate = true
            button.image = image
        }
        statusItem.menu = menu
        menu.delegate = self
        coordinator.onChange = { [weak self] in
            self?.updateIcon()
        }
        updateIcon()
    }

    func menuWillOpen(_ menu: NSMenu) {
        rebuild()
    }

    private func updateIcon() {
        let name = coordinator.pinnedSessions.isEmpty ? "pin" : "pin.fill"
        let image = NSImage(systemSymbolName: name, accessibilityDescription: AppIdentity.name)
        image?.isTemplate = true
        statusItem.button?.image = image
    }

    private func rebuild() {
        menu.removeAllItems()
        let pinItem = NSMenuItem(title: "Pin a Window…", action: #selector(pinByClick), keyEquivalent: "p")
        pinItem.keyEquivalentModifierMask = [.command, .control]
        pinItem.target = self
        menu.addItem(pinItem)

        let list = NSMenuItem(title: "Pin from List", action: nil, keyEquivalent: "")
        list.submenu = windowMenu()
        menu.addItem(list)
        menu.addItem(.separator())

        if coordinator.pinnedSessions.isEmpty {
            let empty = NSMenuItem(title: "Nothing pinned", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            for (index, session) in coordinator.pinnedSessions.enumerated() {
                let item = NSMenuItem(title: "Unpin \(session.menuLabel)", action: #selector(unpinSession(_:)), keyEquivalent: "")
                item.target = self
                item.tag = index
                menu.addItem(item)
            }
            let all = NSMenuItem(title: "Unpin All", action: #selector(unpinAll), keyEquivalent: "")
            all.target = self
            menu.addItem(all)
        }

        menu.addItem(.separator())
        let login = NSMenuItem(title: "Launch at Login", action: #selector(toggleLogin), keyEquivalent: "")
        login.target = self
        login.state = LoginItemController.isEnabled ? .on : .off
        menu.addItem(login)
        let permissions = NSMenuItem(title: "Permissions…", action: #selector(showPermissions), keyEquivalent: "")
        permissions.target = self
        menu.addItem(permissions)
        menu.addItem(.separator())
        let quit = NSMenuItem(title: "Quit \(AppIdentity.name)", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
    }

    private func windowMenu() -> NSMenu {
        let submenu = NSMenu()
        listedWindows = Array(coordinator.windowsForMenu().prefix(40))
        if listedWindows.isEmpty {
            let empty = NSMenuItem(title: "No windows found", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            submenu.addItem(empty)
            return submenu
        }
        for (index, window) in listedWindows.enumerated() {
            let item = NSMenuItem(title: window.menuLabel, action: #selector(pinListed(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            submenu.addItem(item)
        }
        return submenu
    }

    @objc private func pinByClick() {
        coordinator.togglePick()
    }

    @objc private func pinListed(_ sender: NSMenuItem) {
        guard listedWindows.indices.contains(sender.tag) else { return }
        coordinator.pin(listedWindows[sender.tag])
    }

    @objc private func unpinSession(_ sender: NSMenuItem) {
        let sessions = coordinator.pinnedSessions
        guard sessions.indices.contains(sender.tag) else { return }
        coordinator.unpin(sessions[sender.tag])
    }

    @objc private func unpinAll() {
        coordinator.unpinAll()
    }

    @objc private func toggleLogin() {
        do {
            try LoginItemController.setEnabled(!LoginItemController.isEnabled)
        } catch {
            let alert = NSAlert()
            alert.messageText = "Couldn't change login item"
            alert.informativeText = "Move \(AppIdentity.name) into Applications, open it from there, and try again. \(error.localizedDescription)"
            alert.runModal()
        }
    }

    @objc private func showPermissions() {
        PermissionWindowController.shared.show()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}
