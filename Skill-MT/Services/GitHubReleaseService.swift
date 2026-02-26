import Foundation

enum GitHubReleaseError: LocalizedError {
    case invalidResponse
    case noStableRelease
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "Invalid release response from GitHub."
        case .noStableRelease:
            return "No stable release found."
        case .decodingFailed:
            return "Failed to decode release data."
        }
    }
}

struct GitHubReleaseService {
    let owner: String
    let repo: String

    init(owner: String = "sunyifeng11111", repo: String = "Skill-MT") {
        self.owner = owner
        self.repo = repo
    }

    func fetchLatestStableRelease() async throws -> ReleaseInfo {
        let url = URL(string: "https://api.github.com/repos/\(owner)/\(repo)/releases")!
        var request = URLRequest(url: url)
        request.timeoutInterval = 20
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("Skill-MT", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw GitHubReleaseError.invalidResponse
        }

        guard let releases = try? JSONDecoder().decode([ReleaseDTO].self, from: data) else {
            throw GitHubReleaseError.decodingFailed
        }

        guard let stable = releases.first(where: { !$0.draft && !$0.prerelease }) else {
            throw GitHubReleaseError.noStableRelease
        }

        let dmg = stable.assets.first {
            $0.name.lowercased().hasSuffix(".dmg")
        }

        return ReleaseInfo(
            tag: stable.tagName,
            version: stable.tagName.replacingOccurrences(of: "^v", with: "", options: .regularExpression),
            name: stable.name ?? stable.tagName,
            publishedAt: ISO8601DateFormatter().date(from: stable.publishedAt ?? ""),
            releaseURL: URL(string: stable.htmlURL)!,
            dmgAssetURL: URL(string: dmg?.browserDownloadURL ?? ""),
            dmgAssetName: dmg?.name
        )
    }
}

private struct ReleaseDTO: Decodable {
    let tagName: String
    let name: String?
    let draft: Bool
    let prerelease: Bool
    let htmlURL: String
    let publishedAt: String?
    let assets: [ReleaseAssetDTO]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name
        case draft
        case prerelease
        case htmlURL = "html_url"
        case publishedAt = "published_at"
        case assets
    }
}

private struct ReleaseAssetDTO: Decodable {
    let name: String
    let browserDownloadURL: String

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
    }
}
