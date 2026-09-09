import SpriteKit
import StatusDriverCore
import SwiftUI

struct TerrainView: View {
    @Environment(\.colorScheme) private var colorScheme
    @ObservedObject var telemetry: TelemetrySession
    @State private var scene: TerrainScene
    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    init(telemetry: TelemetrySession) {
        self.telemetry = telemetry
        let scene = TerrainScene(size: CGSize(width: 920, height: 340))
        scene.scaleMode = .resizeFill
        _scene = State(initialValue: scene)
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            performanceSidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            PerformanceDetailView(telemetry: telemetry, scene: scene)
                .navigationTitle("Performance")
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 900, minHeight: 600)
        .task {
            scene.onEasterEggToggleRequest = { [weak telemetry] in
                telemetry?.toggleEasterEgg()
            }
            defer { scene.onEasterEggToggleRequest = nil }
            await telemetry.run(scene: scene)
        }
        .onChange(of: telemetry.selectedResource, initial: true) { _, resource in
            let descriptor = telemetry.descriptor(for: resource)
            scene.selectResource(resource, colorRole: descriptor?.colorRole ?? .cpu)
            scene.setEasterEggUtility(telemetry.activeEasterEggUtility)
        }
        .onChange(of: telemetry.easterEggEnabled, initial: true) { _, _ in
            scene.setEasterEggUtility(telemetry.activeEasterEggUtility)
        }
        .onChange(of: colorScheme, initial: true) { _, scheme in
            scene.applyAppearance(isDark: scheme == .dark)
        }
    }

    private var performanceSidebar: some View {
        List(selection: selectionBinding) {
            Section {
                ForEach(telemetry.resources) { record in
                    ResourceRow(
                        descriptor: record.descriptor,
                        reading: telemetry.reading(for: record.id),
                        history: telemetry.history(for: record.id),
                        installedMemoryBytes: telemetry.hardwareProfile?.installedMemoryBytes
                    )
                    .tag(record.id)
                }
            } header: {
                if telemetry.sourceMode == .synthetic {
                    Text("Synthetic data")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Status Driver")
    }

    private var selectionBinding: Binding<PerformanceResourceID?> {
        Binding(
            get: { telemetry.selectedResource },
            set: { resource in
                if let resource {
                    telemetry.select(resource)
                }
            }
        )
    }
}

private struct ResourceRow: View {
    let descriptor: PerformanceResourceDescriptor
    let reading: MetricReading?
    let history: [MetricSample]
    let installedMemoryBytes: UInt64?

    var body: some View {
        HStack(spacing: 12) {
            MetricSparkline(history: history, color: descriptor.colorRole.tint)
                .frame(width: 68, height: 46)
                .overlay {
                    Rectangle()
                        .stroke(descriptor.colorRole.tint.opacity(0.52), lineWidth: 1)
                }

            VStack(alignment: .leading, spacing: 3) {
                Text(descriptor.title)
                    .font(.headline)
                Text(summary)
                    .font(.system(.subheadline, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.9)
            }
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var summary: String {
        guard reading?.availability == .available, let reading else {
            return "Unavailable"
        }
        let percentage = Int((reading.value * 100).rounded())

        guard descriptor.id == .memory,
              let installedMemoryBytes,
              installedMemoryBytes > 0 else {
            return "\(percentage)%"
        }
        let usedBytes = UInt64(Double(installedMemoryBytes) * reading.value)
        return "\(formatMemoryRatio(used: usedBytes, total: installedMemoryBytes)) (\(percentage)%)"
    }
}

private struct MetricSparkline: View {
    let history: [MetricSample]
    let color: Color

    var body: some View {
        Canvas { context, size in
            let samples = visibleSamples
            guard samples.count >= 2,
                  let firstTime = samples.first?.timestamp,
                  let lastTime = samples.last?.timestamp else { return }

            let duration = max(60, lastTime - firstTime)
            let startTime = lastTime - duration
            var line = Path()
            var fill = Path()

            for (index, sample) in samples.enumerated() {
                let x = CGFloat((sample.timestamp - startTime) / duration) * size.width
                let y = (1 - CGFloat(sample.value)) * size.height
                if index == 0 {
                    line.move(to: CGPoint(x: x, y: y))
                    fill.move(to: CGPoint(x: x, y: size.height))
                    fill.addLine(to: CGPoint(x: x, y: y))
                } else {
                    line.addLine(to: CGPoint(x: x, y: y))
                    fill.addLine(to: CGPoint(x: x, y: y))
                }
            }

            if let last = samples.last {
                let lastX = CGFloat((last.timestamp - startTime) / duration) * size.width
                fill.addLine(to: CGPoint(x: lastX, y: size.height))
                fill.closeSubpath()
            }

            context.fill(fill, with: .color(color.opacity(0.12)))
            context.stroke(line, with: .color(color), lineWidth: 1.4)
        }
        .background(Color(nsColor: .controlBackgroundColor).opacity(0.45))
        .clipped()
    }

    private var visibleSamples: [MetricSample] {
        guard let latest = history.last?.timestamp else { return [] }
        return history.filter { $0.timestamp >= latest - 60 }
    }
}

private struct PerformanceDetailView: View {
    @ObservedObject var telemetry: TelemetrySession
    let scene: TerrainScene

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                detailHeader
                Text(telemetry.selectedResource == .cpu ? "% Utilization" : "Memory usage")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 3) {
                    SpriteKitView(scene: scene)
                        .frame(height: 280)
                        .overlay(alignment: .topTrailing) {
                            Text(verticalMaximum)
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .padding(5)
                        }
                        .overlay {
                            Rectangle()
                                .stroke(selectedColor.opacity(0.72), lineWidth: 1)
                        }

                    HStack {
                        Text("61 seconds")
                        Spacer()
                        Text("1 second")
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                }

                if telemetry.selectedResource == .memory {
                    MemoryCompositionView(details: memoryDetails)
                }

                if telemetry.selectedResource == .cpu {
                    CPUStatisticsView(
                        reading: telemetry.latestCPUReading,
                        profile: telemetry.hardwareProfile,
                        activity: telemetry.systemActivity
                    )
                } else {
                    MemoryStatisticsView(
                        reading: telemetry.latestMemoryReading,
                        profile: telemetry.hardwareProfile
                    )
                }
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var detailHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 20) {
            Text(selectedDescriptor.title)
                .font(.system(size: 34, weight: .semibold))
            Spacer(minLength: 24)
            Text(hardwareSummary)
                .font(.headline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }

    private var hardwareSummary: String {
        switch telemetry.selectedResource {
        case .cpu:
            telemetry.hardwareProfile?.cpuName ?? "CPU"
        case .memory:
            telemetry.hardwareProfile?.installedMemoryBytes.map(formatBytes) ?? "Memory"
        case .disk:
            "Disk"
        case .network:
            "Network"
        case .gpu:
            "GPU"
        }
    }

    private var memoryDetails: MemoryDetails? {
        guard case let .memory(details)? = telemetry.latestMemoryReading?.details else {
            return nil
        }
        return details
    }

    private var verticalMaximum: String {
        switch telemetry.selectedResource {
        case .cpu:
            "100%"
        case .memory:
            telemetry.hardwareProfile?.installedMemoryBytes.map(formatBytes) ?? "100%"
        case .disk, .gpu:
            "100%"
        case .network:
            ""
        }
    }

    private var selectedDescriptor: PerformanceResourceDescriptor {
        telemetry.descriptor(for: telemetry.selectedResource) ?? .cpu
    }

    private var selectedColor: Color {
        selectedDescriptor.colorRole.tint
    }
}

private struct CPUStatisticsView: View {
    let reading: MetricReading?
    let profile: PerformanceHardwareProfile?
    let activity: SystemActivitySnapshot?

    var body: some View {
        HStack(alignment: .top, spacing: 34) {
            LazyVGrid(
                columns: [GridItem(.flexible()), GridItem(.flexible())],
                alignment: .leading,
                spacing: 16
            ) {
                PrimaryStatistic(label: "Utilization", value: percentage(reading))
                PrimaryStatistic(label: "Processes", value: count(activity?.processCount))
                PrimaryStatistic(label: "Threads", value: count(activity?.threadCount))
                PrimaryStatistic(label: "Up time", value: uptime(activity?.uptime))
            }
            .frame(maxWidth: 330)

            Divider()

            VStack(alignment: .leading, spacing: 7) {
                DetailRow(label: "Packages", value: count(profile?.packageCount))
                DetailRow(label: "Cores", value: count(profile?.physicalCoreCount))
                if let topology = coreTopology(profile) {
                    DetailRow(label: "Core types", value: topology)
                }
                DetailRow(
                    label: "Logical processors",
                    value: count(profile?.logicalProcessorCount)
                )
                DetailRow(
                    label: "Virtualization",
                    value: virtualization(profile?.virtualizationSupported)
                )
                ForEach(Array((profile?.performanceLevels ?? []).enumerated()), id: \.offset) {
                    _, level in
                    DetailRow(
                        label: "\(level.name) L1",
                        value: l1Description(level)
                    )
                    DetailRow(
                        label: "\(level.name) L2",
                        value: level.l2CacheBytes.map(formatBytes) ?? "-"
                    )
                }
                if let l3CacheBytes = profile?.l3CacheBytes {
                    DetailRow(label: "L3 cache", value: formatBytes(l3CacheBytes))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.top, 4)
    }
}

private struct MemoryCompositionView: View {
    let details: MemoryDetails?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Memory composition")
                .font(.caption)
                .foregroundStyle(.secondary)
            GeometryReader { geometry in
                HStack(spacing: 0) {
                    segment(width: geometry.size.width * (details?.appFraction ?? 0), opacity: 0.92)
                    segment(width: geometry.size.width * (details?.wiredFraction ?? 0), opacity: 0.70)
                    segment(
                        width: geometry.size.width * (details?.compressedFraction ?? 0),
                        opacity: 0.48
                    )
                    segment(
                        width: geometry.size.width * (details?.availableFraction ?? 1),
                        opacity: 0.10
                    )
                }
            }
            .frame(height: 34)
            .overlay {
                Rectangle().stroke(PerformanceColorRole.memory.tint.opacity(0.72), lineWidth: 1)
            }
        }
    }

    private func segment(width: CGFloat, opacity: Double) -> some View {
        PerformanceColorRole.memory.tint
            .opacity(opacity)
            .frame(width: max(0, width))
    }
}

private struct MemoryStatisticsView: View {
    let reading: MetricReading?
    let profile: PerformanceHardwareProfile?

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 128), alignment: .leading)],
            alignment: .leading,
            spacing: 16
        ) {
            PrimaryStatistic(label: "In use", value: bytes(details?.inUseBytes))
            PrimaryStatistic(label: "Available", value: bytes(details?.availableBytes))
            PrimaryStatistic(label: "App memory", value: bytes(details?.appBytes))
            PrimaryStatistic(label: "Wired", value: bytes(details?.wiredBytes))
            PrimaryStatistic(label: "Compressed", value: bytes(details?.compressedBytes))
            PrimaryStatistic(label: "File cache", value: bytes(details?.fileCacheBytes))
            PrimaryStatistic(label: "Installed", value: bytes(profile?.installedMemoryBytes))
            PrimaryStatistic(label: "Type", value: profile?.memoryType ?? "-")
        }
        .padding(.top, 4)
    }

    private var details: MemoryDetails? {
        guard case let .memory(details)? = reading?.details else { return nil }
        return details
    }
}

private struct PrimaryStatistic: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.title3, design: .monospaced, weight: .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
    }
}

private struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(label)
                .foregroundStyle(.secondary)
                .frame(width: 128, alignment: .trailing)
            Text(value)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
        }
        .font(.subheadline)
    }
}

private struct SpriteKitView: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme
    let scene: TerrainScene

    func makeNSView(context: Context) -> SKView {
        let view = FocusableSKView(frame: CGRect(x: 0, y: 0, width: 920, height: 320))
        view.ignoresSiblingOrder = true
        scene.applyAppearance(isDark: colorScheme == .dark)
        view.presentScene(scene)
        return view
    }

    func updateNSView(_ view: SKView, context: Context) {
        scene.applyAppearance(isDark: colorScheme == .dark)
        if view.scene !== scene {
            view.presentScene(scene)
        }
    }
}

private final class FocusableSKView: SKView {
    override var acceptsFirstResponder: Bool { true }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        guard let window else { return }
        DispatchQueue.main.async {
            window.makeFirstResponder(self)
        }
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        super.mouseDown(with: event)
    }
}

private extension PerformanceColorRole {
    var tint: Color {
        switch self {
        case .cpu:
            return Color(red: 0.10, green: 0.48, blue: 0.76)
        case .memory:
            return Color(red: 0.53, green: 0.34, blue: 0.74)
        case .disk:
            return Color(red: 0.27, green: 0.62, blue: 0.26)
        case .wifi:
            return Color(red: 0.88, green: 0.46, blue: 0.14)
        case .ethernet:
            return Color(red: 0.64, green: 0.28, blue: 0.24)
        case let .network(index):
            let colors = [
                Color(red: 0.72, green: 0.38, blue: 0.18),
                Color(red: 0.76, green: 0.31, blue: 0.24),
                Color(red: 0.68, green: 0.43, blue: 0.17),
            ]
            return colors[abs(index) % colors.count]
        case .gpu:
            return Color(red: 0.05, green: 0.62, blue: 0.72)
        }
    }
}

private func percentage(_ reading: MetricReading?) -> String {
    guard reading?.availability == .available, let value = reading?.value else { return "-" }
    return "\(Int((value * 100).rounded()))%"
}

private func count(_ value: Int?) -> String {
    value?.formatted(.number.grouping(.automatic)) ?? "-"
}

private func bytes(_ value: UInt64?) -> String {
    value.map(formatBytes) ?? "-"
}

private func formatBytes(_ value: UInt64) -> String {
    let units: [(threshold: Double, suffix: String)] = [
        (1_073_741_824, "GB"),
        (1_048_576, "MB"),
        (1_024, "KB"),
    ]
    let bytes = Double(value)
    for unit in units where bytes >= unit.threshold {
        let scaled = bytes / unit.threshold
        return scaled >= 10
            ? String(format: "%.0f %@", scaled, unit.suffix)
            : String(format: "%.1f %@", scaled, unit.suffix)
    }
    return "\(value) B"
}

private func formatMemoryRatio(used: UInt64, total: UInt64) -> String {
    let gibibyte = 1_073_741_824.0
    guard Double(total) >= gibibyte else {
        return "\(formatBytes(used))/\(formatBytes(total))"
    }

    let usedValue = Double(used) / gibibyte
    let totalValue = Double(total) / gibibyte
    let totalText = totalValue.rounded() == totalValue
        ? String(format: "%.0f", totalValue)
        : String(format: "%.1f", totalValue)
    return "\(String(format: "%.1f", usedValue))/\(totalText) GB"
}

private func uptime(_ interval: TimeInterval?) -> String {
    guard let interval else { return "-" }
    let seconds = max(0, Int(interval))
    let days = seconds / 86_400
    let hours = seconds % 86_400 / 3_600
    let minutes = seconds % 3_600 / 60
    let remainder = seconds % 60
    return String(format: "%d:%02d:%02d:%02d", days, hours, minutes, remainder)
}

private func virtualization(_ supported: Bool?) -> String {
    guard let supported else { return "-" }
    return supported ? "Supported" : "Not supported"
}

private func coreTopology(_ profile: PerformanceHardwareProfile?) -> String? {
    let levels = profile?.performanceLevels ?? []
    guard levels.count > 1 else { return nil }
    let descriptions = levels.compactMap { level -> String? in
        guard let count = level.physicalCoreCount else { return nil }
        return "\(count) \(level.name)"
    }
    return descriptions.isEmpty ? nil : descriptions.joined(separator: ", ")
}

private func l1Description(_ level: CPUPerformanceLevel) -> String {
    let instruction = level.l1InstructionCacheBytes.map(formatBytes) ?? "-"
    let data = level.l1DataCacheBytes.map(formatBytes) ?? "-"
    return "\(instruction) I / \(data) D"
}
