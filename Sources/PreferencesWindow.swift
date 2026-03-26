import AppKit

class PreferencesWindow: NSWindowController, NSSearchFieldDelegate {

    var onSettingChanged: ((String, String) -> Void)?

    private var allOptions: [MicroOption] = []
    private var filteredOptions: [MicroOption] = []
    private var controls: [String: NSView] = [:]
    private var scrollView: NSScrollView!
    private var containerView: NSView!
    private var searchField: NSSearchField!

    // Options that render as dropdowns
    private let choices: [String: [String]] = [
        "colorscheme": [
            "default", "monokai", "atom-dark", "bubblegum", "cmc-16",
            "darcula", "dracula-tc", "dukedark-tc", "dukelight-tc",
            "geany", "gruvbox", "gruvbox-tc", "material-tc",
            "railscast", "simple", "solarized", "solarized-tc",
            "twilight", "zenburn",
        ],
        "matchbracestyle": ["underline", "highlight"],
        "helpsplit": ["hsplit", "vsplit"],
        "reload": ["prompt", "auto", "disabled"],
    ]

    // Options to hide (managed by MacMicro, internal, or not useful in GUI)
    private let hiddenOptions: Set<String> = [
        // Managed by MacMicro's embedded terminal
        "clipboard",        // SwiftTerm handles clipboard via macOS pasteboard
        "useprimary",       // Unix primary clipboard — not relevant on macOS app
        "truecolor",        // We set MICRO_TRUECOLOR=1 in the environment
        "xterm",            // We set TERM=xterm-256color
        "fakecursor",       // Terminal cursor managed by SwiftTerm
        "mouse",            // Mouse events managed by SwiftTerm
        // Internal / per-buffer / not settable globally
        "filetype",         // Auto-detected per buffer
        "fileformat",       // Auto-detected per buffer
        "readonly",         // Per-buffer only (setlocal)
        "paste",            // Temporary flag, not a preference
        "encoding",         // Rarely changed, per-buffer
        // Plugin infrastructure
        "pluginchannels",   // JSON array, not editable in simple UI
        "pluginrepos",      // JSON array, not editable in simple UI
        // Format strings / characters (too complex for simple UI)
        "statusformatl",
        "statusformatr",
        "divchars",
        "indentchar",
        "showchars",
        "scrollbarchar",
        // System commands
        "sucmd",            // sudo/doas — system-level, not an editor pref
        // Managed by MacMicro wrapper
        "multiopen",        // We handle multi-file via tab command
    ]

    // Friendly labels for options shown in the UI
    private let labels: [String: String] = [
        "autoindent": "Auto-indent",
        "autosave": "Auto-save interval (seconds, 0=off)",
        "autosu": "Auto sudo on save",
        "autoclose": "Auto-close brackets/quotes",
        "backup": "Create backups",
        "backupdir": "Backup directory",
        "basename": "Show only filename in tabs",
        "colorcolumn": "Color column position (0=off)",
        "colorscheme": "Color scheme",
        "comment": "Comment plugin",
        "cursorline": "Highlight cursor line",
        "detectlimit": "Filetype detection line limit",
        "diff": "Git diff plugin",
        "diffgutter": "Show diff gutter",
        "divreverse": "Reverse divider colors",
        "eofnewline": "Ensure newline at end of file",
        "fastdirty": "Fast dirty detection",
        "ftoptions": "Filetype-specific options plugin",
        "helpsplit": "Help split direction",
        "hlsearch": "Highlight search results",
        "hltaberrors": "Highlight tab errors",
        "hltrailingws": "Highlight trailing whitespace",
        "ignorecase": "Case-insensitive search",
        "incsearch": "Incremental search",
        "infobar": "Show info bar",
        "keepautoindent": "Keep auto-indent whitespace",
        "keymenu": "Show key menu (nano-style)",
        "linter": "Linter plugin",
        "literate": "Literate plugin",
        "lockbindings": "Lock key bindings",
        "matchbrace": "Highlight matching braces",
        "matchbraceleft": "Match brace to the left",
        "matchbracestyle": "Brace match style",
        "mkparents": "Create parent directories on save",
        "pageoverlap": "Page scroll overlap lines",
        "parsecursor": "Parse cursor position from filename",
        "permbackup": "Permanent backups",
        "relativeruler": "Relative line numbers",
        "reload": "File reload behavior",
        "rmtrailingws": "Remove trailing whitespace on save",
        "ruler": "Show line numbers",
        "savecursor": "Remember cursor position",
        "savehistory": "Remember command history",
        "saveundo": "Persistent undo history",
        "scrollbar": "Show scrollbar",
        "scrollmargin": "Scroll margin (lines)",
        "scrollspeed": "Scroll speed (lines)",
        "smartpaste": "Smart paste with indentation",
        "softwrap": "Soft wrap long lines",
        "splitbottom": "New horizontal splits below",
        "splitright": "New vertical splits to right",
        "status": "Status plugin (git info)",
        "statusline": "Show status line",
        "syntax": "Syntax highlighting",
        "tabhighlight": "Highlight active tab",
        "tabmovement": "Navigate spaces as tabs",
        "tabreverse": "Reverse tab bar colors",
        "tabsize": "Tab size",
        "tabstospaces": "Use spaces instead of tabs",
        "wordwrap": "Wrap at word boundaries",
    ]

    init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 550),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "MacMicro Settings"
        window.isReleasedWhenClosed = false
        window.minSize = NSSize(width: 400, height: 300)

        super.init(window: window)
        setupUI()
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError() }

    override func showWindow(_ sender: Any?) {
        reloadOptions()
        super.showWindow(sender)
    }

    // MARK: - Setup

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        searchField = NSSearchField(frame: .zero)
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.placeholderString = "Filter settings…"
        searchField.delegate = self
        searchField.target = self
        searchField.action = #selector(filterChanged(_:))
        contentView.addSubview(searchField)

        scrollView = NSScrollView(frame: .zero)
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        containerView = NSView()
        containerView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.documentView = containerView
        contentView.addSubview(scrollView)

        NSLayoutConstraint.activate([
            searchField.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 12),
            searchField.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            searchField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),

            scrollView.topAnchor.constraint(equalTo: searchField.bottomAnchor, constant: 8),
            scrollView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),

            containerView.leadingAnchor.constraint(equalTo: scrollView.contentView.leadingAnchor),
            containerView.trailingAnchor.constraint(equalTo: scrollView.contentView.trailingAnchor),
        ])
    }

    // MARK: - Load & Render

    private func reloadOptions() {
        allOptions = MicroConfig.loadAllOptions()
            .filter { !hiddenOptions.contains($0.key) }
            .sorted { $0.key < $1.key }
        filterChanged(nil)
    }

    @objc private func filterChanged(_ sender: Any?) {
        let query = searchField.stringValue.lowercased()
        if query.isEmpty {
            filteredOptions = allOptions
        } else {
            filteredOptions = allOptions.filter {
                $0.key.lowercased().contains(query) ||
                (labels[$0.key]?.lowercased().contains(query) ?? false)
            }
        }
        rebuildControls()
    }

    private func rebuildControls() {
        containerView.subviews.forEach { $0.removeFromSuperview() }
        controls.removeAll()

        let width: CGFloat = 500
        let padding: CGFloat = 16
        let rowHeight: CGFloat = 26
        let spacing: CGFloat = 4
        let labelWidth: CGFloat = 220
        let controlX = padding + labelWidth + 8
        let controlWidth = width - controlX - padding

        let totalHeight = CGFloat(filteredOptions.count) * (rowHeight + spacing) + padding * 2
        containerView.frame = NSRect(x: 0, y: 0, width: width, height: totalHeight)

        var y = totalHeight - padding - rowHeight

        for option in filteredOptions {
            let label = NSTextField(labelWithString: labels[option.key] ?? option.key)
            label.frame = NSRect(x: padding, y: y + 3, width: labelWidth, height: 18)
            label.alignment = .right
            label.font = .systemFont(ofSize: 12)
            label.lineBreakMode = .byTruncatingTail
            containerView.addSubview(label)

            let isBool = option.defaultValue == "true" || option.defaultValue == "false"

            if let choiceList = choices[option.key] {
                let popup = NSPopUpButton(frame: NSRect(x: controlX, y: y, width: controlWidth, height: 22))
                popup.font = .systemFont(ofSize: 12)
                popup.addItems(withTitles: choiceList)
                // Add current value if not in list (e.g. custom theme)
                if !choiceList.contains(option.currentValue) {
                    popup.addItem(withTitle: option.currentValue)
                }
                popup.selectItem(withTitle: option.currentValue)
                popup.identifier = NSUserInterfaceItemIdentifier(option.key)
                popup.target = self
                popup.action = #selector(popupChanged(_:))
                containerView.addSubview(popup)
                controls[option.key] = popup
            } else if isBool {
                let cb = NSButton(checkboxWithTitle: "", target: self, action: #selector(boolChanged(_:)))
                cb.frame = NSRect(x: controlX, y: y + 2, width: 22, height: rowHeight)
                cb.state = option.currentValue == "true" ? .on : .off
                cb.identifier = NSUserInterfaceItemIdentifier(option.key)
                containerView.addSubview(cb)
                controls[option.key] = cb
            } else {
                let tf = NSTextField(frame: NSRect(x: controlX, y: y + 2, width: controlWidth, height: 20))
                tf.stringValue = option.currentValue
                tf.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
                tf.identifier = NSUserInterfaceItemIdentifier(option.key)
                tf.target = self
                tf.action = #selector(textChanged(_:))
                containerView.addSubview(tf)
                controls[option.key] = tf
            }

            y -= rowHeight + spacing
        }
    }

    // MARK: - Actions

    @objc private func popupChanged(_ sender: NSPopUpButton) {
        guard let key = sender.identifier?.rawValue,
              let value = sender.titleOfSelectedItem else { return }
        onSettingChanged?(key, value)
    }

    @objc private func boolChanged(_ sender: NSButton) {
        guard let key = sender.identifier?.rawValue else { return }
        let value = sender.state == .on ? "true" : "false"
        onSettingChanged?(key, value)
    }

    @objc private func textChanged(_ sender: NSTextField) {
        guard let key = sender.identifier?.rawValue else { return }
        onSettingChanged?(key, sender.stringValue)
    }

    // MARK: - NSSearchFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        if obj.object as? NSSearchField === searchField {
            filterChanged(nil)
        }
    }
}
