# 0017 - Use best-effort IOKit GPU utilization

- **Status:** Accepted
- **Date:** 2026-09-09

## Decision

Add a GPU resource when an IOKit graphics registry entry contains `PerformanceStatistics` with `Device Utilization %`. Treat these property names as an experimental dependency on the current Mac rather than a stable compatibility promise.

Normalize Device Utilization from `0...100` into fixed `0...1` GPU terrain. Apply the existing 0.75-second filter and immutable one-second physical history. Clamp invalid values and preserve stale terrain with unavailable status after failure. Re-discover the registry service every five seconds while missing or unavailable.

Show Renderer Utilization and Tiler Utilization as secondary detail values when present. Show `In use system memory` as a best-effort detail when present. Show Metal support and unified-memory type as adapted metadata.

Do not show a GPU memory graph, fixed dedicated/shared capacity ratio, frequency, temperature, power, DirectX data, PCI location, driver date, or Windows driver version.

Hide the GPU row at launch if Device Utilization is absent. Once discovered, keep a failing selected GPU row unavailable under the general resource rules.

## Rationale

The target M4 exposes Device, Renderer, and Tiler utilization plus in-use system memory without privilege. `powermetrics` requires root, and Metal performance counters measure only this application's command buffers.

The registry property names are observable but not a documented compatibility contract. The project's current-Mac and best-effort constraints permit their use as long as absence is handled cleanly.

Unified memory has no fixed GPU partition equivalent to Windows shared GPU memory. Omitting that graph is more honest than presenting installed RAM as a GPU limit.

## Consequences

- GPU availability may change after macOS updates.
- GPU tests require injected registry dictionaries plus a live current-host smoke check.
- No row appears on systems lacking the required property.
- GPU uses a cyan-blue identity distinct from CPU blue.
