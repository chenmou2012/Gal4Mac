import AppKit
import SwiftUI

@main
struct Gal4MacApp: App {
    @StateObject private var library = LibraryViewModel()

    init() {
        // swift run 启动的可执行文件没有应用包，需要手动设为前台应用才会显示窗口。
        NSApplication.shared.setActivationPolicy(.regular)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    var body: some Scene {
        WindowGroup("Gal4Mac") {
            ContentView()
                .environmentObject(library)
                .frame(minWidth: 760, minHeight: 520)
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
