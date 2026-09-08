# Terrain chart density

## Question

Why did terrain become broken and spiky after the Performance graph changed from the prototype viewport to a full 60-second history?

## Findings

The source line was already piecewise linear. The visual regression came from preserving every 150 ms point while compressing eight times more time into roughly the same width.

For a 924-point graph with a 168-point usable vertical range and the synthetic source's 0.035 maximum step:

```text
old fixed scale
horizontal sample spacing: 18.00 points
maximum vertical step:       5.88 points
maximum local slope:         0.33
visible samples:             about 51

60-second scale at 150 ms
horizontal sample spacing:  2.31 points
maximum vertical step:      5.88 points
maximum local slope:        2.55
visible samples:            400

slope amplification:        7.79x
```

At one chart point per second, the same graph provides 15.4 horizontal points per historical segment and about 60 segments.

## Decision relevance

Keep telemetry collection, current percentages, and detail values at 150 ms. Resample historical chart and terrain data into one-second averages and expose only finalized points. Use the same reduced point collection for sidebar sparklines, visible geometry, and collision.

The first resampling implementation exposed the newest 150 ms point provisionally, then replaced it with the bucket average. This caused visible terrain near the right border to change. In a deterministic example, a point at 0.90 seconds changed from 0.8000 to 0.4667 when its bucket closed, only 2.31 points left of the visible edge.

The corrected model uses a one-second commit horizon. A bucket finalizes offscreen right, appends exactly once, and enters the viewport only after it is immutable. Numeric values remain live at 150 ms, while graph labels truthfully cover 61 to 1 seconds ago.

Do not use Bezier smoothing. It can overshoot source values and complicate drawing and collision identity. Do not generate catch-up buckets after suspension because invented points would misrepresent missing time.

## Method

The comparison used the implemented source interval, old fixed horizontal scale, new graph width and duration, current vertical layout, and synthetic maximum step. Deterministic model checks verify bucket averaging, exposed-prefix immutability, append-only finalization, skipped-gap behavior, and bounded density.

## Confidence and limitations

Confidence is high that density caused the visual regression because horizontal spacing changed by 7.79 times while vertical behavior did not. One-second averaging is a product choice modeled after the reference graph's lower visual density, not a claim about Task Manager's internal sampling algorithm.
