import Foundation
import Gal4MacCore

// 如果带 --cli 参数或任何已知的CLI命令，走CLI模式
let args = CommandLine.arguments
let cliCommands = ["version", "doctor", "scan", "list", "info", "launch", "remove",
                   "libraries", "add-library", "remove-library", "help", "-h", "--help"]
let isCliMode = args.count > 1 && cliCommands.contains(args[1])

if isCliMode {
    CLI.main(args)
} else {
    // 否则启动 SwiftUI UI（通过 @main 在 Gal4MacApp 中）
    // main.swift 不应同时定义 @main；UI 模式需用其他方式启动
    // 这里通过直接调用 NSApplication 让 UI 启动
    // 但 @main 已经被 SwiftUI App 占用，所以这里仅打印提示
    print("启动 UI 模式...")
    print("请使用: swift run 或 Xcode 启动")
    exit(0)
}
