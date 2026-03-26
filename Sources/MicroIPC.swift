import Foundation

/// Sends commands to a micro instance via the macmicro plugin.
/// Each instance gets its own command file identified by a unique ID.
final class MicroIPC: Sendable {

    let instanceID: String
    let commandFilePath: String

    // nonisolated(unsafe) because all access is serialized through `queue`
    nonisolated(unsafe) private var pendingCommands: [String] = []
    nonisolated(unsafe) private var isWriting = false

    private let queue = DispatchQueue(label: "com.macmicro.ipc")

    init(instanceID: String = UUID().uuidString) {
        self.instanceID = instanceID
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacMicro")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        commandFilePath = dir.appendingPathComponent("commands-\(instanceID).pipe").path
        clearStaleCommands()
    }

    func clearStaleCommands() {
        try? FileManager.default.removeItem(atPath: commandFilePath)
    }

    func send(_ command: String) {
        queue.async { [weak self] in
            self?.pendingCommands.append(command)
            self?.flush()
        }
    }

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

        let tmpPath = commandFilePath + ".tmp"
        do {
            try commands.write(toFile: tmpPath, atomically: false, encoding: .utf8)
            try FileManager.default.moveItem(atPath: tmpPath, toPath: commandFilePath)
        } catch {
            if let handle = FileHandle(forWritingAtPath: commandFilePath) {
                handle.seekToEndOfFile()
                handle.write(commands.data(using: .utf8)!)
                handle.closeFile()
            } else {
                try? commands.write(toFile: commandFilePath, atomically: true, encoding: .utf8)
            }
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.queue.async {
                self?.isWriting = false
                if !(self?.pendingCommands.isEmpty ?? true) {
                    self?.flush()
                }
            }
        }
    }

    /// Clean up all stale command files from previous sessions.
    static func cleanupAll() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("MacMicro")
        guard let files = try? FileManager.default.contentsOfDirectory(atPath: dir.path) else { return }
        for file in files where file.hasPrefix("commands-") && file.hasSuffix(".pipe") {
            try? FileManager.default.removeItem(atPath: dir.appendingPathComponent(file).path)
        }
    }
}
