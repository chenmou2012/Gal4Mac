import AppKit
import SwiftUI

@main
struct Gal4MacApp: App {
    @StateObject private var library = LibraryViewModel()

    var body: some Scene {
        WindowGroup("Gal4Mac") {
            ContentView()
                .environmentObject(library)
                .frame(minWidth: 840, minHeight: 580)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .sidebar) {
                Button(NSApp.keyWindow?.styleMask.contains(.fullScreen) == true ? "退出全屏" : "进入全屏") {
                    NSApp.keyWindow?.toggleFullScreen(nil)
                }
                .keyboardShortcut("f", modifiers: [.control, .command])
            }
            CommandGroup(replacing: .newItem) {
                Button("导入游戏…") { library.showingImportWizard = true }
                    .keyboardShortcut("o", modifiers: .command)
            }
            CommandMenu("游戏库") {
                Button("重新扫描") { library.scan() }
                    .keyboardShortcut("r", modifiers: .command)
                    .disabled(library.isScanning)
            }
        }
    }
}
