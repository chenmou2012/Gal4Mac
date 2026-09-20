import SwiftUI
import Gal4MacCore
import AppKit

/// 导入单个游戏弹窗
struct ImportGameSheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var selectedURL: URL?
    @State private var detectedEngine: EngineType = .unknown
    @State private var detectedExecutable: String = ""

    private let detector = EngineDetector()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("导入游戏")
                .font(.title2.bold())

            Text("选择游戏的根目录，自动检测引擎。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                Text(selectedURL?.path ?? "未选择")
                    .font(.callout)
                    .foregroundStyle(selectedURL == nil ? .secondary : .primary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                Button("选择…") {
                    selectGame()
                }
            }

            // 检测结果
            if let url = selectedURL {
                VStack(alignment: .leading, spacing: 8) {
                    Label("检测结果", systemImage: "checkmark.seal")
                        .font(.headline)

                    HStack {
                        Text("引擎:")
                            .foregroundStyle(.secondary)
                        Text(detectedEngine.compatibility.emoji)
                        Text(detectedEngine.displayName)
                            .fontWeight(.medium)
                    }

                    if !detectedExecutable.isEmpty {
                        HStack {
                            Text("可执行文件:")
                                .foregroundStyle(.secondary)
                            Text(detectedExecutable)
                                .font(.system(.callout, design: .monospaced))
                        }
                    }

                    if detectedEngine == .unknown {
                        Text("⚠️ 未识别引擎，可能不支持")
                            .foregroundStyle(.orange)
                            .font(.callout)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("导入") {
                    if let url = selectedURL {
                        library.addGame(at: url)
                        dismiss()
                    }
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .disabled(selectedURL == nil || detectedEngine == .unknown)
            }
        }
        .padding(20)
        .frame(width: 540)
    }

    private func selectGame() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择游戏根目录"
        if panel.runModal() == .OK, let url = panel.url {
            selectedURL = url
            detectGame(at: url)
        }
    }

    private func detectGame(at url: URL) {
        detectedEngine = detector.detect(at: url)
        if let exe = detector.findExecutable(at: url, engine: detectedEngine) {
            detectedExecutable = exe
        } else {
            detectedExecutable = ""
        }
    }
}
