package enum DrivingControl: Hashable {
    case driveRight
    case brakeOrDriveLeft
}

package enum DrivingInput: Equatable {
    case control(DrivingControl)
    case reset
    case toggleCar
}

package struct VehicleVisibilityState: Equatable, Sendable {
    package private(set) var isVisible = false

    package init() {}

    @discardableResult
    package mutating func toggle() -> Bool {
        isVisible.toggle()
        return isVisible
    }
}

package func drivingInput(forKeyCode keyCode: UInt16) -> DrivingInput? {
    switch keyCode {
    case 124, 2:
        .control(.driveRight)
    case 123, 0:
        .control(.brakeOrDriveLeft)
    case 15:
        .reset
    case 8:
        .toggleCar
    default:
        nil
    }
}
