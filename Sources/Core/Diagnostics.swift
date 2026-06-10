import Foundation
import OSLog

enum Diagnostics {
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "com.sshhh.app",
        category: "Diagnostics"
    )

    private static let fileLock = NSLock()
    private static var didConfigureFile = false
    private static var fileHandle: FileHandle?

    static func log(_ message: String) {
        logger.debug("\(message, privacy: .public)")

        let line = "[DIAG \(Date())] \(message)\n"
        guard let data = line.data(using: .utf8) else {
            return
        }

        fileLock.lock()
        defer { fileLock.unlock() }

        guard let handle = configuredFileHandleLocked() else {
            return
        }

        handle.seekToEndOfFile()
        handle.write(data)
    }

    private static func configuredFileHandleLocked() -> FileHandle? {
        if didConfigureFile {
            return fileHandle
        }

        didConfigureFile = true

        let path = ProcessInfo.processInfo.environment["SSHHH_DIAG_LOG_PATH"]
            ?? UserDefaults.standard.string(forKey: "DiagnosticLogPath")

        guard let path, !path.isEmpty else {
            return nil
        }

        FileManager.default.createFile(atPath: path, contents: Data())
        guard let handle = FileHandle(forWritingAtPath: path) else {
            return nil
        }

        handle.truncateFile(atOffset: 0)
        fileHandle = handle
        return handle
    }
}

func diag(_ message: String) {
    Diagnostics.log(message)
}
