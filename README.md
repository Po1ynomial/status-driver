# Status Driver

A standalone macOS activity monitor. It collects real CPU, memory, disk, network, and GPU telemetry and draws it as statistical curves. Those curves also serve as terrain for a hidden layer.

This is a personal project for one machine. There is no application bundle, signing, or distribution setup, and no compatibility goal beyond the owner's Mac.

## Requirements

- macOS 27 with Xcode 27 installed and selected. `xcode-select -p` must print `/Applications/Xcode.app/Contents/Developer`. The separate Command Line Tools package cannot build the interface target, because the macOS 27 SDK implements SwiftUI's `State` as a macro and only Xcode ships the plugin it needs. `docs/SYSTEM.md` records the exact error and the one-line repair.
- Swift Package Manager from the same toolchain, currently `swift-tools-version: 6.3`. The package declares a macOS 26.0 deployment minimum and builds against the macOS 27.0 SDK.

## Build and run

```sh
swift build
swift run StatusDriver
```

Run with fixed synthetic resources instead of live telemetry:

```sh
swift run StatusDriver -- --synthetic
```

Run the model checks:

```sh
swift run StatusDriverModelTests
```

## Using it

Click a row in the sidebar to select a resource. The main graph, its color, and the detail page all follow the selection.

Easter egg: this is not merely a graphical activity monitor. Randomly press keys until you notice it, or read the docs and source code for spoilers.

## Where the rest is written down

- `docs/PROJECT.md` holds goals, users, scope, constraints, success conditions, and open questions.
- `docs/DESIGN.md` holds the current behavioral and technical design.
- `docs/SYSTEM.md` describes what is implemented, the entry points, the runtime flow, inspection commands, and limitations.
- `docs/decisions/` records settled choices with their rationale and consequences.
- `docs/research/` keeps findings and measurements that were costly to reproduce.
