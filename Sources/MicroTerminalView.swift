import AppKit
import SwiftTerm

@MainActor protocol MicroTerminalViewDelegate: AnyObject {
    func microTerminalViewProcessExited(_ view: MicroTerminalView)
}

class MicroTerminalView: NSView {

    let terminalView: LocalProcessTerminalView
    let ipc: MicroIPC
    let workingDirectory: String
    weak var delegate: MicroTerminalViewDelegate?
    private(set) var isProcessRunning: Bool = true

    init(filePaths: [String], workingDirectory: String?, theme: MicroTheme) {
        self.ipc = MicroIPC()
        self.workingDirectory = workingDirectory ?? NSHomeDirectory()
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

        terminalView.font = FontSettings.loadFont()
        // Metal rendering disabled: SwiftTerm's Metal path uses CoreText's native
        // font advance for glyph positioning instead of the pixel-snapped cell width,
        // causing cumulative drift over long runs. This manifests as phantom cells
        // (e.g. extra space before ')' in markdown links). The non-Metal CoreText path
        // grid-aligns each glyph explicitly and doesn't have this issue.
        // See: MetalTerminalRenderer.swift buildRowDrawData() ~line 1153 vs
        //      AppleTerminalView.swift drawTerminalContents() ~line 1383

        let handler = ProcessExitHandler(owner: self)
        terminalView.processDelegate = handler
        self.exitHandler = handler

        let files = Self.filterFiles(filePaths)
        startMicro(args: files, workingDirectory: self.workingDirectory)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private var exitHandler: ProcessExitHandler?

    // MARK: - Commands

    func changeFontSize(delta: CGFloat) {
        let current = terminalView.font
        let newSize = max(8, min(72, current.pointSize + delta))
        let newFont = NSFont(descriptor: current.fontDescriptor, size: newSize)
            ?? NSFont.monospacedSystemFont(ofSize: newSize, weight: .regular)
        terminalView.font = newFont
        FontSettings.save(name: current.fontName, size: newSize)
    }

    func applyFont(_ font: NSFont) {
        terminalView.font = font
    }

    func openFileInTab(_ filePath: String) {
        ipc.send("open \(filePath)")
    }

    func setSetting(key: String, value: String) {
        ipc.send("set \(key) \(value)")
    }

    fileprivate func handleProcessExit() {
        isProcessRunning = false
        ipc.clearStaleCommands()
        delegate?.microTerminalViewProcessExited(self)
    }

    // MARK: - Process Management

    private func startMicro(args: [String], workingDirectory: String) {
        let microPath = findMicroBinary()
        let configDir = MicroConfig.configDir

        MicroConfig.ensureDefaults()

        let fullArgs = ["-config-dir", configDir] + args

        var env = ProcessInfo.processInfo.environment
        env["TERM"] = "xterm-256color"
        env["MICRO_TRUECOLOR"] = "1"
        env["MACMICRO_INSTANCE_ID"] = ipc.instanceID

        let envPairs = env.map { "\($0.key)=\($0.value)" }

        terminalView.startProcess(
            executable: microPath,
            args: fullArgs,
            environment: envPairs,
            execName: nil,
            currentDirectory: workingDirectory
        )
    }

    private static func filterFiles(_ paths: [String]) -> [String] {
        paths.filter { path in
            var isDir: ObjCBool = false
            let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDir)
            return !exists || !isDir.boolValue
        }.map { URL(fileURLWithPath: $0).path }
    }

    private func findMicroBinary() -> String {
        if let bundledPath = Bundle.main.path(forResource: "micro", ofType: nil) {
            return bundledPath
        }
        for path in ["/opt/homebrew/bin/micro", "/usr/local/bin/micro", "/usr/bin/micro"] {
            if FileManager.default.isExecutableFile(atPath: path) { return path }
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
