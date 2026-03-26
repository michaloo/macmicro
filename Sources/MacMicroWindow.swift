import AppKit

class MacMicroWindow: NSWindow {

    override func sendEvent(_ event: NSEvent) {
        if event.type == .keyDown, handleShortcut(event) {
            return
        }
        super.sendEvent(event)
    }

    private func handleShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        guard let chars = event.charactersIgnoringModifiers else { return false }

        // Cmd+Shift+]/[ — tab navigation (terminal eats these before menu)
        if flags == [.command, .shift] {
            switch chars {
            case "]", "}": MicroIPC.shared.send("action NextTab"); return true
            case "[", "{": MicroIPC.shared.send("action PreviousTab"); return true
            default: break
            }
        }

        // Cmd+1-9 — tab switch (terminal eats these before menu)
        if flags == .command, let digit = chars.first, digit >= "1", digit <= "9" {
            MicroIPC.shared.send("tabswitch \(digit)")
            return true
        }

        return false
    }
}
