# Repository Guidelines

## Project Structure & Module Organization

`Package.swift` defines three production targets: `Sources/Gal4MacCore/` holds engine detection, game launching, and library/save logic; `Sources/Gal4MacCLI/` provides the `gal4mac` command; and `Sources/Gal4MacUI/` contains the SwiftUI app. Core tests live in `Tests/Gal4MacCoreTests/`. Keep documentation in `docs/`, source assets in `Resources/`, and helper scripts in `Scripts/`. `.build/`, `dist/`, `dist-sidebar/`, and `GalLib/` contain local build output or game data; do not include them in contributions.

## Build, Test, and Development Commands

Use macOS 14 or newer with a Swift 5.9 compatible toolchain. Run commands from the repository root:

```bash
swift build                    # Compile all package targets
swift build -c release         # Produce optimized binaries
swift test                     # Run the XCTest suite
swift run Gal4MacApp           # Launch the SwiftUI app
swift run gal4mac list         # Exercise the CLI
```

Game launching requires a locally installed Mythic Engine; building and unit testing should not depend on a checked-in engine or game copy.

## Coding Style & Naming Conventions

Follow the existing Swift style: four-space indentation, `UpperCamelCase` types, `lowerCamelCase` members, and one focused type or feature per file where practical. Keep UI code in `Gal4MacUI`; put reusable behavior in `Gal4MacCore` so the CLI can share it. Prefer clear error handling and temporary test fixtures over hard-coded machine paths. There is no repository lint or formatter configuration; keep formatting consistent with adjacent files.

## Testing Guidelines

Tests use XCTest. Add behavior-focused methods named `test...` to a matching `*Tests.swift` file under `Tests/Gal4MacCoreTests/`. Use temporary directories for file-system cases and clean them up with `defer`. Run `swift test` before submitting; for game-specific compatibility changes, record manual results against `docs/TESTING_MATRIX.md`.

## Commit & Pull Request Guidelines

Recent commits use short imperative subjects, sometimes prefixed with `feat:` or a release label such as `Gal4Mac v0.2.7 - ...`. Keep each commit scoped and describe the observable change. Pull requests should explain the behavior, list verification commands and any manual game tests, link the relevant issue when one exists, and include screenshots for SwiftUI changes. Never attach proprietary game files, saves, credentials, or packaged engine binaries.
