import SwiftUI
import Gal4MacCore

@main
struct Gal4MacApp: App {
    @StateObject private var library = GameLibraryViewModel()

    var body: some Scene {
        WindowGroup("Gal4Mac") {
            ContentView()
                .environmentObject(library)
                .frame(minWidth: 800, minHeight: 500)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandMenu("游戏") {
                Button("重新扫描") {
                    library.scanAll()
                }
                .keyboardShortcut("r", modifiers: .command)
                Divider()
                Button("添加库路径…") {
                    library.showingAddLibrary = true
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
}
