import SwiftUI

@main
struct CrateSyncApp: App {
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Serato Crates Sync", id: "main") {
            ContentView(model: model)
                .frame(minWidth: 620, minHeight: 480)
        }
        .defaultSize(width: 720, height: 560)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Réglages…") { model.isShowingSettings = true }
                    .keyboardShortcut(",")
            }
            CommandGroup(replacing: .newItem) {}
            CommandGroup(replacing: .appTermination) {
                Button("Quitter Serato Crates Sync") { model.quit() }
                    .keyboardShortcut("q")
            }
        }
    }
}
