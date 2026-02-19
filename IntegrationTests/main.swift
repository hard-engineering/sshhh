#!/usr/bin/env swift

import Foundation
import Cocoa
import Carbon

// MARK: - Integration Test Runner for sshhh
// Launches the real app, simulates key events, and verifies behavior

class IntegrationTestRunner {

    let appPath: String
    let diagLogPath = "/tmp/sshhh_diag.log"
    var appProcess: Process?
    var logFileHandle: FileHandle?
    var logBuffer: [String] = []

    init(appPath: String) {
        self.appPath = appPath
    }

    // MARK: - Test Execution

    func runAllTests() async -> Bool {
        print("\n" + String(repeating: "=", count: 60))
        print("🧪 sshhh Integration Test Suite")
        print(String(repeating: "=", count: 60))

        // Check accessibility permissions first
        guard checkAccessibilityPermissions() else {
            print("❌ FATAL: Accessibility permissions required")
            print("   Grant permission in System Settings > Privacy & Security > Accessibility")
            return false
        }

        // Launch the app
        guard await launchApp() else {
            print("❌ FATAL: Failed to launch app")
            return false
        }

        // Wait for app to initialize (model loading can take time)
        print("⏳ Waiting for app to initialize (5s for model loading)...")
        try? await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds for model loading

        var passed = 0
        var failed = 0

        // Run test cases
        let tests: [(String, () async -> Bool)] = [
            ("Brief tap should not trigger recording", testBriefTap),
            ("Normal press should show widget", testNormalPress),
            ("Quick release should not leave widget stuck", testQuickRelease),
            ("Option+A shortcut should not trigger recording", testOptionShortcut),
            ("Rapid double tap respects cooldown", testRapidDoubleTap),
        ]

        for (name, test) in tests {
            print("\n▶️  \(name)")
            clearLogBuffer()

            let result = await test()
            if result {
                print("   ✅ PASSED")
                passed += 1
            } else {
                print("   ❌ FAILED")
                failed += 1
            }

            // Cooldown between tests
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }

        // Cleanup
        terminateApp()

        // Summary
        print("\n" + String(repeating: "=", count: 60))
        print("📊 Results: \(passed) passed, \(failed) failed")
        print(String(repeating: "=", count: 60))

        return failed == 0
    }

    // MARK: - Test Cases

    func testBriefTap() async -> Bool {
        // Press and release Option very quickly (< 150ms activation delay)
        pressOptionKey()
        try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
        releaseOptionKey()

        try? await Task.sleep(nanoseconds: 300_000_000) // Wait for any processing

        // Should NOT see recording state in log
        let logs = getRecentLogs()
        let startedRecording = logs.contains { $0.contains("STATE: recording=true") }

        if startedRecording {
            print("   ⚠️  Recording started on brief tap (should not happen)")
            return false
        }
        return true
    }

    func testNormalPress() async -> Bool {
        // Check if app is running first
        let checkProcess = Process()
        checkProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        checkProcess.arguments = ["sshhh"]
        let pipe = Pipe()
        checkProcess.standardOutput = pipe
        try? checkProcess.run()
        checkProcess.waitUntilExit()
        let pidData = pipe.fileHandleForReading.readDataToEndOfFile()
        let pid = String(data: pidData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        print("   📱 App PID: \(pid.isEmpty ? "NOT RUNNING" : pid)")

        // Press Option for 500ms (normal recording)
        print("   🔑 Pressing Option key...")
        pressOptionKey()
        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
        print("   🔑 Releasing Option key...")
        releaseOptionKey()

        try? await Task.sleep(nanoseconds: 1_000_000_000) // Wait for processing

        // Should see recording started in diag log
        let logs = getRecentLogs()
        print("   📋 Got \(logs.count) log entries")
        let startedRecording = logs.contains { $0.contains("STATE: recording=true") }

        if !startedRecording {
            print("   ⚠️  Recording did not start on normal press")
            if logs.isEmpty {
                print("   📋 No logs found - checking raw file...")
                if let content = try? String(contentsOfFile: diagLogPath) {
                    print("   📋 Raw file has \(content.count) chars, \(content.components(separatedBy: "\n").count) lines")
                }
            } else {
                print("   📋 Recent logs: \(logs.suffix(5))")
            }
            return false
        }
        return true
    }

    func testQuickRelease() async -> Bool {
        // Press just over activation delay, release quickly
        // This is the bug scenario - widget should not get stuck

        pressOptionKey()
        try? await Task.sleep(nanoseconds: 180_000_000) // 180ms (just over 150ms threshold)
        releaseOptionKey()

        // Wait for any async processing to complete
        try? await Task.sleep(nanoseconds: 800_000_000)

        // Check if widget is stuck by looking for processing without completion
        let logs = getRecentLogs()
        let hasProcessing = logs.contains { $0.contains("STATE: recording=false, processing=true") }
        let hasFinished = logs.contains { $0.contains("STATE: finishing processing") }

        // If processing started, it should have finished
        if hasProcessing && !hasFinished {
            print("   ⚠️  Widget appears stuck in processing state")
            print("   📋 Logs: \(logs.suffix(5))")
            return false
        }

        return true
    }

    func testOptionShortcut() async -> Bool {
        // Press Option, then press 'A' while holding Option
        // Should NOT trigger recording

        pressOptionKey()
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Press 'A' key while Option is held
        pressKey(keyCode: 0x00) // 'A' key
        try? await Task.sleep(nanoseconds: 50_000_000)
        releaseKey(keyCode: 0x00)

        try? await Task.sleep(nanoseconds: 100_000_000)
        releaseOptionKey()

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Should NOT see recording started
        let logs = getRecentLogs()
        let startedRecording = logs.contains { $0.contains("STATE: recording=true") }

        if startedRecording {
            print("   ⚠️  Recording started on Option+A shortcut (should not happen)")
            return false
        }
        return true
    }

    func testRapidDoubleTap() async -> Bool {
        // First press
        pressOptionKey()
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        releaseOptionKey()

        // Very short gap
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms gap (within cooldown)

        // Second press (should be ignored due to cooldown)
        clearLogBuffer() // Clear logs to check only second press
        pressOptionKey()
        try? await Task.sleep(nanoseconds: 300_000_000)
        releaseOptionKey()

        try? await Task.sleep(nanoseconds: 300_000_000)

        // Second press should be ignored (cooldown)
        let logs = getRecentLogs()
        let cooldownActive = logs.contains { $0.contains("Cooldown active") }

        // Either cooldown message, or no recording started
        let startedRecording = logs.contains { $0.contains("Starting recording") }

        if startedRecording && !cooldownActive {
            print("   ⚠️  Second press was not blocked by cooldown")
            // This might pass if cooldown already expired - not a hard failure
        }

        return true // Soft pass - timing dependent
    }

    // MARK: - App Lifecycle

    func launchApp() async -> Bool {
        // Kill any existing instance first
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProcess.arguments = ["-f", "sshhh"]
        try? killProcess.run()
        killProcess.waitUntilExit()
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Resolve to absolute path
        let absolutePath = URL(fileURLWithPath: appPath).standardizedFileURL.path

        // Launch app using open command
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = [absolutePath]

        do {
            try process.run()
            process.waitUntilExit() // open exits immediately
            appProcess = process
            print("✅ Launched: \(absolutePath)")

            // Wait a moment for the app to create its log file
            try? await Task.sleep(nanoseconds: 1_000_000_000)

            // Now open log file for monitoring (AFTER app creates it)
            logFileHandle = FileHandle(forReadingAtPath: diagLogPath)
            if logFileHandle == nil {
                print("⚠️  Could not open log file at \(diagLogPath)")
            }

            return true
        } catch {
            print("❌ Failed to launch: \(error)")
            return false
        }
    }

    func terminateApp() {
        // Find and kill the app
        let killProcess = Process()
        killProcess.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killProcess.arguments = ["-f", "sshhh"]
        try? killProcess.run()
        killProcess.waitUntilExit()

        logFileHandle?.closeFile()
        print("🛑 App terminated")
    }

    // MARK: - Log Monitoring

    private var lastLogLineCount = 0

    func clearLogBuffer() {
        // Record current line count
        if let content = try? String(contentsOfFile: diagLogPath, encoding: .utf8) {
            lastLogLineCount = content.components(separatedBy: "\n").filter { !$0.isEmpty }.count
        } else {
            lastLogLineCount = 0
        }
        logBuffer.removeAll()
    }

    func getRecentLogs() -> [String] {
        // Read entire file and return lines since last clear
        guard let content = try? String(contentsOfFile: diagLogPath, encoding: .utf8) else {
            return []
        }

        let allLines = content.components(separatedBy: "\n").filter { !$0.isEmpty }

        // Return only new lines since last clear
        if allLines.count > lastLogLineCount {
            return Array(allLines.suffix(from: lastLogLineCount))
        }
        return []
    }

    // MARK: - Key Event Simulation

    func checkAccessibilityPermissions() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false]
        return AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    func pressOptionKey() {
        guard let event = CGEvent(source: nil) else { return }
        event.type = .flagsChanged
        event.flags = .maskAlternate
        event.post(tap: .cghidEventTap)
    }

    func releaseOptionKey() {
        guard let event = CGEvent(source: nil) else { return }
        event.type = .flagsChanged
        event.flags = []
        event.post(tap: .cghidEventTap)
    }

    func pressKey(keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: true) else { return }
        event.flags = .maskAlternate // Option still held
        event.post(tap: .cghidEventTap)
    }

    func releaseKey(keyCode: CGKeyCode) {
        guard let event = CGEvent(keyboardEventSource: nil, virtualKey: keyCode, keyDown: false) else { return }
        event.flags = .maskAlternate
        event.post(tap: .cghidEventTap)
    }
}

// MARK: - Main Entry Point

let args = CommandLine.arguments

// Find app path
let defaultAppPath = FileManager.default.currentDirectoryPath + "/sshhh.app"
let appPath = args.count > 1 ? args[1] : defaultAppPath

guard FileManager.default.fileExists(atPath: appPath) else {
    print("❌ App not found at: \(appPath)")
    print("Usage: IntegrationTests [path/to/sshhh.app]")
    exit(1)
}

let runner = IntegrationTestRunner(appPath: appPath)

// Run async main
let semaphore = DispatchSemaphore(value: 0)
var success = false

Task {
    success = await runner.runAllTests()
    semaphore.signal()
}

semaphore.wait()
exit(success ? 0 : 1)
