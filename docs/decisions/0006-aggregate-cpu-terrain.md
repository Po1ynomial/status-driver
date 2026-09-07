# 0006 - Use aggregate CPU utilization for genuine terrain

- **Status:** Accepted; amended after runtime inspection
- **Date:** 2026-09-07

## Decision

Use whole-system CPU utilization as the first genuine terrain metric. Read cumulative user, system, idle, and nice ticks with the Mach `HOST_CPU_LOAD_INFO` host statistic.

Calculate utilization between consecutive successful reads as:

```text
busy = delta(user) + delta(system) + delta(nice)
total = busy + delta(idle)
utilization = busy / total
```

Use wrapping counter subtraction and clamp the result to `0...1`. A value of `1.0` means all logical CPUs are busy. Include Status Driver's own CPU work in the system total.

If a successful snapshot has no changed ticks, reuse the last filtered value without changing available status. Before the first calculated utilization, keep startup unavailable. Only an actual Mach read failure changes an established source to unavailable.

Sample every 150 ms and apply a time-aware exponential moving average with a target time constant of roughly 0.75 seconds. Use the same filtered value for terrain and the displayed percentage.

## Rationale

CPU utilization is naturally bounded, changes often enough to create terrain, and is available without a permission prompt on the current Mac. RAM changes more slowly, and a single macOS "used memory" percentage hides distinctions among wired, compressed, cached, and reclaimable pages.

Raw 150 ms CPU readings can create near-vertical terrain between adjacent points. A short moving average preserves visible response within about one second while producing drivable slopes.

## Consequences

- Per-core CPU, RAM, swap, memory pressure, process, disk, and network metrics remain later decisions.
- The displayed percentage is filtered rather than an instantaneous raw reading.
- Raw readings remain internal so later monitor work can use them differently.
- CPU counter math requires tests for rollover and zero-delta intervals.
- Successful zero-delta snapshots do not flash the monitor annotation to unavailable.
- The source needs one baseline tick snapshot before it can calculate utilization.
