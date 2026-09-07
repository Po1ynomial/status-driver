package enum DrivingControl: Hashable {
    case driveRight
    case brakeOrDriveLeft
}

package enum DrivingInput: Equatable {
    case control(DrivingControl)
    case reset
}

package func drivingInput(forKeyCode keyCode: UInt16) -> DrivingInput? {
    switch keyCode {
    case 124, 2:
        .control(.driveRight)
    case 123, 0:
        .control(.brakeOrDriveLeft)
    case 15:
        .reset
    default:
        nil
    }
}
