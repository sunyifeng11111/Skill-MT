import Foundation

enum UpdateServiceError: LocalizedError {
    case missingDMGAsset
    case downloadFailed

    var errorDescription: String? {
        switch self {
        case .missingDMGAsset:
            return "No DMG asset found for this release."
        case .downloadFailed:
            return "Failed to download update package."
        }
    }
}

struct UpdateService {
    private let releaseService: GitHubReleaseService
    private let versionService: AppVersionService

    init(
        releaseService: GitHubReleaseService = GitHubReleaseService(),
        versionService: AppVersionService = AppVersionService()
    ) {
        self.releaseService = releaseService
        self.versionService = versionService
    }

    func checkForUpdates() async -> UpdateCheckResult {
        do {
            let latest = try await releaseService.fetchLatestStableRelease()
            let local = versionService.localVersion()
            if versionService.compare(local, latest.version) == .orderedAscending {
                return .updateAvailable(latest)
            }
            return .upToDate
        } catch GitHubReleaseError.noStableRelease {
            return .noStableRelease
        } catch {
            return .networkError(error.localizedDescription)
        }
    }

    func downloadLatestDMG(from release: ReleaseInfo) async throws -> URL {
        guard let remoteURL = release.dmgAssetURL else {
            throw UpdateServiceError.missingDMGAsset
        }

        let (tempURL, response) = try await URLSession.shared.download(from: remoteURL)
        guard let http = response as? HTTPURLResponse, (200...299).contains(http.statusCode) else {
            throw UpdateServiceError.downloadFailed
        }

        let fm = FileManager.default
        let name = release.dmgAssetName ?? "Skill-MT-update.dmg"
        let target = fm.temporaryDirectory.appendingPathComponent(name)
        if fm.fileExists(atPath: target.path) {
            try? fm.removeItem(at: target)
        }
        try fm.moveItem(at: tempURL, to: target)
        return target
    }
}
