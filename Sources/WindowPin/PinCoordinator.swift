import AppKit
import os

@MainActor
final class PinCoordinator {
    var onChange: (() -> Void)?

    private let store = ParkedWindowStore()
    private let logger = Logger(subsystem: AppIdentity.subsystem, category: "pin")
    private var sessions: [PinSession] = []
    private var picker: WindowPickerController?
    private var lastToggle = Date.distantPast

    var pinnedSessions: [PinSession] { sessions }
    var isPicking: Bool { picker != nil }

    func restoreOrphanedWindows() {
        store.restoreOrphans()
    }

    func togglePick() {
        let now = Date()
        if now.timeIntervalSince(lastToggle) < 0.25 { return }
        lastToggle = now
        if picker != nil {
            picker?.cancel()
            return
        }
        beginPick()
    }

    func beginPick() {
        guard ensurePermissions() else { return }
        let picker = WindowPickerController()
        picker.onSelect = { [weak self] window in
            self?.picker = nil
            self?.pin(window)
        }
        picker.onCancel = { [weak self] in
            self?.picker = nil
        }
        self.picker = picker
        picker.begin()
    }

    func pin(_ window: PickableWindow) {
        guard ensurePermissions() else { return }
        if let existing = sessions.first(where: { $0.pick.windowID == window.windowID }) {
            existing.show()
            return
        }
        Task { @MainActor [weak self] in
            guard let self else { return }
            do {
                let session = try await PinSession.make(pick: window) { [weak self] session in
                    self?.unpin(session)
                }
                self.sessions.append(session)
                self.persist()
                self.onChange?()
            } catch {
                self.logger.error("Pin failed: \(error.localizedDescription, privacy: .public)")
                self.present(error)
            }
        }
    }

    func unpin(_ session: PinSession) {
        guard let index = sessions.firstIndex(where: { $0.id == session.id }) else { return }
        let frame = session.restoreFrame
        sessions.remove(at: index)
        session.stop(restoreTo: frame)
        persist()
        onChange?()
    }

    func unpinAll() {
        let snapshot = sessions
        sessions = []
        for session in snapshot {
            session.stop(restoreTo: session.restoreFrame)
        }
        persist()
        onChange?()
    }

    func windowsForMenu() -> [PickableWindow] {
        let pinnedIDs = Set(sessions.map(\.pick.windowID))
        return WindowCatalog.onScreenWindows().filter { !pinnedIDs.contains($0.windowID) }
    }

    private func persist() {
        store.sync(sessions.compactMap(\.record))
    }

    private func ensurePermissions() -> Bool {
        guard PermissionGate.isReady else {
            PermissionWindowController.shared.show()
            return false
        }
        return true
    }

    private func present(_ error: Error) {
        NSApp.activate(ignoringOtherApps: true)
        let alert = NSAlert()
        alert.messageText = "Couldn't pin that window"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
