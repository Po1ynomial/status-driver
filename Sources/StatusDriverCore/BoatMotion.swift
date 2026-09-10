import CoreGraphics
import Foundation

package struct BoatMotionState: Equatable, Sendable {
    package var position: CGPoint
    package var horizontalVelocity: CGFloat
    package var verticalVelocity: CGFloat
    package var rotation: CGFloat

    package init(
        position: CGPoint,
        horizontalVelocity: CGFloat = 0,
        verticalVelocity: CGFloat = 0,
        rotation: CGFloat = 0
    ) {
        self.position = position
        self.horizontalVelocity = horizontalVelocity
        self.verticalVelocity = verticalVelocity
        self.rotation = rotation
    }
}

package struct BoatMotionModel: Sendable {
    package private(set) var state: BoatMotionState

    package init(position: CGPoint) {
        state = BoatMotionState(position: position)
    }

    package mutating func reset(at position: CGPoint) {
        state = BoatMotionState(position: position)
    }

    package mutating func update(
        deltaTime: TimeInterval,
        targetSurfaceY: CGFloat,
        surfaceSlope: CGFloat,
        movements: Set<EasterEggMovement>
    ) {
        let dt = CGFloat(min(max(deltaTime, 0), 0.05))
        guard dt > 0 else { return }

        updateHorizontal(dt: dt, movements: movements)

        let displacement = targetSurfaceY - state.position.y
        let verticalAcceleration = min(
            max(displacement * 22 - state.verticalVelocity * 7.5, -520),
            520
        )
        state.verticalVelocity += verticalAcceleration * dt
        state.position.y += state.verticalVelocity * dt

        let targetRotation = min(max(atan(surfaceSlope) * 0.55, -0.30), 0.30)
        let rotationProgress = 1 - exp(-8 * dt)
        state.rotation += (targetRotation - state.rotation) * rotationProgress
        state.position.x += state.horizontalVelocity * dt
    }

    private mutating func updateHorizontal(
        dt: CGFloat,
        movements: Set<EasterEggMovement>
    ) {
        let movingRight = movements.contains(.right)
        let movingLeft = movements.contains(.left)

        switch (movingRight, movingLeft) {
        case (true, false):
            state.horizontalVelocity += 105 * dt
        case (false, true):
            let acceleration: CGFloat = state.horizontalVelocity > 12 ? -210 : -105
            state.horizontalVelocity += acceleration * dt
        case (true, true):
            state.horizontalVelocity *= exp(-7 * dt)
        case (false, false):
            state.horizontalVelocity *= exp(-1.8 * dt)
        }
        state.horizontalVelocity = min(max(state.horizontalVelocity, -95), 115)
    }
}
