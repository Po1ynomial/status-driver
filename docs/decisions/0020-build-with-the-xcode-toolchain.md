# 0020 - Build with the Xcode developer toolchain

- **Status:** Accepted
- **Date:** 2026-10-03
- **Amends:** Delivery environment in [0002](0002-prototype-platform-and-delivery.md)

## Decision

Build and run Status Driver with the Xcode developer directory selected. `xcode-select -p` must print `/Applications/Xcode.app/Contents/Developer`, and plain `swift build`, `swift run StatusDriver`, and `swift run StatusDriverModelTests` remain the only build commands.

Keep the package deployment minimum at macOS 26.0 while the development machine runs macOS 27.0, so the compiler keeps rejecting API that is newer than the declared minimum.

Do not pin `SDKROOT` to an older SDK, do not copy SwiftUI macro plugins into the Command Line Tools directory, and do not add a build wrapper script.

## Context

The macOS 27 SDK implements `SwiftUI.State` as an external macro:

```swift
@attached(accessor, names: named(init), named(get), named(set)) @attached(peer, names: prefixed(`_`), prefixed(__), prefixed(`$`)) public macro State() = #externalMacro(module: "SwiftUIMacros", type: "StateMacro")
```

The macOS 26.5 SDK declares the same symbol as a property wrapper, so no plugin was involved. The Xcode 27 Command Line Tools package ships `libObservationMacros.dylib`, `libSwiftMacros.dylib`, and the testing plugin, and no `libSwiftUIMacros.dylib`. Xcode 27 ships that plugin in `Xcode.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins/`.

With the Command Line Tools selected, `swift build` fails in `Sources/StatusDriver/TerrainView.swift` with `external macro implementation type 'SwiftUIMacros.StateMacro' could not be found for macro 'State()'; plugin for module 'SwiftUIMacros' not found`. The source is correct. The toolchain moved under it, first when the macOS 27.0 and Command Line Tools 27.0 update repointed `MacOSX.sdk` from `MacOSX26.5.sdk` to `MacOSX27.0.sdk`.

## Rationale

The project's delivery mechanism is source-run through bare Swift Package Manager commands, and selecting Xcode keeps those commands working unchanged. Xcode 27 is installed and owns the plugin, so the repair belongs in the developer directory selection rather than in the package.

A macOS 26.0 minimum costs nothing on the development machine and turns any accidental use of macOS 27-only API into a compile error.

## Consequences

- Building now requires Xcode 27 in addition to the Command Line Tools. The delivery constraint recorded in 0002 no longer holds with a Command Line Tools-only selection.
- If the developer directory is ever reset to the Command Line Tools, the build fails with a macro plugin error rather than a toolchain selection error. `SYSTEM.md` records the signature and the repair command.
- The SwiftUI `State` macro is a hard dependency of the interface target. Any future SDK that converts more SwiftUI property wrappers into macros has the same requirement, so the Xcode selection is not a one-release workaround.
- `Testing` and `XCTest` both work under the Xcode toolchain. The model checks remain an executable target by choice, not by toolchain limitation.

## Alternatives considered

- Pinning the SDK with `SDKROOT=/Library/Developer/CommandLineTools/SDKs/MacOSX26.5.sdk` builds successfully, but pairs a Swift 6.4 compiler with an older SDK and only defers the macro migration to the next SDK bump.
- Copying `libSwiftUIMacros.dylib` into the Command Line Tools plugin directory depends on a file the Command Line Tools package does not own, and the next system update discards it.
- A wrapper script that exports `DEVELOPER_DIR` adds build tooling to a project that has none, to route around a one-time environment change.

## Evidence

- `swift build --scratch-path /tmp/sd-warn-build` with the Xcode developer directory: build complete, zero warnings.
- `swift run StatusDriverModelTests`: 66/66 checks passed.
- `StatusDriver --synthetic`: alive after 12 seconds at 21 percent CPU, no crash report, one already-documented `SKView: no drawables available for rendering.` diagnostic.
- SwiftUICore `.swiftinterface` diff: `@frozen @propertyWrapper public struct State<Value>` in `MacOSX26.5.sdk` against `public macro State()` in `MacOSX27.0.sdk`.
- [TN3211: Resolving SwiftUI source incompatibilities for State and ContentBuilder](https://developer.apple.com/documentation/technotes/tn3211-resolving-swiftui-source-incompatibilities-for-state-and-contentbuilder)
