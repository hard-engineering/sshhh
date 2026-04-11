import Foundation

class UpdateChecker: ObservableObject {

    @Published var availableVersion: String?

    private let owner = "hard-engineering"
    private let repo = "sshhh"
    private var hasChecked = false

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkOnce() {
        guard !hasChecked else { return }
        hasChecked = true

        guard let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases/latest") else { return }

        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            guard let self, let data, error == nil else { return }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let tagName = json["tag_name"] as? String else { return }

            let remote = tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))

            if self.isNewer(remote: remote, local: self.currentVersion) {
                DispatchQueue.main.async {
                    self.availableVersion = remote
                }
            }
        }.resume()
    }

    /// Compare only major.minor.patch (first 3 numeric components).
    /// Local dev builds have a commit hash suffix (e.g. 0.2.1.97ad100) which is ignored.
    private func isNewer(remote: String, local: String) -> Bool {
        let r = semver(remote)
        let l = semver(local)
        for i in 0..<3 {
            if r[i] > l[i] { return true }
            if r[i] < l[i] { return false }
        }
        return false
    }

    private func semver(_ version: String) -> [Int] {
        let parts = version.split(separator: ".").prefix(3).compactMap { Int($0) }
        return parts + Array(repeating: 0, count: max(0, 3 - parts.count))
    }
}
