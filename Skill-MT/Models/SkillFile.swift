import Foundation

struct SkillFile: Identifiable, Hashable {
    let id: UUID
    var relativePath: String
    var fileURL: URL
    var fileSize: Int64
    var isDirectory: Bool

    init(
        id: UUID = UUID(),
        relativePath: String,
        fileURL: URL,
        fileSize: Int64,
        isDirectory: Bool
    ) {
        self.id = id
        self.relativePath = relativePath
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.isDirectory = isDirectory
    }

    /// Convenience initializer that reads file attributes from the file system.
    init(fileURL: URL, relativeTo baseURL: URL) throws {
        let resourceValues = try fileURL.resourceValues(
            forKeys: [.fileSizeKey, .isDirectoryKey]
        )
        self.id = UUID()
        let resolvedFile = (fileURL as NSURL).standardizingPath?.path ?? fileURL.path
        let resolvedBase = ((baseURL as NSURL).standardizingPath?.path ?? baseURL.path) + "/"
        self.relativePath = resolvedFile.hasPrefix(resolvedBase)
            ? String(resolvedFile.dropFirst(resolvedBase.count))
            : resolvedFile
        self.fileURL = fileURL
        self.fileSize = Int64(resourceValues.fileSize ?? 0)
        self.isDirectory = resourceValues.isDirectory ?? false
    }
}
