import Foundation

/// Watches one or more directories for file-system changes and calls `onChange`
/// with a debounce of 500 ms.
final class FileWatcher {

    private var sources: [DispatchSourceFileSystemObject] = []
    private var debounceWorkItem: DispatchWorkItem?
    private let queue = DispatchQueue(label: "com.skill-mt.filewatcher", qos: .utility)
    private let debounceDelay: TimeInterval

    var onChange: (() -> Void)?

    init(debounceDelay: TimeInterval = 0.5) {
        self.debounceDelay = debounceDelay
    }

    deinit {
        stopAll()
    }

    // MARK: - Public API

    func watch(urls: [URL]) {
        stopAll()
        for url in urls {
            startWatching(url: url)
        }
    }

    func stopAll() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
    }

    // MARK: - Private

    private func startWatching(url: URL) {
        guard FileManager.default.fileExists(atPath: url.path) else { return }

        let fd = open(url.path, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete, .link],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            self?.scheduleOnChange()
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        sources.append(source)
    }

    private func scheduleOnChange() {
        debounceWorkItem?.cancel()
        let work = DispatchWorkItem { [weak self] in
            DispatchQueue.main.async {
                self?.onChange?()
            }
        }
        debounceWorkItem = work
        queue.asyncAfter(deadline: .now() + debounceDelay, execute: work)
    }
}
