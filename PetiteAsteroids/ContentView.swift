/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
The main view for rendering game content.
*/

import SwiftUI
import RealityKit
import RealityKitContent

struct ContentView: View {
    @Environment(AppModel.self) private var appModel
    @Environment(\.dismissWindow) private var dismissWindow
    @Environment(\.openWindow) private var openWindow
    
    private static let menuAttachmentID = "MenuAttachment"

    private let notificationTrigger = NotificationCenter.default.publisher(for: Notification.Name("RealityKit.NotificationTrigger"))
    
    @State private var dragStartPosition: SIMD3<Float> = .zero
    @State private var isDragging = false
    @GestureState private var isDragGestureActive = false
    
    var body: some View {
        RealityView { content, attachments in
            
            content.entities.removeAll()
            content.add(appModel.root)

            // Create a collision shape for the floor-input target.
            let floorColliderThickness: Float = 0.001
            let inputFloorShape = ShapeResource.generateBox(size: [GameSettings.volumeSize.width,
                                                                   floorColliderThickness,
                                                                   GameSettings.volumeSize.depth])
                .offsetBy(translation: [0, -GameSettings.volumeSize.height / 2 + floorColliderThickness / 2, 0])
            appModel.floorInputTarget.components.set(CollisionComponent(shapes: [inputFloorShape]))
            // Create a collision shape for the background-input target.
            let backgroundColliderThickness: Float = 0.1
            let inputBackgroundShape = ShapeResource.generateBox(size: [GameSettings.volumeSize.width,
                                                                        GameSettings.volumeSize.height,
                                                                        backgroundColliderThickness])
                .offsetBy(translation: [0, 0, -GameSettings.volumeSize.depth / 2 + backgroundColliderThickness / 2])
            appModel.backgroundInputTarget.components.set(CollisionComponent(shapes: [inputBackgroundShape]))

            // Add the menu attachment.
            if let menuAttachment = attachments.entity(for: Self.menuAttachmentID) {
                menuAttachment.position.y = -0.45
                menuAttachment.position.z = (GameSettings.volumeSize.depth / 2) - 0.3
                menuAttachment.scale = [0.7, 0.7, 0.7]
                appModel.root.addChild(menuAttachment)
            }
            
            if let tutorialPromptAttachment = attachments.entity(for: "TutorialPrompt") {
                tutorialPromptAttachment.position.y = (-GameSettings.volumeSize.height / 2) + 0.5
                appModel.tutorialPromptAttachmentRoot.addChild(tutorialPromptAttachment)
                appModel.root.addChild(appModel.tutorialPromptAttachmentRoot)
            }
        } update: { content, attachments in
            appModel.character.components[CharacterMovementComponent.self]?.canCollideWithLevelBoundary = !appModel.isDifficultyHard
            appModel.character.components[CharacterProgressComponent.self]?.isDifficultyHard = appModel.isDifficultyHard
            switch appModel.root.observable.components[GamePlayStateComponent.self] {
                case .introAnimation:
                    appModel.tutorialPromptAttachmentRoot.removeFromParent()
                case .starting, .playing(_):
                    if let rotationalCamera = appModel.root.first(withComponent: RotationalCameraFollowComponent.self)?.entity {
                        rotationalCamera.components[RotationalCameraFollowComponent.self]?.mode = .auto
                    }
                default:
                    break
            }
        } attachments: {
            Attachment(id: "TutorialPrompt") {
                TutorialPromptView(tutorialPromptAttachment: appModel.tutorialPromptAttachmentRoot)
            }
            
            Attachment(id: Self.menuAttachmentID) {
                MenuView()
            }
        }
        .onReceive(notificationTrigger, perform: appModel.onReceiveNotification)
        // A jump gesture.
        .gesture(SpatialTapGesture()
            // Target this gesture to only entities with the custom component.
            .targetedToEntity(where: .has(LevelInputTargetComponent.self))
             // Have the character jump when the gesture ends.
            .onEnded() { event in
                // Guard for the character's container entity.
                guard let containerEntity = appModel.character.parent else { return }
                
                // Convert the tap position to scene space.
                var targetPosition = event.convert(event.location3D, from: .local, to: .scene)
                
                // Next, convert the scene space position to one in the character's container entity space.
                targetPosition = containerEntity.convert(position: targetPosition, from: nil)

                // Pass the jump target position to a custom component for this game.
                appModel.character.components[CharacterMovementComponent.self]?.targetJumpPosition = targetPosition
                
                // Reset the jump buffer timer, which helps the game feel more responsive when players try to jump a few frames before hitting the
                // ground.
                appModel.character.components[CharacterMovementComponent.self]?.jumpBufferTimer = GameSettings.jumpBufferTime
            
            // Enable the gesture only when the player is actively playing the game.
            }, isEnabled: appModel.root.observable.components[GamePlayStateComponent.self]?.isPlayingGame == true)
        // A below-portal jump gesture.
        .gesture(SpatialTapGesture()
            .targetedToEntity(appModel.floorInputTarget)
            .onEnded() { event in
                // Raycast from an estimate of the player position to the interaction position to determine the target jump position.
                let interactionPosition = event.convert(event.location3D, from: .local, to: .scene)
                let playerPositionEstimate: SIMD3<Float> = [0, 0, 2.5]
                if let hit = appModel.root.scene?.raycast(origin: playerPositionEstimate,
                                                          direction: interactionPosition - playerPositionEstimate,
                                                          length: 5,
                                                          query: .nearest,
                                                          mask: GameCollisionGroup.shadowReceiver.collisionGroup).first {
                    let targetJumpPosition = appModel.character.parent?.convert(position: hit.position, from: nil)
                    appModel.character.components[CharacterMovementComponent.self]?.targetJumpPosition = targetJumpPosition
                    appModel.character.components[CharacterMovementComponent.self]?.jumpBufferTimer = GameSettings.jumpBufferTime
                }
            }, isEnabled: appModel.root.observable.components[GamePlayStateComponent.self]?.isPlayingGame == true)
        // A move gesture.
        .gesture(DragGesture(minimumDistance: 0.001, coordinateSpace: .local)
            .targetedToAnyEntity()
            .updating($isDragGestureActive) { value, state, transaction in
                state = true
            }
            .onChanged() { event in
                // Guard for the nearest physics simulation entity.
                guard let physicsRoot = PhysicsSimulationComponent.nearestSimulationEntity(for: appModel.character) else { return }
                
                // Get the drag position in scene space.
                let dragPosition = event.convert(event.location3D, from: .local, to: .scene)
                        
                // Start the drag if the player isn't already dragging.
                if !isDragging {
                    dragStartPosition = dragPosition
                    isDragging = true
                }
                
                // Convert the drag start and current position to the local space of the physics root.
                let dragPositionInPhysicsSpace = physicsRoot.convert(position: dragPosition, from: nil)
                var dragStartPositionInPhysicsSpace = physicsRoot.convert(position: dragStartPosition, from: nil)
                // Project the drag start position to an XZ plane that's parallel to the current drag position.
                dragStartPositionInPhysicsSpace.y = dragPositionInPhysicsSpace.y
                // Get the drag translation in the XZ plane of the local space of the physics root.
                let dragDelta = (dragPositionInPhysicsSpace - dragStartPositionInPhysicsSpace)

                // Move the drag start position so that it follows behind the current drag position so the player doesn't have to move their hand all
                // the way back to change direction.
                let dragDistance = length(dragDelta)
                let dragRadius = GameSettings.dragRadius / GameSettings.scale
                if dragDistance > dragRadius {
                    let normalizedDragDelta = dragDelta / dragDistance
                    dragStartPositionInPhysicsSpace = dragPositionInPhysicsSpace - normalizedDragDelta * dragRadius
                }

                // Update the scene-space drag-start position.
                dragStartPosition = physicsRoot.convert(position: dragStartPositionInPhysicsSpace, to: nil)
                
                // Normalize the scene space drag translation and pass it to the character movement component.
                let inputDirection = (dragPosition - dragStartPosition) / GameSettings.dragRadius
                appModel.character.components[CharacterMovementComponent.self]?.inputMoveDirection = inputDirection
            }, isEnabled: appModel.root.observable.components[GamePlayStateComponent.self]?.isPlayingGame == true)
        .onChange(of: isDragGestureActive) {
            if isDragGestureActive == false {
                // Set the character's move direction to zero.
                appModel.character.components[CharacterMovementComponent.self]?.inputMoveDirection = .zero
                // Stop dragging.
                isDragging = false
            }
            appModel.handInputVisualizer.components[HandInputVisualizerComponent.self]?.isDragActive = isDragGestureActive
            appModel.handInputVisualizerInsidePortal.components[HandInputVisualizerComponent.self]?.isDragActive = isDragGestureActive
        }
        .ornament(attachmentAnchor: .scene(.bottomFront), ornament: { SettingsOrnamentView() })
        .onVolumeViewpointChange(updateStrategy: .all) { _, volumeViewpoint in
            // Update the character animation component with the current viewpoint.
            if let (characterAnimation, _) = appModel.root.first(withComponent: CharacterAnimationComponent.self) {
                characterAnimation.components[CharacterAnimationComponent.self]?.volumeViewpoint = volumeViewpoint
                // Blink briefly to hide the transition.
                characterAnimation.components[CharacterAnimationComponent.self]?.eyeAppearTimer = GameSettings.eyeBlinkDuration
            }
        }
        .onChange(of: appModel.root.observable.components[GamePlayStateComponent.self]) {
            guard let gamePlayState = appModel.root.components[GamePlayStateComponent.self],
                  let gameInfo = appModel.root.components[GameInfoComponent.self] else {
                return
            }
            switch gamePlayState {
            case .assetsLoaded:
                // Fade the portals in after the assets finish loading.
                let opacityAction = FromToByAction<Float>(to: 1, timing: .easeInOut)
                if let opacityAnimation = try? AnimationResource.makeActionAnimation(for: opacityAction,
                                                                                     duration: GameSettings.portalFadeInDuration,
                                                                                     bindTarget: .opacity) {
                    appModel.floorPortalEntity.playAnimation(opacityAnimation)
                    appModel.backgroundPortalEntity.playAnimation(opacityAnimation)
                }
                // Remove the opacity components from the portals when the fade in animation completes.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(GameSettings.portalFadeInDuration))
                    appModel.floorPortalEntity.components.remove(OpacityComponent.self)
                    appModel.backgroundPortalEntity.components.remove(OpacityComponent.self)
                }
            case .outroAnimation:
                guard gameInfo.currentLevel == .main,
                      let (_, characterProgress) = appModel.root.first(withComponent: CharacterProgressComponent.self) else { return }
                // Record the player's run.
                let persistentData = PersistentData()
                persistentData.recordRun(duration: characterProgress.runDurationTimer,
                                         rockFriendsCollected: characterProgress.collectedRockFriends,
                                         isDifficultyHard: characterProgress.isDifficultyHard)
                persistentData.save()
            default:
                break
            }
        }
    }
}

#Preview(windowStyle: .volumetric) {
    ContentView()
        .environment(AppModel())
}
