import SwiftUI

@main
struct Skill_MTApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @State private var appState = AppState()
    @State private var localization = LocalizationManager()

    var body: some Scene {
        Window("Skill-MT", id: "main") {
            ContentView(appState: appState)
                .environment(\.localization, localization)
                .environment(\.locale, localization.locale)
                .onAppear { AppAppearance.load().apply() }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified(showsTitle: true))
        .defaultSize(width: 1100, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Skill") {
                    appState.showCreateSheet = true
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            CommandGroup(after: .newItem) {
                Button("Import Skill…") {
                    appState.triggerImport()
                }
                .keyboardShortcut("i", modifiers: .command)
            }
        }
    }
}
