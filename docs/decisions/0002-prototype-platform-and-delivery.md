# 0002 - Use native frameworks and source-run delivery

- **Status:** Accepted
- **Date:** 2026-09-07
- **Amended by:** Toolchain selection in [0020](0020-build-with-the-xcode-toolchain.md)

## Decision

Build the prototype as a native SwiftUI application with an embedded SpriteKit scene. SwiftUI owns the application lifecycle. SpriteKit owns curve rendering, input, vehicle physics, and terrain collision.

Use Swift Package Manager and launch the milestone with `swift run`. Target the owner's current macOS 26.2 machine and use convenient current APIs. Do not set a backward-compatibility goal yet.

## Rationale

SpriteKit supplies the rendering and collision behavior needed to test the terrain interaction without building a physics engine. SwiftUI leaves a direct path to the later activity-monitor interface. The project is personal and only needs to run on the development machine, so compatibility and release packaging do not help answer the current prototype question.

## Consequences

- The project commits to Apple-only APIs, matching its macOS-only scope.
- The first milestone does not produce a signed or notarized application bundle.
- Running the prototype requires the source tree and Swift toolchain.
- Packaging, distribution, and support for older macOS versions remain separate future decisions.
