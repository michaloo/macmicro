import AppKit
import SwiftTerm

class MicroWindowController: NSWindowController, NSWindowDelegate, MicroTerminalViewDelegate {

    var onClose: ((MicroWindowController) -> Void)?
    var onProcessExited: (() -> Void)?

    private let theme: MicroTheme
    private var terminalView: MicroTerminalView!

    init(theme: MicroTheme, filePaths: [String]) {
        self.theme = theme

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
        window.setFrameAutosaveName("MacMicroWindow")
        window.minSize = NSSize(width: 400, height: 300)
        window.title = "MacMicro"

        super.init(window: window)
        window.delegate = self

        let tv = MicroTerminalView(filePaths: filePaths, theme: theme)
        tv.delegate = self
        tv.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = tv
        self.terminalView = tv

        // All shortcuts routed through MicroIPC plugin
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError()
    }

    // MARK: - Public

    /// Open a file in a new micro tab within the running instance.
    func openFile(_ path: String) {
        terminalView.openFileInTab(path)
        window?.makeKeyAndOrderFront(nil)
    }

    /// Change a setting in the running micro instance.
    func setSetting(key: String, value: String) {
        terminalView.setSetting(key: key, value: value)

        // Update window styling when colorscheme changes
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

    /// Send Ctrl-Q directly via PTY.
    /// Micro handles it natively: closes current buffer, prompts if unsaved.
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
