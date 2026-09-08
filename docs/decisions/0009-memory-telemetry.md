# 0009 - Estimate reclaimability-aware used memory

- **Status:** Accepted
- **Date:** 2026-09-07

## Decision

Add whole-system memory as the second genuine metric. Read `vm_statistics64` through the unprivileged Mach `HOST_VM_INFO64` host statistic and read physical memory size from `hw.memsize`.

Calculate the normalized metric as:

```text
app pages = max(0, internal_page_count - purgeable_count)
used pages = app pages + wire_count + compressor_page_count
memory value = used pages / physical pages
```

Clamp intermediate arithmetic and the final result to `0...1`. Apply an independent time-aware exponential moving average with the same roughly 0.75-second time constant used for CPU.

Collect CPU and memory concurrently every 150 ms. Keep their acquisition, smoothing, availability, and history independent.

## Rationale

A simple `total - free` calculation treats macOS file cache as unavailable memory and tends to remain near 100 percent. Excluding file-backed cache and purgeable pages better represents memory the system cannot reclaim immediately. Wired and compressed pages still occupy physical RAM and belong in the used estimate. Swap does not.

The public memory-pressure notification API provides categorical states rather than the continuous normalized value terrain requires. The accepted formula is explicit and inspectable, even though it does not claim byte-for-byte parity with Activity Monitor's private accounting.

Concurrent collection keeps both values current and avoids a new baseline or flat prefill when selection changes.

## Consequences

- The label is `MEMORY`, not `memory pressure`.
- Internal raw VM fields remain available for later breakdown UI.
- Memory may form flatter terrain than CPU because its value changes more slowly.
- File cache, purgeable pages, and swap do not raise this metric.
- VM read failure does not affect CPU availability.
- Full memory breakdown, pressure states, and swap display remain deferred.
