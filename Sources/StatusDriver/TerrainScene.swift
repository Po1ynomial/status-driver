import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
final class TerrainScene: SKScene {
    private struct Configuration {
        let sampleInterval: TimeInterval = 0.15
        let visibleDuration: TimeInterval = 60
        let commitDelay: TimeInterval = 1
        let retentionDuration: TimeInterval = 65
        let rightCollisionMargin: CGFloat = 120
        let bottomInset: CGFloat = 48
        let topInset: CGFloat = 64
        let resetClearance: CGFloat = 48

        func timeline(width: CGFloat) -> GraphTimelineLayout {
            GraphTimelineLayout(width: max(1, width), visibleDuration: visibleDuration)
        }

        func terrainLayout(width: CGFloat) -> TerrainLayout {
            TerrainLayout(
                pointsPerSecond: timeline(width: width).pointsPerSecond,
                bottomInset: bottomInset,
                topInset: topInset
            )
        }
    }

    private let configuration = Configuration()
    private let trackingCamera = SKCameraNode()
    private let gridNode = SKNode()
    private var fillNode = SKShapeNode()
    private var lineNode = SKShapeNode()
    private let collisionNode = SKNode()

    private lazy var histories = MetricHistoryStore(
        sampleInterval: configuration.sampleInterval,
        retentionDuration: configuration.retentionDuration
    )
    private var selectedResource: PerformanceResourceID = .cpu
    private var selectedColorRole: PerformanceColorRole = .cpu
    private var activeEasterEggUtility: EasterEggUtility = .none
    private var vehicle: Vehicle?
    private var boat: Boat?
    private var activeTetromino: TetrominoPiece?
    private var settledTetrominos: [TetrominoPiece] = []
    private var tetrominoBag = TetrominoBag()
    private var tetrominoDropClock = TetrominoDropClock()
    private var pressedControls: Set<DrivingControl> = []
    private var pressedMovements: Set<EasterEggMovement> = []
    private var latestReadingTimestamp: TimeInterval?
    private var previousUpdateTime: TimeInterval?
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
    }

    override func willMove(from view: SKView) {
        removeCurrentUtility()
        super.willMove(from: view)
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard isConfigured else { return }

        updateCamera()
        rebuildGrid()
        rebuildTerrain(rebuildCollisions: true)
        removeCurrentUtility()
        ensureUtilityMatchesSelection()
    }

    override func update(_ currentTime: TimeInterval) {
        guard isConfigured else { return }

        let deltaTime = previousUpdateTime.map { currentTime - $0 } ?? 0
        previousUpdateTime = currentTime
        updateCamera()
        ensureUtilityMatchesSelection()
        vehicle?.update(controls: pressedControls)
        updateBoat(deltaTime: deltaTime)
        updateTetrominos(deltaTime: deltaTime)
        resetUtilityIfOutsideViewport()
    }

    func ingest(_ reading: MetricReading, historyInput: MetricHistoryInput) {
        let update = histories.ingestUpdate(reading, input: historyInput)
        guard update.wasAccepted else { return }

        latestReadingTimestamp = max(latestReadingTimestamp ?? reading.timestamp, reading.timestamp)
        if isConfigured, reading.resource == selectedResource, update == .historyChanged {
            updateCamera()
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
    func selectResource(
        _ resource: PerformanceResourceID,
        colorRole: PerformanceColorRole
    ) -> Bool {
        guard resource != selectedResource, histories.samples(for: resource).count >= 2 else {
            return false
        }

        selectedResource = resource
        selectedColorRole = colorRole
        applyGraphStyle()
        rebuildTerrain(rebuildCollisions: true)
        removeCurrentUtility()
        ensureUtilityMatchesSelection()
        return true
    }

    func setEasterEggUtility(_ utility: EasterEggUtility) {
        guard activeEasterEggUtility != utility else { return }
        activeEasterEggUtility = utility
        removeCurrentUtility()
        ensureUtilityMatchesSelection()
    }

    func handle(_ command: EasterEggCommand) {
        switch command {
        case let .setMovement(.right, isPressed):
            updateMovement(.right, isPressed: isPressed)
        case let .setMovement(.left, isPressed):
            updateMovement(.left, isPressed: isPressed)
        case .reset:
            resetCurrentUtility()
        case .stepLeft:
            moveActiveTetromino(x: -1, y: 0)
        case .stepRight:
            moveActiveTetromino(x: 1, y: 0)
        case let .setFastDrop(isPressed):
            guard activeEasterEggUtility == .tetromino else { break }
            tetrominoDropClock.isFastDropping = isPressed
        case .rotateClockwise:
            guard activeEasterEggUtility == .tetromino else { break }
            activeTetromino?.rotateClockwise()
            settleActiveTetrominoIfNeeded()
        case .toggle, .flap:
            break
        }
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
        switch (selectedColorRole, isDarkAppearance) {
        case (.cpu, false):
            color = NSColor(red: 0.10, green: 0.48, blue: 0.76, alpha: 1)
        case (.cpu, true):
            color = NSColor(red: 0.30, green: 0.68, blue: 0.96, alpha: 1)
        case (.memory, false):
            color = NSColor(red: 0.53, green: 0.34, blue: 0.74, alpha: 1)
        case (.memory, true):
            color = NSColor(red: 0.72, green: 0.52, blue: 0.93, alpha: 1)
        case (.disk, false):
            color = NSColor(red: 0.27, green: 0.62, blue: 0.26, alpha: 1)
        case (.disk, true):
            color = NSColor(red: 0.45, green: 0.80, blue: 0.42, alpha: 1)
        case (.wifi, false):
            color = NSColor(red: 0.88, green: 0.46, blue: 0.14, alpha: 1)
        case (.wifi, true):
            color = NSColor(red: 1.0, green: 0.64, blue: 0.28, alpha: 1)
        case (.ethernet, false):
            color = NSColor(red: 0.64, green: 0.28, blue: 0.24, alpha: 1)
        case (.ethernet, true):
            color = NSColor(red: 0.90, green: 0.47, blue: 0.40, alpha: 1)
        case (.network, false):
            color = NSColor(red: 0.72, green: 0.38, blue: 0.18, alpha: 1)
        case (.network, true):
            color = NSColor(red: 0.94, green: 0.58, blue: 0.32, alpha: 1)
        case (.gpu, false):
            color = NSColor(red: 0.05, green: 0.62, blue: 0.72, alpha: 1)
        case (.gpu, true):
            color = NSColor(red: 0.28, green: 0.80, blue: 0.88, alpha: 1)
        }

        backgroundColor = isDarkAppearance
            ? NSColor(red: 0.085, green: 0.095, blue: 0.11, alpha: 1)
            : NSColor(red: 0.975, green: 0.978, blue: 0.97, alpha: 1)

        let linePath = lineNode.path
        let fillPath = fillNode.path
        lineNode.removeFromParent()
        fillNode.removeFromParent()

        fillNode = SKShapeNode(path: fillPath ?? CGMutablePath())
        fillNode.fillColor = color.withAlphaComponent(isDarkAppearance ? 0.20 : 0.14)
        fillNode.strokeColor = .clear
        fillNode.zPosition = -2
        addChild(fillNode)

        // Replacing the node avoids SpriteKit retaining its first rendered stroke style.
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
            if let collisionPath = geometry.collisionPath(
                rightExtension: configuration.rightCollisionMargin
            ) {
                let body = SKPhysicsBody(edgeChainFrom: collisionPath)
                body.friction = 0.92
                body.restitution = 0.02
                body.categoryBitMask = PhysicsCategory.terrain
                body.collisionBitMask = PhysicsCategory.chassis
                    | PhysicsCategory.wheel
                    | PhysicsCategory.tetromino
                body.contactTestBitMask = 0
                collisionNode.physicsBody = body
            } else {
                collisionNode.physicsBody = nil
            }
        }
    }

    private func terrainGeometry(sceneHeight: CGFloat) -> TerrainGeometry {
        TerrainGeometry(
            samples: histories.samples(for: selectedResource),
            layout: configuration.terrainLayout(width: size.width),
            sceneHeight: sceneHeight
        )
    }

    private func terrainHeight(atWorldX x: CGFloat, sceneHeight: CGFloat) -> CGFloat? {
        terrainGeometry(sceneHeight: sceneHeight).height(atWorldX: x)
    }

    private func updateCamera() {
        let timeline = configuration.timeline(width: size.width)
        let endingTimestamp = timeline.visibleEndTimestamp(
            sourceTimestamp: latestReadingTimestamp ?? 0,
            commitDelay: configuration.commitDelay,
            latestCommittedTimestamp: histories.samples(for: selectedResource).last?.timestamp
        )
        trackingCamera.position = CGPoint(
            x: timeline.cameraCenterX(endingAt: endingTimestamp),
            y: size.height / 2
        )
    }

    private func ensureUtilityMatchesSelection() {
        switch activeEasterEggUtility {
        case .car:
            ensureVisibleVehicleExists()
        case .boat:
            ensureBoatExists()
        case .tetromino:
            ensureTetrominoExists()
        case .packet, .none:
            break
        }
    }

    private func updateMovement(_ movement: EasterEggMovement, isPressed: Bool) {
        guard activeEasterEggUtility == .car || activeEasterEggUtility == .boat else { return }
        let control: DrivingControl = movement == .right ? .driveRight : .brakeOrDriveLeft
        if isPressed {
            pressedMovements.insert(movement)
            pressedControls.insert(control)
        } else {
            pressedMovements.remove(movement)
            pressedControls.remove(control)
        }
    }

    private func removeCurrentUtility() {
        pressedControls.removeAll()
        pressedMovements.removeAll()
        vehicle?.remove(from: self)
        vehicle = nil
        boat?.remove()
        boat = nil
        activeTetromino?.remove()
        activeTetromino = nil
        settledTetrominos.forEach { $0.remove() }
        settledTetrominos.removeAll()
        tetrominoDropClock.reset()
    }

    private func ensureVisibleVehicleExists() {
        guard activeEasterEggUtility == .car, vehicle == nil,
              histories.samples(for: selectedResource).count >= 2 else { return }
        replaceVehicle(at: vehicleResetPosition())
    }

    private func ensureBoatExists() {
        guard activeEasterEggUtility == .boat, boat == nil,
              histories.samples(for: selectedResource).count >= 2 else { return }
        let position = boatResetPosition()
        boat = Boat(in: self, at: position)
    }

    private func ensureTetrominoExists() {
        guard activeEasterEggUtility == .tetromino, activeTetromino == nil,
              histories.samples(for: selectedResource).count >= 2 else { return }
        let position = CGPoint(
            x: trackingCamera.position.x,
            y: size.height - TetrominoPiece.blockSize * 2.5
        )
        activeTetromino = TetrominoPiece(
            kind: tetrominoBag.next(),
            in: self,
            at: position
        )
        let isFastDropping = tetrominoDropClock.isFastDropping
        tetrominoDropClock.reset()
        tetrominoDropClock.isFastDropping = isFastDropping
    }

    private func replaceVehicle(at position: CGPoint) {
        vehicle?.remove(from: self)
        vehicle = Vehicle(in: self, at: position)
    }

    private func resetVehicle() {
        guard activeEasterEggUtility == .car else { return }
        pressedControls.removeAll()
        guard histories.samples(for: selectedResource).count >= 2 else {
            vehicle?.remove(from: self)
            vehicle = nil
            return
        }
        replaceVehicle(at: vehicleResetPosition())
    }

    private func resetCurrentUtility() {
        switch activeEasterEggUtility {
        case .car:
            resetVehicle()
        case .boat:
            boat?.remove()
            boat = nil
            pressedMovements.removeAll()
            pressedControls.removeAll()
            ensureBoatExists()
        case .tetromino:
            releaseActiveTetromino()
        case .packet, .none:
            break
        }
    }

    private func updateBoat(deltaTime: TimeInterval) {
        guard activeEasterEggUtility == .boat, let boat else { return }
        let x = boat.position.x
        guard let surfaceY = terrainHeight(atWorldX: x, sceneHeight: size.height) else {
            return
        }
        let probe: CGFloat = 4
        let leftY = terrainHeight(atWorldX: x - probe, sceneHeight: size.height) ?? surfaceY
        let rightY = terrainHeight(atWorldX: x + probe, sceneHeight: size.height) ?? surfaceY
        boat.update(
            deltaTime: deltaTime,
            targetSurfaceY: surfaceY + Boat.surfaceOffset,
            surfaceSlope: (rightY - leftY) / (probe * 2),
            movements: pressedMovements
        )
    }

    private func updateTetrominos(deltaTime: TimeInterval) {
        guard activeEasterEggUtility == .tetromino else { return }
        ensureTetrominoExists()
        for _ in 0..<tetrominoDropClock.advance(by: deltaTime) {
            moveActiveTetromino(x: 0, y: -1)
        }

        let viewport = graphViewport()
        settledTetrominos.removeAll { piece in
            if piece.isFullyOutside(viewport) {
                piece.remove()
                return true
            }
            return false
        }
        if settledTetrominos.count > 96 {
            let excess = settledTetrominos.count - 96
            settledTetrominos.prefix(excess).forEach { $0.remove() }
            settledTetrominos.removeFirst(excess)
        }
    }

    private func moveActiveTetromino(x: Int, y: Int) {
        guard activeEasterEggUtility == .tetromino, let activeTetromino else { return }
        activeTetromino.move(x: x, y: y)
        settleActiveTetrominoIfNeeded()
    }

    private func settleActiveTetrominoIfNeeded() {
        guard let activeTetromino else { return }
        let frames = activeTetromino.blockFrames(in: self)
        let touchesTerrain = frames.contains { frame in
            [frame.minX, frame.midX, frame.maxX].contains { x in
                let terrainY = terrainHeight(atWorldX: x, sceneHeight: size.height)
                    ?? configuration.bottomInset
                return frame.minY <= terrainY
            }
        }
        let touchesPiece = settledTetrominos.contains { settled in
            let settledFrames = settled.blockFrames(in: self)
            return frames.contains { frame in
                settledFrames.contains { $0.intersects(frame.insetBy(dx: 1, dy: 1)) }
            }
        }
        if touchesTerrain || touchesPiece {
            releaseActiveTetromino()
        }
    }

    private func releaseActiveTetromino() {
        guard activeEasterEggUtility == .tetromino, let activeTetromino else { return }
        activeTetromino.release()
        settledTetrominos.append(activeTetromino)
        self.activeTetromino = nil
        ensureTetrominoExists()
    }

    private func resetUtilityIfOutsideViewport() {
        let viewport = graphViewport()
        if vehicle?.isFullyOutside(viewport) == true {
            resetVehicle()
        }
        if boat?.isFullyOutside(viewport) == true {
            resetCurrentUtility()
        }
    }

    private func graphViewport() -> CGRect {
        CGRect(
            x: trackingCamera.position.x - size.width / 2,
            y: trackingCamera.position.y - size.height / 2,
            width: size.width,
            height: size.height
        )
    }

    private func vehicleResetPosition() -> CGPoint {
        let x = trackingCamera.position.x
        let terrainY = terrainHeight(atWorldX: x, sceneHeight: size.height)
            ?? configuration.bottomInset
        return CGPoint(x: x, y: terrainY + configuration.resetClearance)
    }

    private func boatResetPosition() -> CGPoint {
        let x = trackingCamera.position.x
        let terrainY = terrainHeight(atWorldX: x, sceneHeight: size.height)
            ?? configuration.bottomInset
        return CGPoint(x: x, y: terrainY + Boat.surfaceOffset)
    }

    private func rebuildGrid() {
        gridNode.removeAllChildren()

        let path = CGMutablePath()
        let width = size.width
        let height = size.height
        let originX = -width / 2
        let originY = -height / 2
        let verticalSpacing = width / 12
        let horizontalSpacing = height / 8

        for index in 0...12 {
            let x = originX + CGFloat(index) * verticalSpacing
            path.move(to: CGPoint(x: x, y: originY))
            path.addLine(to: CGPoint(x: x, y: height / 2))
        }
        for index in 0...8 {
            let y = originY + CGFloat(index) * horizontalSpacing
            path.move(to: CGPoint(x: originX, y: y))
            path.addLine(to: CGPoint(x: width / 2, y: y))
        }

        let lines = SKShapeNode(path: path)
        lines.strokeColor = isDarkAppearance
            ? NSColor(white: 1, alpha: 0.10)
            : NSColor(white: 0, alpha: 0.09)
        lines.lineWidth = 1
        gridNode.addChild(lines)
    }
}
