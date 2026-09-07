import SpriteKit
import SwiftUI

struct TerrainView: View {
    @State private var scene: TerrainScene

    init() {
        let scene = TerrainScene(size: CGSize(width: 1_200, height: 700))
        scene.scaleMode = .resizeFill
        _scene = State(initialValue: scene)
    }

    var body: some View {
        SpriteView(scene: scene, options: [.ignoresSiblingOrder])
            .frame(minWidth: 720, minHeight: 440)
    }
}
