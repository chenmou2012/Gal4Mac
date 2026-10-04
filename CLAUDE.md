# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Gal4Mac is a macOS 14+ launcher that manages Windows galgames and runs them through the Wine/GPTK build that ships with Mythic Engine. It has a SwiftUI app and a `gal4mac` CLI, both built on a shared core library. User-facing strings, docs, and most code comments are in Chinese (Simplified); keep new user-facing text consistent with that. `AGENTS.md` contains the repository contribution guidelines.

## Commands

```bash
swift build                                   # all targets (Swift 5.9 toolchain, macOS 14+)
swift test                                    # XCTest suite (Gal4MacCoreTests)
swift test --filter LibraryManagerTests       # one test class
swift test --filter LibraryManagerTests/testExtractedGameMovesIntoLibraryAndKeepsMetadata # one test method
swift run Gal4MacApp                          # SwiftUI app
swift run gal4mac doctor                      # CLI: environment check (also list/scan/launch/info/libraries/add-library)
ENGINE_DIR="$HOME/Library/Application Support/Mythic/Engine" bash Scripts/build_release.sh   # .app + DMG in dist-release/
```

The repo has no lint or formatter configuration. Building and unit tests must not depend on an installed Mythic Engine or on game files. Only `doctor` and real launches need them. The `Scripts/run_*.sh` files are early per-game validation scripts. They are not entry points. See `docs/RELEASING.md` for signing and notarization.

## Architecture

- **`Gal4MacCore`** contains all reusable logic. Put new behavior here so both the UI and the CLI can use it.
  - `Game/`: the `Game` model, `EngineDetector`, which identifies Unity, SiglusEngine, KiriKiri, TyranoScript, Ren'Py, and others from file signatures, and `GameLauncher`.
  - `Engine/`: `EngineManager` is a static API. It finds the Engine, creates a separate Wine prefix for each game under `~/Library/Application Support/Mythic/Containers/`, and handles DXVK, audio registry defaults, native `dsound.dll` installation, and running or stopping Wine. `EngineOptimizer` supplies per-engine `WineConfig`. `WineMenuFont` handles CJK font mapping.
  - `Library/`: `LibraryManager` stores JSON (`config.json` holds library paths and `library.json` holds game records) under `~/Library/Application Support/Gal4Mac/`. It does not use SwiftData. This folder also has archive extraction (`ArchiveExtractor`, which uses `unar`), online download (`Aria2Downloader`, which uses `aria2`), save archive and backup logic, and Steam cloud save import.
- **`Gal4MacCLI`** is a thin command layer (`CLI/CLI.swift`) over the core library.
- **`Gal4MacUI`** is the SwiftUI app. `LibraryViewModel` is the central state object. Steam metadata and login use `SteamWebSession`, which relies on WebKit's persistent website data.

### Launch flow
`LibraryManager` provides a `Game` record. `GameLauncher.launchConfig(for:)` picks the Wine config for the detected engine. `EngineManager` then prepares the game's prefix, applies DXVK, optimizations, audio defaults, the optional user-provided native DirectSound DLL, and font mapping, and starts Wine. The audio defaults are reapplied on every launch. The UI writes the launch state and play time back to the library.

### Engine location
`EngineManager.engineDirectory` first checks for `Bundle.main.resourceURL/Engine`. That copy must contain both `wine/bin/wine64` and `Properties.plist`. `build_release.sh` places it there when `ENGINE_DIR` is set. Otherwise `EngineManager` falls back to `~/Library/Application Support/Mythic/Engine/`. As a result, `swift run` and the CLI always use the locally installed Mythic Engine.

### Testability
Tests avoid the real Application Support directory. For example, `LibraryManager(storageDirectory:)` takes a temporary directory, and internal `static` helpers such as `EngineManager.winePrefix(for:in:)` take an explicit base URL. Follow the same approach: use temporary directories cleaned up with `defer`, and never hard-code machine paths.

## Constraints

- Only Aokana (32-bit Unity) and CLANNAD (SiglusEngine) have been verified by hand. Detecting an engine does not mean the game is compatible. Record game-specific compatibility testing in `docs/TESTING_MATRIX.md`. Known failures are recorded in `docs/FAILURE_HISTORY.md`.
- Never commit games, saves, Engine binaries, or Windows DLLs. `.build/`, `dist*/`, and `GalLib/` are local output or game data.
- Commits use short imperative subjects, sometimes prefixed with `feat:`.
