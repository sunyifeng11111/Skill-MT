import Foundation

struct AppVersionService {
    func localVersion() -> String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func localBuild() -> String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "0"
    }

    func normalizeVersion(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "^v", with: "", options: .regularExpression)
    }

    func compare(_ lhs: String, _ rhs: String) -> ComparisonResult {
        let lParts = normalizeVersion(lhs).split(separator: ".").map { Int($0) ?? 0 }
        let rParts = normalizeVersion(rhs).split(separator: ".").map { Int($0) ?? 0 }
        let count = max(lParts.count, rParts.count)

        for i in 0..<count {
            let l = i < lParts.count ? lParts[i] : 0
            let r = i < rParts.count ? rParts[i] : 0
            if l < r { return .orderedAscending }
            if l > r { return .orderedDescending }
        }
        return .orderedSame
    }
}
