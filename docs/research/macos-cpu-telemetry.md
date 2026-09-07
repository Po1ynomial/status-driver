# macOS aggregate CPU telemetry

## Question

Can Status Driver read normalized whole-system CPU activity on the owner's Mac without permissions or full Xcode?

## Findings

- The macOS SDK exposes `HOST_CPU_LOAD_INFO` through `host_statistics`.
- The returned aggregate counters are user, system, idle, and nice CPU ticks.
- Utilization requires two snapshots and uses non-idle tick deltas divided by all tick deltas.
- The call succeeded from an ordinary Swift script without a permission prompt or entitlement.
- The counters use `natural_t`, so implementation should use wrapping subtraction.

## Evidence

Local SDK headers:

- `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/host_info.h` defines `HOST_CPU_LOAD_INFO`.
- `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/mach_host.h` declares `host_statistics` and `host_statistics64`.
- `/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk/usr/include/mach/machine.h` maps CPU states as user `0`, system `1`, idle `2`, and nice `3`.

A local Swift 6.3 probe took two `HOST_CPU_LOAD_INFO` snapshots 200 ms apart on macOS 26.2. It returned:

```text
result=KERN_SUCCESS deltaTicks=201 utilization=0.03980099502487562
```

## Method and environment

- Apple Swift 6.3 from Command Line Tools.
- macOS 26.2 on arm64.
- Called `host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, ...)` from an unsigned Swift script.
- Waited 200 ms, took a second snapshot, and calculated aggregate busy and total deltas.

## Confidence and limitations

Confidence is high for API availability and unprivileged access on the target machine. The probe only establishes current-host behavior. It did not test sandboxed distribution, older macOS releases, counter rollover, sustained sampling overhead, or sleep and wake behavior.

## Relevance

This supports using aggregate CPU utilization as the first real terrain source and identifies the counter math that needs isolated automated checks.
