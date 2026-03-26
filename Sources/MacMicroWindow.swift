import AppKit

class MacMicroWindow: NSWindow {

    /// IPC for this window's micro instance. Set by the window controller.
    var ipc: MicroIPC?

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleShortcut(event) {
            return
        }
        super.sendEvent(event)
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        guard let ipc = ipc else { return false }
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let chars = event.charactersIgnoringModifiers else { return false }

        // Cmd+Shift+]/[ — tab navigation
        if flags == [.command, .shift] {
            switch chars {
            case "]", "}": ipc.send("action NextTab"); return true
            case "[", "{": ipc.send("action PreviousTab"); return true
            default: break
            }
        }

        // Cmd+1-9 — tab switch
        if flags == .command, let digit = chars.first, digit >= "1", digit <= "9" {
            ipc.send("tabswitch \(digit)")
            return true
        }

        return false
    }
}
