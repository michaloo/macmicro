import Foundation

// macmicro CLI — opens files in MacMicro.app
// Usage: macmicro [--wait] [file ...]
//   --wait: block until the file is closed (for EDITOR/VISUAL usage)

let args = CommandLine.arguments.dropFirst()
let waitMode = args.contains("--wait")
let files = args.filter { $0 != "--wait" }

// Resolve file paths to absolute
let absolutePaths = files.map { path -> String in
    if path.hasPrefix("/") { return path }
    let cwd = FileManager.default.currentDirectoryPath
    return URL(fileURLWithPath: cwd).appendingPathComponent(path).standardized.path
}

// Find MacMicro.app — check common locations
func findApp() -> String? {
    let candidates = [
        "/Applications/MacMicro.app",
        "\(NSHomeDirectory())/Applications/MacMicro.app",
        // Check relative to CLI binary location (inside app bundle)
        URL(fileURLWithPath: CommandLine.arguments[0])
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent().path,
    ]
    for path in candidates {
        if path.hasSuffix(".app") && FileManager.default.fileExists(atPath: path) {
            return path
        }
    }
    return nil
}

guard let appPath = findApp() else {
    fputs("error: MacMicro.app not found. Install it to /Applications.\n", stderr)
    exit(1)
}

if !waitMode {
    // Simple mode: open and exit immediately
    let proc = Process()
    proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
    proc.arguments = ["-a", appPath] + absolutePaths
    try proc.run()
    proc.waitUntilExit()
    exit(proc.terminationStatus)
}

// Wait mode: open the file, then poll until it's no longer open in micro
// We use a signal file that gets created on open and deleted on close

let signalDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    .appendingPathComponent("MacMicro")
let signalFile = signalDir.appendingPathComponent("wait-\(ProcessInfo.processInfo.processIdentifier)")
try? FileManager.default.createDirectory(at: signalDir, withIntermediateDirectories: true)

// Create the signal file
FileManager.default.createFile(atPath: signalFile.path, contents: nil)

// Open the files in MacMicro
let proc = Process()
proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
proc.arguments = ["-a", appPath] + absolutePaths
try proc.run()
proc.waitUntilExit()

// Poll until MacMicro removes the signal file or the app quits
// For now, use a simpler approach: watch if the file is still open in any micro process
// We poll by checking if MacMicro is still running with these files

// Simple approach: watch if MacMicro.app is running, and if our files are still open
// by checking the micro process list
func isMacMicroRunning() -> Bool {
    let task = Process()
    task.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
    task.arguments = ["-f", "MacMicro"]
    let pipe = Pipe()
    task.standardOutput = pipe
    task.standardError = pipe
    try? task.run()
    task.waitUntilExit()
    return task.terminationStatus == 0
}

// For EDITOR usage, we just need to wait until MacMicro quits
// (the user closes the window/tab with the file)
// Poll every 500ms
signal(SIGINT) { _ in
    try? FileManager.default.removeItem(at: signalFile)
    exit(0)
}
signal(SIGTERM) { _ in
    try? FileManager.default.removeItem(at: signalFile)
    exit(0)
}

while isMacMicroRunning() {
    Thread.sleep(forTimeInterval: 0.5)
}

try? FileManager.default.removeItem(at: signalFile)
exit(0)
