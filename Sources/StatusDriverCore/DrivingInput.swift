package enum DrivingControl: Hashable {
    case driveRight
    case brakeOrDriveLeft
}

package enum EasterEggInputKey: Equatable, Sendable {
    case left
    case right
    case down
    case up
    case space
    case reset
    case toggle
}

package enum EasterEggInputPhase: Equatable, Sendable {
    case pressed
    case released
}

package struct EasterEggInputEvent: Equatable, Sendable {
    package let key: EasterEggInputKey
    package let phase: EasterEggInputPhase
    package let isRepeat: Bool

    package init(
        key: EasterEggInputKey,
        phase: EasterEggInputPhase,
        isRepeat: Bool = false
    ) {
        self.key = key
        self.phase = phase
        self.isRepeat = isRepeat
    }
}

package enum EasterEggMovement: Hashable, Sendable {
    case left
    case right
}

package enum EasterEggCommand: Equatable, Sendable {
    case toggle
    case reset
    case setMovement(EasterEggMovement, isPressed: Bool)
    case stepLeft
    case stepRight
    case setFastDrop(isPressed: Bool)
    case rotateClockwise
    case flap
}

package struct EasterEggInputRoute: Equatable, Sendable {
    package let command: EasterEggCommand?
    package let consumesEvent: Bool

    package init(command: EasterEggCommand?, consumesEvent: Bool) {
        self.command = command
        self.consumesEvent = consumesEvent
    }
}

package func routeEasterEggInput(
    _ event: EasterEggInputEvent,
    utility: EasterEggUtility
) -> EasterEggInputRoute {
    if event.key == .toggle {
        let command: EasterEggCommand? = event.phase == .pressed && !event.isRepeat
            ? .toggle
            : nil
        return EasterEggInputRoute(command: command, consumesEvent: true)
    }

    if event.key == .reset, utility != .none {
        let command: EasterEggCommand? = event.phase == .pressed && !event.isRepeat
            ? .reset
            : nil
        return EasterEggInputRoute(command: command, consumesEvent: true)
    }

    switch utility {
    case .car, .boat:
        let movement: EasterEggMovement? = switch event.key {
        case .left:
            .left
        case .right:
            .right
        case .down, .up, .space, .reset, .toggle:
            nil
        }
        guard let movement else {
            return EasterEggInputRoute(command: nil, consumesEvent: false)
        }
        return EasterEggInputRoute(
            command: .setMovement(movement, isPressed: event.phase == .pressed),
            consumesEvent: true
        )

    case .tetromino:
        switch event.key {
        case .left:
            return discreteRoute(event, command: .stepLeft)
        case .right:
            return discreteRoute(event, command: .stepRight)
        case .down:
            return EasterEggInputRoute(
                command: .setFastDrop(isPressed: event.phase == .pressed),
                consumesEvent: true
            )
        case .up:
            return discreteRoute(event, command: .rotateClockwise)
        case .space, .reset, .toggle:
            return EasterEggInputRoute(command: nil, consumesEvent: false)
        }

    case .packet:
        guard event.key == .space else {
            return EasterEggInputRoute(command: nil, consumesEvent: false)
        }
        let command: EasterEggCommand? = event.phase == .pressed && !event.isRepeat
            ? .flap
            : nil
        return EasterEggInputRoute(command: command, consumesEvent: true)

    case .none:
        return EasterEggInputRoute(command: nil, consumesEvent: false)
    }
}

private func discreteRoute(
    _ event: EasterEggInputEvent,
    command: EasterEggCommand
) -> EasterEggInputRoute {
    EasterEggInputRoute(
        command: event.phase == .pressed ? command : nil,
        consumesEvent: true
    )
}
