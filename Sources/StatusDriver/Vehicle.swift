import AppKit
import SpriteKit
import StatusDriverCore

@MainActor
enum PhysicsCategory {
    static let terrain: UInt32 = 1 << 0
    static let chassis: UInt32 = 1 << 1
    static let wheel: UInt32 = 1 << 2
}

@MainActor
final class Vehicle {
    private enum Constants {
        static let wheelRadius: CGFloat = 10.5
        static let wheelOffsetX: CGFloat = 19.25
        static let wheelOffsetY: CGFloat = -10.5
        static let rightRotationSpeed: CGFloat = -6
        static let leftRotationSpeed: CGFloat = 5
        static let driveTorque: CGFloat = 3.5
        static let brakeTorque: CGFloat = 6
        static let coastingTorque: CGFloat = 0.25
    }

    let chassis: SKShapeNode
    let rearWheel: SKShapeNode
    let frontWheel: SKShapeNode

    private let rearJoint: SKPhysicsJointPin
    private let frontJoint: SKPhysicsJointPin

    init(in scene: SKScene, at position: CGPoint) {
        chassis = Self.makeChassis()
        rearWheel = Self.makeWheel()
        frontWheel = Self.makeWheel()

        chassis.position = position
        rearWheel.position = CGPoint(
            x: position.x - Constants.wheelOffsetX,
            y: position.y + Constants.wheelOffsetY
        )
        frontWheel.position = CGPoint(
            x: position.x + Constants.wheelOffsetX,
            y: position.y + Constants.wheelOffsetY
        )

        scene.addChild(chassis)
        scene.addChild(rearWheel)
        scene.addChild(frontWheel)

        rearJoint = SKPhysicsJointPin.joint(
            withBodyA: chassis.physicsBody!,
            bodyB: rearWheel.physicsBody!,
            anchor: rearWheel.position
        )
        frontJoint = SKPhysicsJointPin.joint(
            withBodyA: chassis.physicsBody!,
            bodyB: frontWheel.physicsBody!,
            anchor: frontWheel.position
        )

        scene.physicsWorld.add(rearJoint)
        scene.physicsWorld.add(frontJoint)
        configureMotor(speed: 0, torque: Constants.coastingTorque)
    }

    func update(controls: Set<DrivingControl>) {
        let drivingRight = controls.contains(.driveRight)
        let drivingLeft = controls.contains(.brakeOrDriveLeft)

        switch (drivingRight, drivingLeft) {
        case (true, false):
            configureMotor(
                speed: Constants.rightRotationSpeed,
                torque: Constants.driveTorque
            )
        case (false, true):
            let stillMovingRight = (chassis.physicsBody?.velocity.dx ?? 0) > 12
            configureMotor(
                speed: stillMovingRight ? 0 : Constants.leftRotationSpeed,
                torque: stillMovingRight ? Constants.brakeTorque : Constants.driveTorque
            )
        case (true, true):
            configureMotor(speed: 0, torque: Constants.brakeTorque)
        case (false, false):
            configureMotor(speed: 0, torque: Constants.coastingTorque)
        }
    }

    func remove(from scene: SKScene) {
        scene.physicsWorld.remove(rearJoint)
        scene.physicsWorld.remove(frontJoint)
        chassis.removeFromParent()
        rearWheel.removeFromParent()
        frontWheel.removeFromParent()
    }

    func isFullyOutside(_ rect: CGRect) -> Bool {
        let frame = chassis.calculateAccumulatedFrame()
            .union(rearWheel.calculateAccumulatedFrame())
            .union(frontWheel.calculateAccumulatedFrame())

        return frame.maxX < rect.minX
            || frame.minX > rect.maxX
            || frame.maxY < rect.minY
            || frame.minY > rect.maxY
    }

    private func configureMotor(speed: CGFloat, torque: CGFloat) {
        for joint in [rearJoint, frontJoint] {
            joint.rotationSpeed = speed
            joint.frictionTorque = torque
        }
    }

    private static func makeChassis() -> SKShapeNode {
        let chassis = SKShapeNode(rectOf: CGSize(width: 57, height: 16.5), cornerRadius: 5)
        chassis.name = "car-chassis"
        chassis.fillColor = NSColor(red: 0.95, green: 0.31, blue: 0.08, alpha: 1)
        chassis.strokeColor = NSColor(red: 0.20, green: 0.16, blue: 0.12, alpha: 1)
        chassis.lineWidth = 2
        chassis.zPosition = 10

        let cabinPath = CGMutablePath()
        cabinPath.move(to: CGPoint(x: -15.5, y: 7.5))
        cabinPath.addLine(to: CGPoint(x: -6.5, y: 18.5))
        cabinPath.addLine(to: CGPoint(x: 12, y: 18.5))
        cabinPath.addLine(to: CGPoint(x: 21.5, y: 7.5))
        cabinPath.closeSubpath()

        let cabin = SKShapeNode(path: cabinPath)
        cabin.fillColor = NSColor(red: 0.99, green: 0.49, blue: 0.15, alpha: 1)
        cabin.strokeColor = chassis.strokeColor
        cabin.lineWidth = 2
        cabin.zPosition = -1
        chassis.addChild(cabin)

        let window = SKShapeNode(rectOf: CGSize(width: 15, height: 7), cornerRadius: 2)
        window.position = CGPoint(x: 3, y: 12.5)
        window.fillColor = NSColor(red: 0.95, green: 0.93, blue: 0.84, alpha: 1)
        window.strokeColor = .clear
        cabin.addChild(window)

        let body = SKPhysicsBody(rectangleOf: CGSize(width: 55, height: 15.5))
        body.mass = 0.8
        body.friction = 0.65
        body.restitution = 0.02
        body.linearDamping = 0.16
        body.angularDamping = 1.1
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.chassis
        body.collisionBitMask = PhysicsCategory.terrain
        body.contactTestBitMask = 0
        chassis.physicsBody = body
        return chassis
    }

    private static func makeWheel() -> SKShapeNode {
        let wheel = SKShapeNode(circleOfRadius: Constants.wheelRadius)
        wheel.name = "car-wheel"
        wheel.fillColor = NSColor(red: 0.12, green: 0.14, blue: 0.13, alpha: 1)
        wheel.strokeColor = NSColor(red: 0.96, green: 0.88, blue: 0.70, alpha: 1)
        wheel.lineWidth = 1.5
        wheel.zPosition = 12

        let hub = SKShapeNode(circleOfRadius: 3.5)
        hub.fillColor = NSColor(red: 0.95, green: 0.31, blue: 0.08, alpha: 1)
        hub.strokeColor = .clear
        wheel.addChild(hub)

        let spokePath = CGMutablePath()
        spokePath.move(to: CGPoint(x: -6.5, y: 0))
        spokePath.addLine(to: CGPoint(x: 6.5, y: 0))
        spokePath.move(to: CGPoint(x: 0, y: -6.5))
        spokePath.addLine(to: CGPoint(x: 0, y: 6.5))
        let spokes = SKShapeNode(path: spokePath)
        spokes.strokeColor = NSColor(red: 0.96, green: 0.88, blue: 0.70, alpha: 0.8)
        spokes.lineWidth = 1.25
        wheel.addChild(spokes)

        let body = SKPhysicsBody(circleOfRadius: Constants.wheelRadius)
        body.mass = 0.22
        body.friction = 1.35
        body.restitution = 0.02
        body.linearDamping = 0.1
        body.angularDamping = 0.12
        body.usesPreciseCollisionDetection = true
        body.categoryBitMask = PhysicsCategory.wheel
        body.collisionBitMask = PhysicsCategory.terrain
        body.contactTestBitMask = 0
        wheel.physicsBody = body
        return wheel
    }
}
