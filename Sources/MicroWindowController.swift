import AppKit
import SwiftTerm

class MicroWindowController: NSWindowController, NSWindowDelegate, MicroTerminalViewDelegate {

    var onClose: ((MicroWindowController) -> Void)?
    var onProcessExited: (() -> Void)?

    private(set) var workingDirectory: String
    private let theme: MicroTheme
    private var terminalView: MicroTerminalView!

    /// The IPC channel for this window's micro instance.
    var ipc: MicroIPC { terminalView.ipc }

    init(theme: MicroTheme, filePaths: [String], workingDirectory: String?) {
        self.theme = theme
        self.workingDirectory = workingDirectory ?? NSHomeDirectory()

        let window = MacMicroWindow(
            contentRect: NSRect(x: 0, y: 0, width: 800, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.tabbingMode = .disallowed
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.backgroundColor = theme.defaultBg
        window.appearance = theme.appearance
        window.center()
        window.minSize = NSSize(width: 400, height: 300)
        window.title = self.workingDirectory == NSHomeDirectory()
            ? "MacMicro"
            : "\(URL(fileURLWithPath: self.workingDirectory).lastPathComponent) — MacMicro"

        super.init(window: window)
        window.delegate = self

        window.ipc = nil // will be set after terminal view is created

        let tv = MicroTerminalView(filePaths: filePaths, workingDirectory: workingDirectory, theme: theme)
        tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = tv
        window.ipc = tv.ipc
        self.terminalView = tv
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Public

    func openFile(_ path: String) {
        terminalView.openFileInTab(path)
        window?.makeKeyAndOrderFront(nil)
    }

    func setSetting(key: String, value: String) {
        terminalView.setSetting(key: key, value: value)

        if key == "colorscheme" {
            let newTheme = MicroTheme.load(colorscheme: value)
            window?.backgroundColor = newTheme.defaultBg
            window?.appearance = newTheme.appearance
        }
    }

    func changeFontSize(delta: CGFloat) {
        terminalView.changeFontSize(delta: delta)
    }

    func applyFont(_ font: NSFont) {
        terminalView.applyFont(font)
    }

    func sendCtrlQ() {
        guard terminalView.isProcessRunning else { return }
        terminalView.terminalView.process.send(data: [0x11][...])
    }

    // MARK: - MicroTerminalViewDelegate

    func microTerminalViewProcessExited(_ view: MicroTerminalView) {
        onProcessExited?()
        window?.close()
    }

    // MARK: - NSWindowDelegate

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        if terminalView.isProcessRunning {
            sendCtrlQ()
            return false
        }
        return true
    }

    func windowWillClose(_ notification: Notification) {
        onClose?(self)
    }

    func windowDidBecomeKey(_ notification: Notification) {
        window?.makeFirstResponder(terminalView.terminalView)
    }
}
