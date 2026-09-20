import SwiftUI
import Gal4MacCore
import AppKit

/// 添加库路径弹窗
struct AddLibrarySheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss
    @State private var path: String = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("添加库路径")
                .font(.title2.bold())

            Text("选择包含 galgame 的根目录。\n可以是本地磁盘、外接硬盘或网络盘。")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack {
                TextField("路径", text: $path)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { addLibrary() }
                Button("选择…") {
                    selectFolder()
                }
            }

            // 预设路径快捷选择
            VStack(alignment: .leading, spacing: 4) {
                Text("快捷选择")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack {
                    ForEach(quickPaths, id: \.self) { p in
                        Button(p.lastPathComponent) {
                            path = p.path
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
            }

            Spacer()

            HStack {
                Button("取消") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("添加") { addLibrary() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
                    .disabled(path.isEmpty)
            }
        }
        .padding(20)
        .frame(width: 480)
    }

    private var quickPaths: [URL] {
        var paths: [URL] = []
        let home = FileManager.default.homeDirectoryForCurrentUser
        paths.append(home.appendingPathComponent("Games/Gal"))
        paths.append(home.appendingPathComponent("Games"))
        paths.append(home.appendingPathComponent("Downloads"))

        // 添加已挂载的外接磁盘
        if let volumes = try? FileManager.default.contentsOfDirectory(
            at: URL(fileURLWithPath: "/Volumes"),
            includingPropertiesForKeys: nil
        ) {
            paths.append(contentsOf: volumes.filter { $0.lastPathComponent != "Macintosh HD" })
        }
        return paths
    }

    private func selectFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "选择库路径"
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func addLibrary() {
        let url = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        library.addLibrary(url)
        library.scanAll()
        dismiss()
    }
}

/// 设置弹窗
struct SettingsSheet: View {
    @EnvironmentObject var library: GameLibraryViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("设置")
                .font(.title2.bold())

            // Engine 状态
            VStack(alignment: .leading, spacing: 8) {
                Label("Mythic Engine", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                if let version = EngineManager.currentVersion() {
                    Text("版本: \(version.string)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text("路径: \(EngineManager.engineDirectory.path)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // 库路径列表
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("库路径 (\(library.config.libraryPaths.count))")
                        .font(.headline)
                    Spacer()
                    Button {
                        library.showingAddLibrary = true
                    } label: {
                        Label("添加", systemImage: "plus")
                    }
                    .buttonStyle(.borderless)
                    .controlSize(.small)
                }

                if library.config.libraryPaths.isEmpty {
                    Text("未配置库路径")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 8)
                } else {
                    List {
                        ForEach(library.config.libraryPaths, id: \.self) { path in
                            HStack {
                                Image(systemName: library.isAccessible(path) ? "external.drive.connected.to.line.below" : "external.drive.badge.exclamationmark")
                                    .foregroundStyle(library.isAccessible(path) ? .green : .orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(path.lastPathComponent)
                                    Text(path.path)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                }
                                Spacer()
                                if !library.isAccessible(path) {
                                    Text("不可访问")
                                        .font(.caption2)
                                        .foregroundStyle(.orange)
                                }
                                Button {
                                    library.removeLibrary(path)
                                } label: {
                                    Image(systemName: "minus.circle")
                                }
                                .buttonStyle(.borderless)
                                .foregroundStyle(.red)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .listStyle(.bordered)
                    .frame(minHeight: 200)
                }
            }

            Spacer()

            HStack {
                Spacer()
                Button("完成") { dismiss() }
                    .keyboardShortcut(.defaultAction)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 560, height: 500)
    }
}
