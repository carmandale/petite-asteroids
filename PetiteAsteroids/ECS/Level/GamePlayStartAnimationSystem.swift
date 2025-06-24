/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A system that controls the gameplay start animation.
*/

import Combine
import SwiftUI
import RealityKit
import RealityKitContent

final class GamePlayStartAnimationSystem: System {
    var subscriptions: [AnyCancellable] = []

    init (scene: RealityKit.Scene) {
        scene.subscribe(to: ComponentEvents.DidChange.self,
                        componentType: GamePlayStateComponent.self,
                        onDidChangeGamePlayState).store(in: &subscriptions)
    }
    
    @MainActor
    func onDidChangeGamePlayState (event: ComponentEvents.DidChange) {
        guard let gamePlayState = event.entity.components[GamePlayStateComponent.self],
              let gameInfo = event.entity.components[GameInfoComponent.self] else { return }
        
        switch gamePlayState {
            case .introAnimation:
                if gameInfo.isTutorial {
                    playTutorialIntroAnimation(entity: event.entity)
                } else {
                    playMainIntroAnimation(entity: event.entity)
                }
            case .starting:
                // Position the level root so that the level's origin is at the bottom of the volume.
                event.entity.findEntity(named: "LevelRoot")?.position = [0, -GameSettings.volumeSize.height / 2, GameSettings.levelDepthOffset]
            default:
                break
        }
    }
    
    @MainActor
    func playTutorialIntroAnimation (entity: Entity) {
        guard let rotationalCamera = entity.first(withComponent: RotationalCameraFollowComponent.self)?.entity else {
            return
        }
        if var rotationalCameraFollow = rotationalCamera.components[RotationalCameraFollowComponent.self] {
            rotationalCameraFollow.mode = .fixed
            rotationalCameraFollow.angle = 0
            rotationalCameraFollow.targetAngle = 0
            rotationalCameraFollow.cameraTiltAmount = 0
            rotationalCameraFollow.cameraTiltTarget = 0
            rotationalCameraFollow.cameraVerticalOffset = rotationalCameraFollow.cameraVerticalOffsetBottom
            rotationalCamera.components.set(rotationalCameraFollow)
        }
    }
    
    @MainActor
    func playMainIntroAnimation (entity: Entity) {
        guard let characterEntity = entity.first(withComponent: CharacterMovementComponent.self)?.entity,
              let spawnPointEntity = entity.first(withComponent: CharacterSpawnPointComponent.self)?.entity.parent,
              let physicsRoot = entity.first(withComponent: PhysicsSimulationComponent.self)?.entity,
              let levelRoot = entity.findEntity(named: "LevelRoot") else {
            return
        }
        // Post the intro animation notification.
        entity.scene?.postRealityKitNotification(notification: "IntroAnimation")

        // Fade the butte to black.
        levelRoot.setFadeAmountForDescendants(fadeAmount: 1)

        // Make the character a sibling of the world so that it doesn't move with the world.
        let worldPosition = characterEntity.position(relativeTo: nil)
        let worldOrientation = characterEntity.orientation(relativeTo: nil)
        characterEntity.setParent(levelRoot.parent)
        characterEntity.setPosition(worldPosition, relativeTo: nil)
        characterEntity.setOrientation(worldOrientation, relativeTo: nil)
        
        // Rotate the butte to align the character with the spawn point.
        alignSpawnWithCharacter(characterEntity: characterEntity, spawnPointEntity: spawnPointEntity, physicsRoot: physicsRoot)

        // Animate the butte rising from the ground.
        let volumeHeight = GameSettings.volumeSize.height
        let startTransform = Transform(translation: [0.0,
                                                     -volumeHeight / 2 - GameSettings.butteRiseAnimationInitialOffset,
                                                     GameSettings.levelDepthOffset])
        let endTransform = Transform(translation: [0.0, -volumeHeight / 2, GameSettings.levelDepthOffset])
        let transformAction = FromToByAction<Transform>(from: startTransform, to: endTransform, mode: .parent, timing: .easeOut)
        if let transformAnimation = try? AnimationResource.makeActionAnimation(for: transformAction,
                                                                               duration: Double(GameSettings.butteRiseAnimationDuration),
                                                                               bindTarget: .transform) {
            levelRoot.playAnimation(transformAnimation)
        }
        
        Task { @MainActor in
            // Activate a speech bubble as the butte emerges from the ground.
            Task { @MainActor in
                try await Task.sleep(nanoseconds: UInt64(GameSettings.butteRiseSpeechBubbleAppearDelay * Float(NSEC_PER_SEC)))
                characterEntity.activateSpeechBubble(text: "Ohhhh, sooo talll!",
                                                     duration: GameSettings.butteRiseSpeechBubbleAppearDuration,
                                                     isDown: true)
            }
            
            // Wait for the butte to emerge from the ground.
            try await Task.sleep(nanoseconds: UInt64(GameSettings.butteRiseAnimationDuration * Float(NSEC_PER_SEC)))
            
            // Set the character back to being a descendant of the physics root.
            characterEntity.setParent(physicsRoot)
            characterEntity.setPosition(worldPosition, relativeTo: nil)
            characterEntity.setOrientation(worldOrientation, relativeTo: nil)
            
            // Enable shadows.
            entity.scene?.applyBakedShadowShaderParameters(parameters: BakedDirectionalLightShadowSystem.ShadowParameters(receivesShadows: true))
            // Fade the butte back in.
            levelRoot.playFadeAnimationOnDescendants(fadeType: .fadeIn,
                                                     duration: GameSettings.butteFadeInAnimationDuration,
                                                     timingFunction: .easeInQuad)
            try await Task.sleep(nanoseconds: UInt64(GameSettings.butteFadeInAnimationDuration * Float(NSEC_PER_SEC)))
            
            // Start the game.
            entity.components.set(GamePlayStateComponent.starting)
        }
    }
    
    @MainActor
    private func alignSpawnWithCharacter(characterEntity: Entity, spawnPointEntity: Entity, physicsRoot: Entity) {
        guard var rotationalCameraFollow = physicsRoot.components[RotationalCameraFollowComponent.self] else {
            return
        }
        rotationalCameraFollow.mode = .fixed
        var toCharacter = characterEntity.position(relativeTo: physicsRoot)
        toCharacter.y = 0
        var toSpawn = spawnPointEntity.position(relativeTo: physicsRoot)
        toSpawn.y = 0
        let angleBetweenCharacterAndSpawn = signedAngleBetween(from: toSpawn, to: toCharacter, axis: [0, 1, 0])
        rotationalCameraFollow.angle += angleBetweenCharacterAndSpawn
        rotationalCameraFollow.targetAngle = rotationalCameraFollow.angle
        rotationalCameraFollow.cameraTiltAmount = 0
        rotationalCameraFollow.cameraTiltTarget = 0
        rotationalCameraFollow.cameraVerticalOffset = rotationalCameraFollow.cameraVerticalOffsetBottom
        physicsRoot.components.set(rotationalCameraFollow)
    }
}
