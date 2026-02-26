import Foundation

struct ReleaseInfo: Hashable {
    let tag: String
    let version: String
    let name: String
    let publishedAt: Date?
    let releaseURL: URL
    let dmgAssetURL: URL?
    let dmgAssetName: String?
}

enum UpdateCheckResult: Hashable {
    case upToDate
    case updateAvailable(ReleaseInfo)
    case noStableRelease
    case networkError(String)
}
