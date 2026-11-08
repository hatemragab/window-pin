import AppKit

@MainActor
final class PermissionWindowController: NSWindowController, NSWindowDelegate {
    static let shared = PermissionWindowController()

    private let screenStatus = NSTextField(labelWithString: "")
    private let accessibilityStatus = NSTextField(labelWithString: "")
    private var refreshTimer: Timer?

    private init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 460),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = AppIdentity.name
        super.init(window: window)
        window.delegate = self
        window.contentView = makeContent()
        refreshStatus()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not used")
    }

    func show() {
        guard let window else { return }
        refreshStatus()
        window.center()
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
        if !PermissionGate.hasScreenRecording {
            PermissionGate.promptScreenRecording()
        }
        if !PermissionGate.hasAccessibility {
            PermissionGate.promptAccessibility()
        }
        refreshStatus()
        refreshTimer?.invalidate()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshStatus()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    private func refreshStatus() {
        screenStatus.stringValue = PermissionGate.hasScreenRecording ? "Screen Recording: allowed" : "Screen Recording: not allowed"
        accessibilityStatus.stringValue = PermissionGate.hasAccessibility ? "Accessibility: allowed" : "Accessibility: not allowed"
        screenStatus.textColor = PermissionGate.hasScreenRecording ? .systemGreen : .systemRed
        accessibilityStatus.textColor = PermissionGate.hasAccessibility ? .systemGreen : .systemRed
    }

    private func makeContent() -> NSView {
        let content = NSView()
        let title = NSTextField(labelWithString: "Keep any window on top")
        title.font = .systemFont(ofSize: 20, weight: .semibold)

        let body = NSTextField(wrappingLabelWithString: "Choose a window and Window Pin shows a live view that stays above your other work. Drag the pin to move it. Click the red pin when you want the original window back. The view is not clickable, so video and calls keep playing while you work somewhere else.")
        body.font = .systemFont(ofSize: 13)

        let hint = NSTextField(wrappingLabelWithString: "Nothing is recorded or sent off this Mac. After you allow a permission, click Relaunch. macOS only applies Screen Recording to a freshly opened copy of Window Pin.")
        hint.font = .systemFont(ofSize: 12)
        hint.textColor = .secondaryLabelColor

        let screenButton = button("Allow Screen Recording", action: #selector(allowScreen))
        let accessButton = button("Allow Accessibility", action: #selector(allowAccessibility))
        let relaunchButton = button("Relaunch", action: #selector(relaunch))
        let closeButton = button("Close", action: #selector(closeWindow))

        screenStatus.font = .systemFont(ofSize: 13, weight: .medium)
        accessibilityStatus.font = .systemFont(ofSize: 13, weight: .medium)

        let stack = NSStackView(views: [
            title, body, screenStatus, accessibilityStatus, hint, screenButton, accessButton, relaunchButton, closeButton,
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor, constant: -24),
            stack.topAnchor.constraint(equalTo: content.topAnchor, constant: 20),
            screenButton.widthAnchor.constraint(equalToConstant: 220),
            accessButton.widthAnchor.constraint(equalToConstant: 220),
            relaunchButton.widthAnchor.constraint(equalToConstant: 220),
        ])
        return content
    }

    private func button(_ title: String, action: Selector) -> NSButton {
        let button = NSButton(title: title, target: self, action: action)
        button.bezelStyle = .rounded
        return button
    }

    @objc private func allowScreen() {
        PermissionGate.promptScreenRecording()
        PermissionGate.openScreenRecordingSettings()
        refreshStatus()
    }

    @objc private func allowAccessibility() {
        PermissionGate.promptAccessibility()
        PermissionGate.openAccessibilitySettings()
        refreshStatus()
    }

    @objc private func closeWindow() {
        window?.close()
    }

    @objc private func relaunch() {
        let url = Bundle.main.bundleURL
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.createsNewApplicationInstance = true
        NSWorkspace.shared.openApplication(at: url, configuration: configuration) { _, error in
            guard error == nil else { return }
            DispatchQueue.main.async {
                NSApp.terminate(nil)
            }
        }
    }
}
