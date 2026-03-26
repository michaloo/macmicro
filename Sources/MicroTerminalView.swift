import AppKit
import SwiftTerm

@MainActor protocol MicroTerminalViewDelegate: AnyObject {
    func microTerminalViewProcessExited(_ view: MicroTerminalView)
}

class MicroTerminalView: NSView {

    let terminalView: LocalProcessTerminalView
    weak var delegate: MicroTerminalViewDelegate?
    private(set) var isProcessRunning: Bool = true

    init(filePaths: [String], theme: MicroTheme) {
        terminalView = LocalProcessTerminalView(frame: .zero)
        super.init(frame: .zero)

        wantsLayer = true
        layer?.backgroundColor = theme.defaultBg.cgColor

        let hPadding: CGFloat = 4
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.nativeBackgroundColor = theme.defaultBg
        addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: topAnchor),
            terminalView.bottomAnchor.constraint(equalTo: bottomAnchor),
            terminalView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: hPadding),
            terminalView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -hPadding),
        ])

        terminalView.font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)

        let handler = ProcessExitHandler(owner: self)
        terminalView.processDelegate = handler
        self.exitHandler = handler

        let resolved = Self.resolveInitialPaths(filePaths)
        startMicro(args: resolved.args, workingDirectory: resolved.cwd)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var exitHandler: ProcessExitHandler?

    // MARK: - Commands

    /// Open a file in a new micro tab via the plugin IPC.
    func openFileInTab(_ filePath: String) {
        MicroIPC.shared.send("open \(filePath)")
    }

    /// Change a setting in the running micro instance via the plugin IPC.
    func setSetting(key: String, value: String) {
        MicroIPC.shared.send("set \(key) \(value)")
    }

    fileprivate func handleProcessExit() {
        isProcessRunning = false
        delegate?.microTerminalViewProcessExited(self)
    }

    // MARK: - Process Management

    private func startMicro(args: [String], workingDirectory: String?) {
        let microPath = findMicroBinary()
        let configDir = MicroConfig.configDir

        // Ensure config directory and default settings exist
        MicroConfig.ensureDefaults()

        let fullArgs = ["-config-dir", configDir] + args

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["MICRO_TRUECOLOR"] = "1"

        let envPairs = env.map { "\($0.key)=\($0.value)" }

        terminalView.startProcess(
            executable: microPath,
            args: fullArgs,
            environment: envPairs,
            execName: nil,
            currentDirectory: workingDirectory
        )
    }

    /// Always use HOME as CWD. Files are passed as absolute paths.
    private static func resolveInitialPaths(_ paths: [String]) -> (args: [String], cwd: String?) {
        // Filter out directories — they don't make sense as micro file args
        let files = paths.filter { path in
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            return !exists || !isDir.boolValue
        }

        // Use absolute paths so they work regardless of CWD
        let args = files.map { URL(fileURLWithPath: $0).path }
        return (args: args, cwd: NSHomeDirectory())
    }

    private func findMicroBinary() -> String {
        if let bundledPath = Bundle.main.path(forResource: "micro", ofType: nil) {
            return bundledPath
        }

        let searchPaths = [
            "/opt/homebrew/bin/micro",
            "/usr/local/bin/micro",
            "/usr/bin/micro",
        ]

        for path in searchPaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        return "/opt/homebrew/bin/micro"
    }
}

class ProcessExitHandler: LocalProcessTerminalViewDelegate {
    private weak var owner: MicroTerminalView?

    init(owner: MicroTerminalView) {
        self.owner = owner
    }

    func processTerminated(source: TerminalView, exitCode: Int32?) {
        let owner = self.owner
        DispatchQueue.main.async {
            owner?.handleProcessExit()
        }
    }

    func sizeChanged(source: LocalProcessTerminalView, newCols: Int, newRows: Int) {}
    func setTerminalTitle(source: LocalProcessTerminalView, title: String) {}
    func hostCurrentDirectoryUpdate(source: TerminalView, directory: String?) {}
}
