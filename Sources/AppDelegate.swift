import AppKit

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {

    private var windowController: MicroWindowController?
    private var preferencesWindow: PreferencesWindow?
    private lazy var theme: MicroTheme = MicroTheme.load()

    // Files received before the window is ready (e.g. during launch via Apple Events)
    private var pendingFiles: [String] = []

    // MARK: - Application Lifecycle

    func applicationDidFinishLaunching(_ notification: Notification) {
        MicroIPC.shared.clearStaleCommands()
        setupMenuBar()

        if windowController == nil {
            let files = pendingFiles.isEmpty ? [] : pendingFiles
            pendingFiles = []
            createWindow(filePaths: files)
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard let wc = windowController else { return .terminateNow }

        // QuitAll closes all buffers (prompts for each unsaved one)
        MicroIPC.shared.send("action QuitAll")
        wc.onProcessExited = { [weak self] in
            // Clean up the pipe file so no stale commands persist
            MicroIPC.shared.clearStaleCommands()
            self?.windowController = nil
            NSApp.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
        return true
    }

    // MARK: - File Opening (Finder, Open With, Dock drag-and-drop)

    func application(_ application: NSApplication, open urls: [URL]) {
        // Filter out directories — micro can't open them as files
        let paths = urls.map(\.path).filter { path in
            var isDir: ObjCBool = false
            return !FileManager.default.fileExists(atPath: path, isDirectory: &isDir) || !isDir.boolValue
        }
        guard !paths.isEmpty else { return }

        if let wc = windowController {
            for path in paths {
                wc.openFile(path)
            }
        } else {
            pendingFiles.append(contentsOf: paths)
        }
    }

    // MARK: - Window Management

    private func createWindow(filePaths: [String]) {
        let wc = MicroWindowController(theme: theme, filePaths: filePaths)
        wc.onClose = { [weak self] _ in
            self?.windowController = nil
        }
        wc.showWindow(nil)
        windowController = wc
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

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = true
        panel.canChooseFiles = true

        guard panel.runModal() == .OK else { return }

        if let wc = windowController {
            for url in panel.urls {
                wc.openFile(url.path)
            }
        } else {
            createWindow(filePaths: panel.urls.map(\.path))
        }
    }

    @objc func closeWindow(_ sender: Any?) {
        windowController?.sendCtrlQ()
    }

    @objc func showPreferences(_ sender: Any?) {
        if preferencesWindow == nil {
            preferencesWindow = PreferencesWindow()
        }
        preferencesWindow?.onSettingChanged = { [weak self] key, value in
            self?.windowController?.setSetting(key: key, value: value)
        }
        preferencesWindow?.showWindow(nil)
        preferencesWindow?.window?.makeKeyAndOrderFront(nil)
    }

    @objc func microAction(_ sender: NSMenuItem) {
        let actions = [
            1: "Save", 2: "Undo", 3: "Redo",
            4: "Cut", 5: "Copy", 6: "Paste", 7: "SelectAll",
            8: "DuplicateLine", 9: "Find", 10: "CommandMode",
        ]
        if let action = actions[sender.tag] {
            MicroIPC.shared.send("action \(action)")
        }
    }

    @objc func openMicroHelp(_ sender: Any?) {
        MicroIPC.shared.send("action ToggleHelp")
    }

    @objc func openHelpTopic(_ sender: NSMenuItem) {
        guard let topic = sender.representedObject as? String else { return }
        MicroIPC.shared.send("help \(topic)")
    }
}
