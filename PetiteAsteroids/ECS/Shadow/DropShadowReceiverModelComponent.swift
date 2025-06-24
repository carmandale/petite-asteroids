/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
A component marking an entity that can receive drop shadows, and contains state data the drop-shadow system uses.
*/

import RealityKit

struct DropShadowReceiverModelComponent: Component {
    // Create shader parameters for each material instance in your scene.
    let characterPositionParameterHandle = ShaderGraphMaterial.parameterHandle(name: "CharacterPosition")
    let characterShadowPositionParameterHandle = ShaderGraphMaterial.parameterHandle(name: "CharacterShadowPosition")
    let worldToLevelMatrixParameterHandle = ShaderGraphMaterial.parameterHandle(name: "WorldToLevelMatrix")
    let rockFriendShadowRadiusHandle = ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowRadius")
    let rockFriendPositionParameterHandles = [
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition1"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition2"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition3"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition4"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition5"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition6"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition7"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition8"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition9"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition10"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition11"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendPosition12")
    ]
    let rockFriendShadowPositionParameterHandles = [
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition1"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition2"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition3"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition4"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition5"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition6"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition7"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition8"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition9"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition10"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition11"),
        ShaderGraphMaterial.parameterHandle(name: "RockFriendShadowPosition12")
    ]
    var shadowMaterialIndices = Set<Int>()
}
