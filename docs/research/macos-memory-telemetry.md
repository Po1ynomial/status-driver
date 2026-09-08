# macOS memory telemetry

## Question

Which unprivileged macOS counters can support a continuous whole-system memory terrain metric?

## Findings

- `host_statistics64` with `HOST_VM_INFO64` exposes free, active, inactive, wired, purgeable, speculative, compressor, file-backed, and anonymous page counts.
- `sysctl hw.memsize` reports total physical bytes. The target Mac reported 17,179,869,184 bytes.
- The target uses 16,384-byte VM pages.
- `vm_stat` identifies `external_page_count` as file-backed pages and `internal_page_count` as anonymous pages.
- `memory_pressure` reports a continuous-looking free percentage, but the public dispatch memory-pressure API exposes categorical normal, warning, and critical states rather than that percentage.
- `top` physical-memory usage includes cache and therefore differs from the project's reclaimability-aware metric.

## Chosen calculation

```text
app pages = max(0, internal_page_count - purgeable_count)
used pages = app pages + wire_count + compressor_page_count
memory value = clamp(used pages / physical pages, 0, 1)
```

This excludes reclaimable file-backed and purgeable pages, includes wired and compressed physical pages, and excludes swap.

## Evidence

Local SDK headers:

- `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/host_info.h` defines `HOST_VM_INFO64`.
- `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/vm_statistics.h` documents VM page counters, including internal, external, wired, purgeable, and compressor pages.
- `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/dispatch/source.h` documents categorical system memory-pressure events.

Local commands used for inspection:

```text
sysctl -n hw.memsize
vm_stat
memory_pressure
top -l 1 -n 0
```

## Confidence and limitations

Confidence is high that the required counters and total physical memory are available without privilege on the target Mac. Confidence is moderate that this is the most useful single continuous memory value. macOS memory accounting is nuanced, and Activity Monitor's exact calculation is not a promised public API.

The metric is therefore defined by this project rather than described as exact Activity Monitor parity. Implementation still needs a live Mach smoke check, overflow-safe arithmetic tests, and comparison against current command output.

## Relevance

These findings support memory as a second normalized terrain channel while explaining why file cache, memory-pressure categories, and swap remain outside its percentage.
