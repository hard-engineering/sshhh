import Foundation

func waitUntil(
    timeout: TimeInterval = 1.0,
    pollInterval: UInt64 = 10_000_000,
    _ condition: @escaping () -> Bool
) async -> Bool {
    let deadline = Date().addingTimeInterval(timeout)

    while Date() < deadline {
        if condition() {
            return true
        }
        try? await Task.sleep(nanoseconds: pollInterval)
    }

    return condition()
}
