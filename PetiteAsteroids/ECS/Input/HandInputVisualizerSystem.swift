/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A system that visualizes the player's gesture input.
*/

import RealityKit

struct HandInputVisualizerSystem: System {
    let query = EntityQuery(where: .has(HandInputVisualizerComponent.self))
     
    init(scene: Scene) {}
    
    func update(context: SceneUpdateContext) {
        for visualizerEntity in context.entities(matching: query, updatingSystemWhen: .rendering) {
            guard let visualizerComponent = visualizerEntity.components[HandInputVisualizerComponent.self],
                  let movementComponent = visualizerComponent.character.components[CharacterMovementComponent.self],
                  let characterParent = visualizerComponent.character.parent else {
                visualizerEntity.scale = .zero
                continue
            }
            // Set the position and direction of the direction indicator entity.
            let moveDirection = characterParent.convert(direction: movementComponent.inputMoveDirection, from: nil) * characterParent.scale.x
            let visualizerPosition = visualizerComponent.character.position + moveDirection * visualizerComponent.directionIndicatorRadius
            visualizerComponent.directionIndicator.look(at: visualizerComponent.character.position,
                                                        from: visualizerPosition,
                                                        relativeTo: characterParent)
            
            // Update the direction indicator's blend shape animation to animate it from a sphere to a cone.
            let dragPercent = remap(value: length(moveDirection), fromRange: 0...1)
            visualizerComponent.directionIndicator.components[BlendShapeWeightsComponent.self]?.weightSet[0].weights[0] = 1 - dragPercent
            visualizerComponent.directionIndicator.isEnabled = visualizerComponent.isDragActive
            
            // Update the jump indicator visual.
            if let targetPosition = movementComponent.targetJumpPosition {
                visualizerComponent.jumpIndicator.setPosition(targetPosition, relativeTo: characterParent)
                visualizerComponent.jumpIndicator.isEnabled = true
            } else {
                visualizerComponent.jumpIndicator.isEnabled = false
            }
        }
    }
}
