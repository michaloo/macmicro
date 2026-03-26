import Foundation

/// Sends commands to the micro instance via the macmicro plugin.
/// Commands are written to a file that the plugin polls.
final class MicroIPC: Sendable {

    static let shared = MicroIPC()

    // nonisolated(unsafe) because all access is serialized through `queue`
    nonisolated(unsafe) private var pendingCommands: [String] = []
    nonisolated(unsafe) private var isWriting = false

    private let commandFilePath: String
    private let queue = DispatchQueue(label: "com.macmicro.ipc")

    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacMicro")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        commandFilePath = dir.appendingPathComponent("commands.pipe").path
        clearStaleCommands()
    }

    /// Remove any leftover command file from a previous session.
    func clearStaleCommands() {
        try? FileManager.default.removeItem(atPath: commandFilePath)
    }

    /// Send a command to the micro plugin.
    func send(_ command: String) {
        queue.async { [weak self] in
            self?.pendingCommands.append(command)
            self?.flush()
        }
    }

    /// Send multiple commands.
    func send(_ commands: [String]) {
        queue.async { [weak self] in
            self?.pendingCommands.append(contentsOf: commands)
            self?.flush()
        }
    }

    private func flush() {
        guard !isWriting, !pendingCommands.isEmpty else { return }
        isWriting = true

        let commands = pendingCommands.joined(separator: "\n") + "\n"
        pendingCommands.removeAll()

        // Atomic write: write to temp file then rename
        let tmpPath = commandFilePath + ".tmp"
        do {
            try commands.write(toFile: tmpPath, atomically: false, encoding: .utf8)
            try FileManager.default.moveItem(atPath: tmpPath, toPath: commandFilePath)
        } catch {
            // If rename fails (target exists), append instead
            if let handle = FileHandle(forWritingAtPath: commandFilePath) {
                handle.seekToEndOfFile()
                handle.write(commands.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? commands.write(toFile: commandFilePath, atomically: true, encoding: .utf8)
            }
        }

        // Small delay before next flush to let plugin read
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.queue.async {
                self?.isWriting = false
                if !(self?.pendingCommands.isEmpty ?? true) {
                    self?.flush()
                }
            }
        }
    }
}
