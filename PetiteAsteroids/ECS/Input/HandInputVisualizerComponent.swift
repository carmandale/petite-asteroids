/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A component that stores the state for the hand-input visualizer system.
*/

import RealityKit

struct HandInputVisualizerComponent: Component {
    let character: Entity
    var directionIndicator: Entity
    var directionIndicatorRadius: Float = 1.6
    var jumpIndicator: Entity
    var isDragActive = false
}
