import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {

    /// If another instance is already running, activate it and terminate this one.
    func applicationWillFinishLaunching(_ notification: Notification) {
        let bundleID = Bundle.main.bundleIdentifier ?? ""
        let others = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
            .filter { $0 != NSRunningApplication.current }

        if let existing = others.first {
            existing.activate(options: .activateIgnoringOtherApps)
            NSApp.terminate(nil)
        }
    }

    /// Dock icon clicked while app is already running — just bring the window forward.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        sender.windows.first(where: \.isKeyWindow)?.makeKeyAndOrderFront(nil)
            ?? sender.windows.first?.makeKeyAndOrderFront(nil)
        return false
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }
}
