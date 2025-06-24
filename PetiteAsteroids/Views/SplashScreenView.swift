/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A view showing the startup screen for the game.
*/

import RealityKit
import SwiftUI
import RealityKitContent

struct SplashScreenView: View {

    @AppStorage(PersistentData.rockFriendsCollectedKey) var rockFriendsCollectedMapData: Data?
    @AppStorage(PersistentData.skipTutorialKey) var skipTutorialData: Data?

    @Environment(AppModel.self) private var appModel

    private var rockFriendsCollectedMap: [String: Bool] {
        guard let rockFriendsCollectedMapData,
              let rockFriendsCollectedMap = try? JSONDecoder().decode([String: Bool].self, from: rockFriendsCollectedMapData) else {
            return [:]
        }
        return rockFriendsCollectedMap
    }
    
    private var skipTutorial: Bool {
        guard let skipTutorialData, let skipTutorial = try? JSONDecoder().decode(Bool.self, from: skipTutorialData) else {
            return false
        }
        return skipTutorial
    }
    
    private var rockFriendsCollected: Int {
        return rockFriendsCollectedMap.values.count(where: { $0 == true })
    }
    
    private var speechBubbleText: String {
        switch rockFriendsCollected {
        case 0: "Let's go find all my friends!"
        case 1...7: "Oh I found \(rockFriendsCollected) of my friends already!"
        case 8...9: "OK, a bunch more to find. Let's do this!"
        case 10: "Just two more. Sooo close!"
        case 11: "Ohhh, just one more. I wonder where it's hiding?"
        case 12: "Yay! I found all my friends!"
        default: "Found more rock friends than I should have!"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                TitleView(title: "PETITE ASTEROIDS")

                SpeechBubbleView(text: speechBubbleText)

                FriendsView(rockFriendsCollectedMap: rockFriendsCollectedMap)
                
                HStack(spacing: 60) {

                    Button(skipTutorial ? "Restart Game" : "Start Game") {
                        appModel.menuVisibility = .hidden
                        appModel.playLevel(gameLevel: .intro)
                    }
                    .buttonStyle(AttachmentButton())
                    
                    if skipTutorial {
                        Button("Restart Level") {
                            appModel.menuVisibility = .hidden
                            if appModel.root.components[GameInfoComponent.self]?.currentLevel == .main {
                                appModel.root.components.set(GamePlayStateComponent.starting)
                            } else {
                                // Position the character at a spawn point's radius in front of the butte before the main level intro animation plays.
                                if let mainLevel = appModel.root.components[GameAssetContainer.self]?.levels[.main],
                                   let physicsRoot = mainLevel.first(withComponent: PhysicsSimulationComponent.self)?.entity,
                                   let spawnPoint = physicsRoot.first(withComponent: CharacterSpawnPointComponent.self)?.entity.parent {
                                    var spawnPosition = spawnPoint.position(relativeTo: physicsRoot)
                                    spawnPosition.y = 0
                                    let spawnPointDistance = length(spawnPosition)
                                    appModel.character.setPosition([0, GameSettings.characterWorldRadius, spawnPointDistance * GameSettings.scale],
                                                                   relativeTo: appModel.levelRoot)
                                }
                                appModel.playLevel(gameLevel: .main)
                            }
                        }
                        .buttonStyle(AttachmentButton())
                    }
                }
            }
            .attachment()
            .ignoresSafeArea()
        }
    }
}

#Preview {
    let previewUserDefaults: UserDefaults = {
        let userDefaults = UserDefaults(suiteName: "preview_splash_screen_view")!

        let rockFriendsCollectedMap = [
            "RockPickup_1/RockFriend_Bowie": false,
            "RockPickup_2/RockFriend_Cavity": true,
            "RockPickup_3/RockFriend_Curvy": false,
            "RockPickup_4/RockFriend_Dottie": true,
            "RockPickup_5/RockFriend_Dubz": false,
            "RockPickup_6/RockFriend_Fleck": false,
            "RockPickup_7/RockFriend_Moon": false,
            "RockPickup_8/RockFriend_Rub": false,
            "RockPickup_9/RockFriend_Striped": true,
            "RockPickup_10/RockFriend_Wave": false,
            "RockPickup_11/RockFriend_Bowie": false,
            "RockPickup_12/RockFriend_Cavity": true
        ]

        userDefaults.set(rockFriendsCollectedMap, forKey: PersistentData.rockFriendsCollectedKey)
        return userDefaults
    }()

    SplashScreenView()
        .environment(AppModel())
        .frame(maxWidth: 700, maxHeight: 450)
        .defaultAppStorage(previewUserDefaults)
}
