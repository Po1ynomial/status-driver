import Foundation

package struct TetrominoCell: Equatable, Hashable, Sendable {
    package let x: Int
    package let y: Int

    package init(x: Int, y: Int) {
        self.x = x
        self.y = y
    }

    package func rotatedClockwise() -> TetrominoCell {
        TetrominoCell(x: y, y: -x)
    }
}

package enum TetrominoKind: CaseIterable, Equatable, Sendable {
    case i
    case o
    case t
    case s
    case z
    case j
    case l

    package var cells: [TetrominoCell] {
        switch self {
        case .i:
            [cell(-1, 0), cell(0, 0), cell(1, 0), cell(2, 0)]
        case .o:
            [cell(0, 0), cell(1, 0), cell(0, 1), cell(1, 1)]
        case .t:
            [cell(-1, 0), cell(0, 0), cell(1, 0), cell(0, 1)]
        case .s:
            [cell(-1, 0), cell(0, 0), cell(0, 1), cell(1, 1)]
        case .z:
            [cell(0, 0), cell(1, 0), cell(-1, 1), cell(0, 1)]
        case .j:
            [cell(-1, 0), cell(0, 0), cell(1, 0), cell(-1, 1)]
        case .l:
            [cell(-1, 0), cell(0, 0), cell(1, 0), cell(1, 1)]
        }
    }

    private func cell(_ x: Int, _ y: Int) -> TetrominoCell {
        TetrominoCell(x: x, y: y)
    }
}

package struct TetrominoBag: Sendable {
    private var remaining: [TetrominoKind] = []
    private var random: TetrominoRandom

    package init(seed: UInt64 = 0x544554524953) {
        random = TetrominoRandom(seed: seed)
    }

    package mutating func next() -> TetrominoKind {
        if remaining.isEmpty {
            remaining = TetrominoKind.allCases
            remaining.shuffle(using: &random)
        }
        return remaining.removeLast()
    }
}

package struct TetrominoDropClock: Equatable, Sendable {
    package private(set) var elapsed: TimeInterval = 0
    package var isFastDropping = false

    package init() {}

    package mutating func advance(by deltaTime: TimeInterval) -> Int {
        elapsed += min(max(deltaTime, 0), 0.1)
        let interval = isFastDropping ? 0.08 : 0.52
        let steps = Int(elapsed / interval)
        elapsed -= Double(steps) * interval
        return steps
    }

    package mutating func reset() {
        elapsed = 0
        isFastDropping = false
    }
}

private struct TetrominoRandom: RandomNumberGenerator, Sendable {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E3779B97F4A7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58476D1CE4E5B9
        value = (value ^ (value >> 27)) &* 0x94D049BB133111EB
        return value ^ (value >> 31)
    }
}
