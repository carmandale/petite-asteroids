/*
See the LICENSE.txt file for this sample’s licensing information.

Abstract:
Utility functions for generating mesh data.
*/

import RealityKit

struct PortalMeshDescriptor {
    var width: Float
    var height: Float
    var depth: Float
    var cornerRadius: Float
    var cornerSegmentCount: Int = 20
    var withBend: Bool
    var bendRadius: Float
    var bendSegmentCount: Int
}

@MainActor
func generateBackgroundPortal (descriptor: PortalMeshDescriptor) -> MeshResource {
    let bendSegmentAngle = 1 / Float(descriptor.bendSegmentCount) * .pi / 2

    var positions: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    
    var index: UInt32 = 0
    
    if descriptor.withBend {
        for segmentIndex in 0...descriptor.bendSegmentCount {
            let angle: Float = Float(segmentIndex) * bendSegmentAngle
            
            positions.append([-descriptor.width / 2,
                               -descriptor.height / 2 + (1 - cos(angle)) * descriptor.bendRadius,
                               descriptor.bendRadius - sin(angle) * descriptor.bendRadius])
            positions.append([descriptor.width / 2,
                              -descriptor.height / 2 + (1 - cos(angle)) * descriptor.bendRadius,
                              descriptor.bendRadius - sin(angle) * descriptor.bendRadius])
            
            if descriptor.bendSegmentCount > 0 {
                indices.append(contentsOf: [index + 0, index + 1, index + 2, index + 2, index + 1, index + 3])
                index += 2
            }
        }
    }
    
    let cornerSegmentAngle = 1 / Float(descriptor.cornerSegmentCount) * .pi / 2
    
    positions.append([-descriptor.width / 2, -descriptor.height / 2 + descriptor.bendRadius, 0])
    positions.append([descriptor.width / 2, -descriptor.height / 2 + descriptor.bendRadius, 0])
    positions.append([-descriptor.width / 2, descriptor.height / 2 - descriptor.cornerRadius, 0])
    positions.append([descriptor.width / 2, descriptor.height / 2 - descriptor.cornerRadius, 0])
    
    indices.append(contentsOf: [index + 0, index + 1, index + 2, index + 2, index + 1, index + 3])
    index += 2
    
    for segmentIndex in 0..<descriptor.cornerSegmentCount {
        let angle: Float = Float(segmentIndex + 1) * cornerSegmentAngle
        
        positions.append([-descriptor.width / 2 + descriptor.cornerRadius * (1 - cos(angle)),
                           descriptor.height / 2 - descriptor.cornerRadius + descriptor.cornerRadius * sin(angle),
                           0])
        positions.append([descriptor.width / 2 - descriptor.cornerRadius * (1 - cos(angle)),
                          descriptor.height / 2 - descriptor.cornerRadius + descriptor.cornerRadius * sin(angle),
                          0])
        
        indices.append(contentsOf: [index + 0, index + 1, index + 2, index + 2, index + 1, index + 3])
        index += 2
    }
    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = .init(positions)
    meshDescriptor.primitives = .triangles(indices)

    let meshResource = try! MeshResource.generate(from: [meshDescriptor])
    return meshResource
}

@MainActor func generateFloorPortal (descriptor: PortalMeshDescriptor) -> MeshResource {
    let bendSegmentAngle = 1 / Float(descriptor.bendSegmentCount) * .pi / 2
    
    var positions: [SIMD3<Float>] = []
    var indices: [UInt32] = []
    
    var index: UInt32 = 0
    
    if descriptor.withBend {
        for segmentIndex in 0...descriptor.bendSegmentCount {
            let angle: Float = .pi / 2 - Float(segmentIndex) * bendSegmentAngle
            
            positions.append([-descriptor.width / 2,
                              (1 - cos(angle)) * descriptor.bendRadius,
                              -descriptor.depth / 2 + descriptor.bendRadius - sin(angle) * descriptor.bendRadius])
            positions.append([descriptor.width / 2,
                              (1 - cos(angle)) * descriptor.bendRadius,
                              -descriptor.depth / 2 + descriptor.bendRadius - sin(angle) * descriptor.bendRadius])
            
            if descriptor.bendSegmentCount > 0 {
                indices.append(contentsOf: [index + 1, index + 2, index + 1, index + 1, index + 2, index + 3])
                index += 2
            }
        }
    }
    
    let cornerSegmentAngle = 1 / Float(descriptor.cornerSegmentCount) * .pi / 2
    
    positions.append([-descriptor.width / 2, 0, -descriptor.depth / 2 + descriptor.bendRadius])
    positions.append([descriptor.width / 2, 0, -descriptor.depth / 2 + descriptor.bendRadius])
    positions.append([-descriptor.width / 2, 0, descriptor.depth / 2 - descriptor.cornerRadius])
    positions.append([descriptor.width / 2, 0, descriptor.depth / 2 - descriptor.cornerRadius])
    
    indices.append(contentsOf: [index + 0, index + 2, index + 1, index + 1, index + 2, index + 3])
    index += 2
    
    for segmentIndex in 0..<descriptor.cornerSegmentCount {
        let angle: Float = Float(segmentIndex + 1) * cornerSegmentAngle
        
        positions.append([-descriptor.width / 2 + descriptor.cornerRadius * (1 - cos(angle)),
                           0,
                           descriptor.depth / 2 - descriptor.cornerRadius + descriptor.cornerRadius * sin(angle)])
        positions.append([descriptor.width / 2 - descriptor.cornerRadius * (1 - cos(angle)),
                          0,
                          descriptor.depth / 2 - descriptor.cornerRadius + descriptor.cornerRadius * sin(angle)])
        
        indices.append(contentsOf: [index + 0, index + 2, index + 1, index + 1, index + 2, index + 3])
        index += 2
    }

    var meshDescriptor = MeshDescriptor()
    meshDescriptor.positions = .init(positions)
    meshDescriptor.primitives = .triangles(indices)

    let meshResource = try! MeshResource.generate(from: [meshDescriptor])
    return meshResource
}
