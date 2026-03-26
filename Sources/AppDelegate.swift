import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowControllers: [MicroWindowController] = []
    private var preferencesWindow: PreferencesWindow?
    private lazy var theme: MicroTheme = MicroTheme.load()
    private var pendingFiles: [String] = []

    /// The currently focused window controller.
    private var activeWindowController: MicroWindowController? {
        windowControllers.first { $0.window?.isKeyWindow == true } ?? windowControllers.first
    }

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        MicroIPC.cleanupAll()
        setupMenuBar()

        if windowControllers.isEmpty {
            let files = pendingFiles.isEmpty ? [] : pendingFiles
            pendingFiles = []
            createWindow(filePaths: files, workingDirectory: nil)
        }
    }

    private var quitQueue: [MicroWindowController] = []

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        let running = windowControllers.filter { $0.window != nil }
        guard !running.isEmpty else { return .terminateNow }

        quitQueue = running
        quitNextWindow()
        return .terminateLater
    }

    /// Close windows one at a time to avoid micro instances racing on shared config files.
    private func quitNextWindow() {
        guard let wc = quitQueue.first else {
            windowControllers.removeAll()
            NSApp.reply(toApplicationShouldTerminate: true)
            return
        }

        wc.ipc.send("action QuitAll")
        wc.onProcessExited = { [weak self] in
            wc.ipc.clearStaleCommands()
            self?.quitQueue.removeFirst()
            self?.quitNextWindow()
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - File Opening

    func application(_ application: NSApplication, open urls: [URL]) {
        let paths = urls.map(\.path).filter { path in
            var isDir: ObjCBool = false
            return !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) || !isDir.boolValue
        }
        guard !paths.isEmpty else { return }

        if windowControllers.isEmpty {
            pendingFiles.append(contentsOf: paths)
            return
        }

        // Open files in the focused window
        if let wc = activeWindowController {
            for path in paths {
                wc.openFile(path)
            }
        }
    }

    // MARK: - Window Management

    private func createWindow(filePaths: [String], workingDirectory: String?) {
        let wc = MicroWindowController(theme: theme, filePaths: filePaths, workingDirectory: workingDirectory)
        wc.onClose = { [weak self] controller in
            self?.windowControllers.removeAll { $0 === controller }
        }
        wc.showWindow(nil)
        windowControllers.append(wc)
    }

    // MARK: - Menu Bar

    private func setupMenuBar() {
        let mainMenu = NSMenu()

        // Application menu
        let appMenuItem = NSMenuItem()
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "About MacMicro", action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: "")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Settings…", action: #selector(showPreferences(_:)), keyEquivalent: ",")
        appMenu.addItem(.separator())
        appMenu.addItem(withTitle: "Quit MacMicro", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu
        mainMenu.addItem(appMenuItem)

        // File menu
        let fileMenuItem = NSMenuItem()
        let fileMenu = NSMenu(title: "File")
        fileMenu.addItem(withTitle: "New Window", action: #selector(newWindow(_:)), keyEquivalent: "n")
        fileMenu.addItem(withTitle: "New Tab", action: #selector(newTab(_:)), keyEquivalent: "t")
        fileMenu.addItem(withTitle: "Open...", action: #selector(openDocument(_:)), keyEquivalent: "o")
        fileMenu.addItem(withTitle: "Save", action: #selector(microAction(_:)), keyEquivalent: "s").tag = 1
        fileMenu.addItem(.separator())
        fileMenu.addItem(withTitle: "Close Window", action: #selector(closeWindow(_:)), keyEquivalent: "w")
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit menu
        let editMenuItem = NSMenuItem()
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: #selector(microAction(_:)), keyEquivalent: "z").tag = 2
        let redo = editMenu.addItem(withTitle: "Redo", action: #selector(microAction(_:)), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        redo.tag = 3
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(microAction(_:)), keyEquivalent: "x").tag = 4
        editMenu.addItem(withTitle: "Copy", action: #selector(microAction(_:)), keyEquivalent: "c").tag = 5
        editMenu.addItem(withTitle: "Paste", action: #selector(microAction(_:)), keyEquivalent: "v").tag = 6
        editMenu.addItem(withTitle: "Select All", action: #selector(microAction(_:)), keyEquivalent: "a").tag = 7
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Duplicate Line", action: #selector(microAction(_:)), keyEquivalent: "d").tag = 8
        editMenu.addItem(withTitle: "Find...", action: #selector(microAction(_:)), keyEquivalent: "f").tag = 9
        editMenu.addItem(withTitle: "Command Palette", action: #selector(microAction(_:)), keyEquivalent: "/").tag = 10
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // View menu
        let viewMenuItem = NSMenuItem()
        let viewMenu = NSMenu(title: "View")
        viewMenu.addItem(withTitle: "Bigger", action: #selector(fontBigger(_:)), keyEquivalent: "+")
        viewMenu.addItem(withTitle: "Smaller", action: #selector(fontSmaller(_:)), keyEquivalent: "-")
        viewMenu.addItem(withTitle: "Reset Font Size", action: #selector(fontReset(_:)), keyEquivalent: "0")
        viewMenuItem.submenu = viewMenu
        mainMenu.addItem(viewMenuItem)

        // Window menu
        let windowMenuItem = NSMenuItem()
        let windowMenu = NSMenu(title: "Window")
        windowMenu.addItem(withTitle: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m")
        windowMenu.addItem(withTitle: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: "")
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        // Help menu
        let helpMenuItem = NSMenuItem()
        let helpMenu = NSMenu(title: "Help")
        helpMenu.addItem(withTitle: "Micro Editor Help", action: #selector(openMicroHelp(_:)), keyEquivalent: "?")
        helpMenu.addItem(.separator())
        for (title, topic) in [
            ("Tutorial", "tutorial"),
            ("Keybindings", "keybindings"),
            ("Default Keys", "defaultkeys"),
            ("Commands", "commands"),
            ("Options", "options"),
            ("Plugins", "plugins"),
            ("Colors & Themes", "colors"),
        ] as [(String, String)] {
            let item = helpMenu.addItem(withTitle: title, action: #selector(openHelpTopic(_:)), keyEquivalent: "")
            item.representedObject = topic
        }
        helpMenuItem.submenu = helpMenu
        mainMenu.addItem(helpMenuItem)

        NSApp.mainMenu = mainMenu
        NSApp.windowsMenu = windowMenu
        NSApp.helpMenu = helpMenu
    }

    // MARK: - Menu Actions

    @objc func newWindow(_ sender: Any?) {
        createWindow(filePaths: [], workingDirectory: nil)
    }

    @objc func newTab(_ sender: Any?) {
        activeWindowController?.ipc.send("action AddTab")
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        if let wc = activeWindowController {
            for url in panel.urls {
                wc.openFile(url.path)
            }
        } else {
            createWindow(filePaths: panel.urls.map(\.path), workingDirectory: nil)
        }
    }

    @objc func closeWindow(_ sender: Any?) {
        activeWindowController?.sendCtrlQ()
    }

    @objc func fontBigger(_ sender: Any?) {
        activeWindowController?.changeFontSize(delta: 1)
    }

    @objc func fontSmaller(_ sender: Any?) {
        activeWindowController?.changeFontSize(delta: -1)
    }

    @objc func fontReset(_ sender: Any?) {
        let font = NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
        FontSettings.save(name: font.fontName, size: 14)
        for wc in windowControllers { wc.applyFont(font) }
    }

    @objc func microAction(_ sender: NSMenuItem) {
        let actions = [
            1: "Save", 2: "Undo", 3: "Redo",
            4: "Cut", 5: "Copy", 6: "Paste", 7: "SelectAll",
            8: "DuplicateLine", 9: "Find", 10: "CommandMode",
        ]
        if let action = actions[sender.tag] {
            activeWindowController?.ipc.send("action \(action)")
        }
    }

    @objc func showPreferences(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.onSettingChanged = { [weak self] key, value in
            // Broadcast settings to ALL instances
            self?.windowControllers.forEach { $0.setSetting(key: key, value: value) }
        }
        preferencesWindow?.onFontChanged = { [weak self] font in
            self?.windowControllers.forEach { $0.applyFont(font) }
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func openMicroHelp(_ sender: Any?) {
        activeWindowController?.ipc.send("action ToggleHelp")
    }

    @objc func openHelpTopic(_ sender: NSMenuItem) {
        guard let topic = sender.representedObject as? String else { return }
        activeWindowController?.ipc.send("help \(topic)")
    }
}
