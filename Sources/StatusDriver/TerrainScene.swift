import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
final class TerrainScene: SKScene {
    var onMetricSelectionRequest: ((MetricIdentity) -> Void)?

    private struct Configuration {
        let sampleInterval: TimeInterval = 0.15
        let pointsPerSecond: CGFloat = 120
        let viewportDelay: TimeInterval = 2.75
        let retentionDuration: TimeInterval = 60
        let bottomInset: CGFloat = 92
        let topInset: CGFloat = 92
        let resetClearance: CGFloat = 48

        var layout: TerrainLayout {
            TerrainLayout(
                pointsPerSecond: pointsPerSecond,
                bottomInset: bottomInset,
                topInset: topInset
            )
        }
    }

    private let configuration = Configuration()
    private let timelineClock = ContinuousClock()
    private let trackingCamera = SKCameraNode()
    private let gridNode = SKNode()
    private var fillNode = SKShapeNode()
    private var lineNode = SKShapeNode()
    private let collisionNode = SKNode()

    private lazy var histories = MetricHistoryStore(
        sampleInterval: configuration.sampleInterval,
        retentionDuration: configuration.retentionDuration
    )
    private var selectedMetric: MetricIdentity = .cpu
    private var vehicle: Vehicle?
    private var pressedControls: Set<DrivingControl> = []
    private var elapsedTime: TimeInterval = 0
    private var latestReadingTimestamp: TimeInterval?
    private var latestReadingArrival: ContinuousClock.Instant?
    private var vehicleCreationFramesRemaining = 3
    private var isDarkAppearance = false
    private var isConfigured = false

    override func didMove(to view: SKView) {
        guard !isConfigured else { return }
        isConfigured = true

        physicsWorld.gravity = CGVector(dx: 0, dy: -18)

        configureTerrainNodes()
        applyGraphStyle()
        configureCamera()
        rebuildGrid()
        rebuildTerrain(rebuildCollisions: true)
        view.window?.makeFirstResponder(view)
    }

    override func willMove(from view: SKView) {
        pressedControls.removeAll()
        super.willMove(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isConfigured else { return }

        let oldCameraX = trackingCamera.position.x
        let oldVehiclePosition = vehicle?.chassis.position
        let oldTerrainHeight = oldVehiclePosition.flatMap {
            terrainHeight(atWorldX: $0.x, sceneHeight: oldSize.height)
        }

        updateCamera()
        rebuildGrid()
        rebuildTerrain(rebuildCollisions: true)
        if vehicle == nil {
            vehicleCreationFramesRemaining = 3
        }

        if let oldVehiclePosition, let oldTerrainHeight {
            let horizontalOffset = trackingCamera.position.x - oldCameraX
            let newVehicleX = oldVehiclePosition.x + horizontalOffset
            let newTerrainHeight = terrainHeight(atWorldX: newVehicleX, sceneHeight: size.height)
                ?? oldTerrainHeight
            replaceVehicle(
                at: CGPoint(
                    x: newVehicleX,
                    y: oldVehiclePosition.y + newTerrainHeight - oldTerrainHeight
                )
            )
        }
    }

    override func update(_ currentTime: TimeInterval) {
        guard isConfigured else { return }

        updateTimelineTime()
        updateCamera()
        createVehicleAfterLayoutSettles()
        vehicle?.update(controls: pressedControls)
        resetVehicleIfOutsideViewport()
    }

    func ingest(_ reading: MetricReading) {
        guard histories.ingest(reading) else { return }

        latestReadingTimestamp = max(latestReadingTimestamp ?? reading.timestamp, reading.timestamp)
        latestReadingArrival = timelineClock.now
        elapsedTime = max(elapsedTime, reading.timestamp)

        if isConfigured, reading.metric == selectedMetric {
            rebuildTerrain(rebuildCollisions: true)
        }
    }

    func applyAppearance(isDark: Bool) {
        guard isDarkAppearance != isDark else { return }
        isDarkAppearance = isDark
        applyGraphStyle()
        if isConfigured {
            rebuildGrid()
        }
    }

    @discardableResult
    func selectMetric(_ metric: MetricIdentity) -> Bool {
        guard metric != selectedMetric, histories.samples(for: metric).count >= 2 else {
            return false
        }

        selectedMetric = metric
        applyGraphStyle()
        rebuildTerrain(rebuildCollisions: true)
        resetVehicle()
        view?.window?.makeFirstResponder(view)
        return true
    }

    override func keyDown(with event: NSEvent) {
        if let metric = metricSelection(forKeyCode: event.keyCode) {
            if !event.isARepeat {
                onMetricSelectionRequest?(metric)
            }
            return
        }

        guard let input = drivingInput(forKeyCode: event.keyCode) else { return }

        switch input {
        case let .control(control):
            pressedControls.insert(control)
        case .reset where !event.isARepeat:
            resetVehicle()
        case .reset:
            break
        }
    }

    override func keyUp(with event: NSEvent) {
        guard case let .control(control) = drivingInput(forKeyCode: event.keyCode) else {
            return
        }
        pressedControls.remove(control)
    }

    override func mouseDown(with event: NSEvent) {
        view?.window?.makeFirstResponder(view)
    }

    private func configureTerrainNodes() {
        fillNode.strokeColor = .clear
        fillNode.zPosition = -2
        addChild(fillNode)

        lineNode.lineWidth = 4
        lineNode.lineCap = .butt
        lineNode.lineJoin = .bevel
        lineNode.zPosition = -1
        addChild(lineNode)

        collisionNode.name = "terrain-collision"
        addChild(collisionNode)
    }

    private func applyGraphStyle() {
        let color: NSColor
        switch (selectedMetric, isDarkAppearance) {
        case (.cpu, false):
            color = NSColor(red: 0.10, green: 0.48, blue: 0.76, alpha: 1)
        case (.cpu, true):
            color = NSColor(red: 0.30, green: 0.68, blue: 0.96, alpha: 1)
        case (.memory, false):
            color = NSColor(red: 0.53, green: 0.34, blue: 0.74, alpha: 1)
        case (.memory, true):
            color = NSColor(red: 0.72, green: 0.52, blue: 0.93, alpha: 1)
        }

        backgroundColor = isDarkAppearance
            ? NSColor(red: 0.085, green: 0.095, blue: 0.11, alpha: 1)
            : NSColor(red: 0.975, green: 0.978, blue: 0.97, alpha: 1)
        lineNode.strokeColor = color
        fillNode.fillColor = color.withAlphaComponent(isDarkAppearance ? 0.20 : 0.14)

        // SpriteKit caches shape style state after first render, so replace only on style changes.
        let linePath = lineNode.path
        let fillPath = fillNode.path
        lineNode.removeFromParent()
        fillNode.removeFromParent()

        fillNode = SKShapeNode(path: fillPath ?? CGMutablePath())
        fillNode.fillColor = color.withAlphaComponent(isDarkAppearance ? 0.20 : 0.14)
        fillNode.strokeColor = .clear
        fillNode.zPosition = -2
        addChild(fillNode)

        lineNode = SKShapeNode(path: linePath ?? CGMutablePath())
        lineNode.strokeColor = color
        lineNode.lineWidth = 4
        lineNode.lineCap = .butt
        lineNode.lineJoin = .bevel
        lineNode.zPosition = -1
        addChild(lineNode)
    }

    private func configureCamera() {
        camera = trackingCamera
        addChild(trackingCamera)

        gridNode.zPosition = -20
        trackingCamera.addChild(gridNode)
        updateCamera()
    }

    private func rebuildTerrain(rebuildCollisions: Bool) {
        let geometry = terrainGeometry(sceneHeight: size.height)
        lineNode.path = geometry.linePath()
        fillNode.path = geometry.fillPath()

        if rebuildCollisions {
            if let linePath = geometry.linePath() {
                let body = SKPhysicsBody(edgeChainFrom: linePath)
                body.friction = 0.92
                body.restitution = 0.02
                body.categoryBitMask = PhysicsCategory.terrain
                body.collisionBitMask = PhysicsCategory.chassis | PhysicsCategory.wheel
                body.contactTestBitMask = 0
                collisionNode.physicsBody = body
            } else {
                collisionNode.physicsBody = nil
            }
        }
    }

    private func terrainGeometry(sceneHeight: CGFloat) -> TerrainGeometry {
        TerrainGeometry(
            samples: histories.samples(for: selectedMetric),
            layout: configuration.layout,
            sceneHeight: sceneHeight
        )
    }

    private func terrainHeight(atWorldX x: CGFloat, sceneHeight: CGFloat) -> CGFloat? {
        terrainGeometry(sceneHeight: sceneHeight).height(atWorldX: x)
    }

    private func updateTimelineTime() {
        guard let latestReadingTimestamp, let latestReadingArrival else { return }

        let components = latestReadingArrival.duration(to: timelineClock.now).components
        let timeSinceReading = Double(components.seconds) + Double(components.attoseconds) / 1e18
        let interpolation = min(
            max(0, timeSinceReading),
            configuration.sampleInterval * 2
        )
        elapsedTime = latestReadingTimestamp + interpolation
    }

    private func updateCamera() {
        let visibleRightX = CGFloat(elapsedTime - configuration.viewportDelay)
            * configuration.pointsPerSecond
        trackingCamera.position = CGPoint(
            x: visibleRightX - size.width / 2,
            y: size.height / 2
        )
    }

    private func createVehicleAfterLayoutSettles() {
        guard vehicle == nil, histories.samples(for: selectedMetric).count >= 2 else { return }
        guard vehicleCreationFramesRemaining == 0 else {
            vehicleCreationFramesRemaining -= 1
            return
        }

        replaceVehicle(at: vehicleResetPosition())
    }

    private func replaceVehicle(at position: CGPoint) {
        vehicle?.remove(from: self)
        vehicle = Vehicle(in: self, at: position)
    }

    private func resetVehicle() {
        pressedControls.removeAll()
        replaceVehicle(at: vehicleResetPosition())
    }

    private func resetVehicleIfOutsideViewport() {
        let viewport = CGRect(
            x: trackingCamera.position.x - size.width / 2,
            y: trackingCamera.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
        if vehicle?.isFullyOutside(viewport) == true {
            resetVehicle()
        }
    }

    private func vehicleResetPosition() -> CGPoint {
        let x = trackingCamera.position.x
        let terrainY = terrainHeight(atWorldX: x, sceneHeight: size.height)
            ?? configuration.bottomInset
        return CGPoint(x: x, y: terrainY + configuration.resetClearance)
    }

    private func rebuildGrid() {
        gridNode.removeAllChildren()

        let path = CGMutablePath()
        let width = size.width
        let height = size.height
        let minorSpacing: CGFloat = 40
        let originX = -width / 2
        let originY = -height / 2

        var x = originX
        while x <= width / 2 {
            path.move(to: CGPoint(x: x, y: originY))
            path.addLine(to: CGPoint(x: x, y: height / 2))
            x += minorSpacing
        }

        var y = originY
        while y <= height / 2 {
            path.move(to: CGPoint(x: originX, y: y))
            path.addLine(to: CGPoint(x: width / 2, y: y))
            y += minorSpacing
        }

        let lines = SKShapeNode(path: path)
        lines.strokeColor = isDarkAppearance
            ? NSColor(white: 1, alpha: 0.10)
            : NSColor(white: 0, alpha: 0.09)
        lines.lineWidth = 1
        gridNode.addChild(lines)
    }
}
