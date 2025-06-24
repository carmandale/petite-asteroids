/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A system that calculates and then passes data to material instances that render drop shadows on objects.
*/

import Combine
import RealityKit
import RealityKitContent

final class DropShadowSystem: System {
    
    let characterProxyShape: ShapeResource
    let rockFriendQuery = EntityQuery(where: .has(RockPickupComponent.self))
    let dropShadowReceiverQuery = EntityQuery(where: .has(DropShadowReceiverModelComponent.self))
    var subscriptions: [AnyCancellable] = .init()

    required init (scene: Scene) {
        characterProxyShape = ShapeResource.generateSphere(radius: GameSettings.characterRadius * GameSettings.scale)
        scene.subscribe(to: ComponentEvents.DidAdd.self,
                        componentType: DropShadowReceiverComponent.self,
                        onDidAddDropShadowReceiverComponent).store(in: &subscriptions)
    }
    
    @MainActor func onDidAddDropShadowReceiverComponent (
        event: ComponentEvents.DidAdd
    ) {
        setShadowReceiverModelsRecursively(entity: event.entity)
    }

    func update(context: SceneUpdateContext) {
        // Guard for the physics root and the character entity.
        guard let physicsRoot = context.first(withComponent: PhysicsSimulationComponent.self)?.entity,
                let character = context.first(withComponent: CharacterMovementComponent.self)?.entity else { return }
        
        // Get the matrix that transforms from world space to level space.
        let worldToLevelMatrix = physicsRoot.transformMatrix(relativeTo: nil).inverse
        
        // Raycast downward to determine where the character's shadow lands.
        if let (characterPosition, characterShadowPosition) = calculateParametersForShadow(character, physicsRoot) {
            
            // Raycast downward for each rock friend to determine where their shadows land.
            var rockFriendPositions = [(position: SIMD3<Float>, shadowPosition: SIMD3<Float>)]()
            for rockFriend in context.entities(matching: rockFriendQuery, updatingSystemWhen: .rendering) {
                if let (friendPosition, friendShadowPosition) = calculateParametersForShadow(rockFriend, physicsRoot) {
                    rockFriendPositions.append((friendPosition, friendShadowPosition))
                }
            }
            
            // Set the shader parameters in a custom function.
            for dropShadowReceiver in context.entities(matching: dropShadowReceiverQuery, updatingSystemWhen: .rendering) {
                setShadowShaderParameters(
                    entity: dropShadowReceiver,
                    characterPosition: characterPosition,
                    characterShadowPosition: characterShadowPosition,
                    worldToLevelMatrix: worldToLevelMatrix,
                    rockFriendPositions: rockFriendPositions)
            }
        }
    }
    
    @MainActor
    func calculateParametersForShadow(_ entity: Entity, _ physicsRoot: Entity) -> (characterPosition: SIMD3<Float>, shadowPosition: SIMD3<Float>)? {
        // Get the origin relative to the physics root entity.
        let origin = entity.position(relativeTo: physicsRoot)
        
        // Peform a raycast against the scene downward from the origin.
        return if let hit = entity.scene?.raycast(
            origin: origin,
            direction: [0, -1, 0],
            query: .nearest,
            // Use a mask to make sure you're only performing a raycast against entities in the shadow receiver group.
            mask: GameCollisionGroup.shadowReceiver.collisionGroup,
            relativeTo: physicsRoot
        ).first {
            // Return a tuple when the raycast is successful.
            (origin, hit.position)
        } else {
            nil
        }
    }

    @MainActor
    func setShadowReceiverModelsRecursively (entity: Entity) {
        if let modelComponent = entity.components[ModelComponent.self] {
            for (index, material) in modelComponent.materials.enumerated() {
                // Skip the material if it's not a graph material that takes a shadow position input.
                guard let shaderGraphMaterial = material as? ShaderGraphMaterial,
                      shaderGraphMaterial.parameterNames.contains("CharacterPosition") else { continue }

                // Add a drop-shadow receiver model component to the entity if it doesn't have one.
                if !entity.components.has(DropShadowReceiverModelComponent.self) {
                    entity.components.set(DropShadowReceiverModelComponent())
                }

                // Store the material index of the shadow shader.
                entity.components[DropShadowReceiverModelComponent.self]?.shadowMaterialIndices.insert(index)
            }
        }

        for child in entity.children {
            setShadowReceiverModelsRecursively(entity: child)
        }
    }
    
    /// Sets the shadow shader parameters for all materials on an entity.
    @MainActor
    func setShadowShaderParameters (
        entity: Entity,
        characterPosition: SIMD3<Float>,
        characterShadowPosition: SIMD3<Float>,
        worldToLevelMatrix: simd_float4x4,
        rockFriendPositions: [(SIMD3<Float>, SIMD3<Float>)]
    ) {
        // Guard for the entity's model component and a custom shadow receiver component.
        guard let modelComponent = entity.components[ModelComponent.self],
                let shadowReceiver = entity.components[DropShadowReceiverModelComponent.self] else { return }
        
        // Iterate through each shadow material on this model and apply the shadow shader parameters.
        for index in shadowReceiver.shadowMaterialIndices {
            guard var shaderGraphMaterial = modelComponent.materials[index] as? ShaderGraphMaterial else { continue }

            try? shaderGraphMaterial.setParameter(
                handle: shadowReceiver.worldToLevelMatrixParameterHandle,
                value: .float4x4(worldToLevelMatrix))
            try? shaderGraphMaterial.setParameter(
                handle: shadowReceiver.characterPositionParameterHandle,
                value: .simd3Float(characterPosition))
            try? shaderGraphMaterial.setParameter(
                handle: shadowReceiver.characterShadowPositionParameterHandle,
                value: .simd3Float(characterShadowPosition))

            for friendIndex in 0..<rockFriendPositions.count {
                let rockFriendPosition = rockFriendPositions[friendIndex].0
                let rockFriendShadowPosition = rockFriendPositions[friendIndex].1
                try? shaderGraphMaterial.setParameter(
                    handle: shadowReceiver.rockFriendPositionParameterHandles[friendIndex],
                    value: .simd3Float(rockFriendPosition))
                try? shaderGraphMaterial.setParameter(
                    handle: shadowReceiver.rockFriendShadowPositionParameterHandles[friendIndex],
                    value: .simd3Float(rockFriendShadowPosition))
            }
            
            try? shaderGraphMaterial.setParameter(
                handle: shadowReceiver.rockFriendShadowRadiusHandle,
                value: .float(0.45))
            
            // Set the material directly onto the entity with the model component.
            entity.components[ModelComponent.self]?.materials[index] = shaderGraphMaterial
        }
    }
}
