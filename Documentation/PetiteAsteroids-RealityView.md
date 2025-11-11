## RealityView Pipeline Overview

`ContentView` owns the RealityKit scene and binds it to SwiftUI by instantiating a `RealityView`. Each render pass clears the scene and reattaches the shared `AppModel.root`, so RealityKit always reflects the latest game graph.

```26:52:PetiteAsteroids/ContentView.swift
RealityView { content, attachments in
    content.entities.removeAll()
    content.add(appModel.root)
    // ... existing code ...
```

`AppModel.root` is populated during initialization with core gameplay entities (portals, input targets, audio, speech bubble) and becomes the anchor for everything else the game loads.

## Asset Loading and Preparation

The `AppModel` kicks off asset loading as soon as it initializes. Assets are described by `assetsToLoad`, then fetched in parallel using an async task group. Each task returns a `LoadResult` tagged with an `AssetType`, allowing preparation logic to branch cleanly by kind of resource.

```115:152:PetiteAsteroids/AppModel.swift
Task.detached(priority: .high) {
    await self.loadGameAssets()
}
// ... existing code ...
floorPortalEntity.components.set(PortalComponent(target: emptyPortalWorld, clippingMode: .disabled, crossingMode: .plane(.positiveY)))
```

```13:53:PetiteAsteroids/AppModel+LoadAssets.swift
func loadGameAssets() async {
    root.components.set(GamePlayStateComponent.loadingAssets)
    await withTaskGroup(of: LoadResult.self) { loadAssetsTaskGroup in
        for asset in assetsToLoad {
            loadAssetsTaskGroup.addTask {
                switch asset.type {
                case .level, .character, .inputVisualizer:
                    guard let entity = try? await Entity(named: asset.name, in: realityKitContentBundle) else {
                        fatalError("Attempted to load entity \(asset.name), but failed.")
                    }
                    return LoadResult(entity: entity, type: asset.type)
                case .audio:
                    // ... existing code ...
```

As each asset completes, `prepareGameAssets` configures it: levels receive physics and portal-crossing components, character assets gain animation and portal support, and input visualizers are cloned for both the main world and the portal interior. The prepared data is cached inside a `GameAssetContainer` component on `root` so other systems can pull levels and animation roots without reloading.

```40:86:PetiteAsteroids/AppModel+LoadAssets.swift
let (levels, characterAnimationRoot) = await prepareGameAssets(loadAssetsTaskGroup: loadAssetsTaskGroup)
// ... existing code ...
let assetContainerComponent = GameAssetContainer(levels: levels,
                                                 characterAnimationRoot: characterAnimationRoot)
root.components.set(assetContainerComponent)
```

## Portal Construction and Activation

Before assets finish loading, the `AppModel` provisions floor and background portals that render into an empty placeholder world. Each portal uses a generated mesh and starts fully transparent. When `GamePlayStateComponent` transitions to `.assetsLoaded`, `ContentView` fades both portals in by animating their opacity and removes the opacity components once the animation completes. Later, `playLevel` swaps the portal targets to the new level’s worlds and ensures they have `WorldComponent` markers so the content renders correctly.

```138:165:PetiteAsteroids/AppModel.swift
let emptyPortalWorld = Entity(components: [WorldComponent()])
root.addChild(emptyPortalWorld)
// ... existing code ...
backgroundPortalEntity.components.set(ModelComponent(mesh: generateBackgroundPortal(descriptor: portalMeshDescriptor),
                                                     materials: [PortalMaterial()]))
backgroundPortalEntity.position = [0, 0, -GameSettings.volumeSize.depth / 2]
backgroundPortalEntity.components.set(OpacityComponent(opacity: 0))
```

```191:217:PetiteAsteroids/ContentView.swift
case .assetsLoaded:
    let opacityAction = FromToByAction<Float>(to: 1, timing: .easeInOut)
    if let opacityAnimation = try? AnimationResource.makeActionAnimation(for: opacityAction,
                                                                         duration: GameSettings.portalFadeInDuration,
                                                                         bindTarget: .opacity) {
        appModel.floorPortalEntity.playAnimation(opacityAnimation)
        appModel.backgroundPortalEntity.playAnimation(opacityAnimation)
    }
    Task { @MainActor in
        try? await Task.sleep(for: .seconds(GameSettings.portalFadeInDuration))
        appModel.floorPortalEntity.components.remove(OpacityComponent.self)
        appModel.backgroundPortalEntity.components.remove(OpacityComponent.self)
    }
```

```219:224:PetiteAsteroids/AppModel.swift
levelPortalWorldRoot.components.set(WorldComponent())
floorPortalEntity.components[PortalComponent.self]?.targetEntity = levelPortalWorldRoot
backgroundPortalWorldRoot.components.set(WorldComponent())
backgroundPortalEntity.components[PortalComponent.self]?.targetEntity = backgroundPortalWorldRoot
```

## Observable Components for State

`AppModel` is annotated with `@Observable`, making it available through SwiftUI’s environment. RealityKit state is kept inside components attached to `root`. `GamePlayStateComponent` double-serves as both a component and an enum describing the current lifecycle stage, enabling SwiftUI bindings like gesture toggles or animation triggers to react to game state without extra glue code.

```55:75:PetiteAsteroids/AppModel.swift
var root = Entity(components: [
    GamePlayStateComponent.loadingAssets,
    LoadingTrackerComponent(),
    GameInfoComponent(currentLevel: .intro),
    AudioCueStorageComponent()
])
// ... existing code ...
```

`ContentView` reads these component values through the `observable` proxy. Gestures only enable while `GamePlayStateComponent` reports active gameplay, physics boundaries toggle when difficulty changes, and portal fade logic lives in an `onChange` handler keyed to the same component.

```60:122:PetiteAsteroids/ContentView.swift
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
// ... existing code ...
.gesture(SpatialTapGesture()
    .targetedToEntity(where: .has(LevelInputTargetComponent.self))
    // ... existing code ...
```

Additional components like `GameInfoComponent`, `LoadingTrackerComponent`, and `NotificationComponent` live on `root` and let other systems speak a common ECS vocabulary—SwiftUI just observes the same entity graph rather than duplicating state.

## Level Activation via Component Data

Once assets are ready, `playLevel` uses the cached `GameAssetContainer` component to obtain the level entity and install it under `levelRoot`. The method aligns physics transforms, re-parents shared visualizers, and updates portal targets. It also configures the rotational camera component based on spawn metadata and finally transitions gameplay state to `.introAnimation`, which downstream systems observe to start their sequences.

```168:243:PetiteAsteroids/AppModel.swift
guard let gamePlayAssets = root.components[GameAssetContainer.self],
      let level = gameLevel == .intro ? gamePlayAssets.levels[gameLevel]?.clone(recursive: true) : gamePlayAssets.levels[gameLevel],
      let physicsRoot = level.findEntity(named: "PhysicsRoot"),
      let levelPortalWorldRoot = physicsRoot.findEntity(named: "Level"),
      let backgroundPortalWorldRoot = physicsRoot.findEntity(named: "Background"),
      let spawnPointOrigin = physicsRoot.first(withComponent: CharacterSpawnPointComponent.self)?.entity.parent else {
    return
}
// ... existing code ...
root.components.set(GamePlayStateComponent.introAnimation)
```

By storing level entities and animation roots inside a component, the game keeps asset lifetimes inside RealityKit’s entity graph. SwiftUI only needs to trigger `playLevel`, and each subsystem—physics, audio, animation—receives the correct entities through shared component access.
