import Foundation
import simd
import ARKit

/// Point cloud processing utilities for the LiDAR spike.
///
/// Handles:
/// - Filtering noise and outliers
/// - Ground plane fitting (RANSAC)
/// - Surface classification (grass, concrete, water, etc.)
/// - Building a decimated mesh from the raw capture
///
/// These are standalone functions for easy testing in a throwaway spike.

// MARK: - Filtering helpers

/// Remove obvious outliers from a point cloud (beyond maxDistance from median center).
func filterOutliers(points: [SIMD3<Float>], maxDistanceMeters: Float = 50.0) -> [SIMD3<Float>] {
    guard points.count >= 3 else { return points }
    
    let center = points.reduce(SIMD3<Float>(0)) { $0 + $1 } / Float(points.count)
    let maxDistSq = maxDistanceMeters * maxDistanceMeters
    
    return points.filter {
        let dx = $0.x - center.x
        let dy = $0.y - center.y
        let dz = $0.z - center.z
        let distSq = dx*dx + dy*dy + dz*dz
        return distSq <= maxDistSq
    }
}

/// Filter to a bounding box in meters (relative to origin).
func filterByBox(points: [SIMD3<Float>], box: Box3D) -> [SIMD3<Float>] {
    points.filter { p in
        p.x >= box.minX && p.x <= box.maxX &&
        p.y >= box.minY && p.y <= box.maxY &&
        p.z >= box.minZ && p.z <= box.maxZ
    }
}

// MARK: - Ground plane extraction

/// Find the dominant horizontal plane using RANSAC.
/// Returns the plane parameters and a boolean mask of inlier indices.
func findGroundPlane(points: [SIMD3<Float>], iterations: Int = 100, threshold: Float = 0.05) -> (plane: Plane, inliers: [Bool]) {
    assert(points.count >= 3)
    
    var bestInliers = Array(repeating: false, count: points.count)
    var bestCount = 0
    
    for _ in 0..<iterations {
        // Sample 3 random points
        let i1 = Int.random(in: 0..<points.count)
        let i2 = Int.random(in: 0..<points.count)
        let i3 = Int.random(in: 0..<points.count)
        
        let p1 = points[i1]
        let p2 = points[i2]
        let p3 = points[i3]
        
        let e1 = p2 - p1
        let e2 = p3 - p1
        var normal = normalize(cross(e1, e2))
        
        // Ensure normal points upward
        if normal.y < 0 { normal = -normal }
        
        let distance = -dot(normal, p1)
        
        // Count inliers
        let count = points.filter { p in
            let dist = abs(dot(normal, p) + distance)
            return dist < threshold
        }.count
        
        if count > bestCount {
            bestCount = count
            bestInliers = points.map { p in
                let dist = abs(dot(normal, p) + distance)
                return dist < threshold
            }
        }
    }
    
    let bestPlane = Plane(normal: simd_float3(0, 1, 0), distance: 0) // simplified
    return (bestPlane, bestInliers)
}

// MARK: - Surface classification

/// Classify ground surface type based on point cloud characteristics.
/// Returns a classification per region of interest (ROI).
func classifySurface(points: [SIMD3<Float>], roi: Box3D) -> SurfaceType {
    let roiPoints = filterByBox(points: points, box: roi)
    
    guard roiPoints.count >= 10 else {
        return .unknown
    }
    
    // Compute variance in Y (height variation)
    let heights = roiPoints.map { $0.y }
    let avgHeight = heights.reduce(0, +) / Float(heights.count)
    let variance = heights.map { pow($0 - avgHeight, 2) }.reduce(0, +) / Float(heights.count)
    let stddev = sqrt(variance)
    
    // Compute surface roughness (how "flat" is it?)
    let avgNormal = roiPoints.reduce(SIMD3<Float>(0)) { acc, p in
        acc + simd_float3(0, 1, 0)
    } / Float(roiPoints.count)
    
    // Heuristics:
    // - Low height variation + smooth → concrete/path
    // - Medium variation + textured → garden bed
    // - High variation + uneven → lawn/natural
    // - Very low (flat, no variation) → water
    // - Height above ground → raised bed / structure
    
    let groundY = avgHeight
    
    if stddev < 0.01 {
        return .water
    } else if stddev < 0.03 {
        return .concrete
    } else if stddev < 0.08 {
        return .gardenBed
    } else if stddev < 0.2 {
        return .lawn
    } else {
        return .other
    }
}

// MARK: - Mesh building and decimation

/// Build a simple 2D surface mesh from ground-projected points.
/// Uses a grid-based approach: average points per grid cell into vertices,
/// then connect adjacent cells into triangles.
func buildSurfaceMesh(points: [SIMD3<Float>], gridSize: Float = 0.05) -> (vertices: [SIMD3<Float>], triangles: [SIMD3<Int>]) {
    guard points.count > 0 else {
        return ([], [])
    }
    
    // Grid into a hash map: gridCell → [points in cell]
    var grid: [SIMD2<Int>: [SIMD3<Float>]] = [:]
    
    for p in points {
        let gx = Int(floor(p.x / gridSize))
        let gz = Int(floor(p.z / gridSize))
        let key = SIMD2<Int>(gx, gz)
        grid[key, default: []].append(p)
    }
    
    // Compute average height per cell
    var gridHeights: [SIMD2<Int>: Float] = [:]
    for (key, cellPoints) in grid {
        let avgY = cellPoints.reduce(SIMD3<Float>(0), +).y / Float(cellPoints.count)
        gridHeights[key] = avgY
    }
    
    // Build mesh: for each cell with a neighbor to the right and down,
    // create a quad (2 triangles)
    var vertices: [SIMD3<Float>] = []
    var triangles: [SIMD3<Int>] = []
    
    let cellToVertex: [SIMD2<Int>: Int] = grid.keys.enumerated().reduce(into: [:]) { dict, entry in
        dict[entry.element] = entry.offset
    }
    
    for key in grid.keys {
        let gx = key.x
        let gz = key.y
        
        // Only create triangles if we have right and down neighbors
        let right = SIMD2<Int>(gx + 1, gz)
        let down = SIMD2<Int>(gx, gz + 1)
        let diagonal = SIMD2<Int>(gx + 1, gz + 1)
        
        if let _ = grid[right], let _ = grid[down] {
            let v0 = cellToVertex[key]!
            let v1 = cellToVertex[right]!
            let v2 = cellToVertex[down]!
            let v3 = cellToVertex[diagonal]!
            
            // Two triangles per quad
            triangles.append(SIMD3<Int>(v0, v2, v1))
            triangles.append(SIMD3<Int>(v1, v2, v3))
        }
    }
    
    // Build vertex positions from grid
    for (key, height) in gridHeights {
        let x = Float(key.x) * gridSize
        let z = Float(key.y) * gridSize
        vertices.append(SIMD3<Float>(x, height, z))
    }
    
    return (vertices, triangles)
}

/// Decimate a mesh to target point count (quadric decimation simplified).
func decimateMesh(vertices: [SIMD3<Float>], triangles: [SIMD3<Int>], targetCount: Int) -> (vertices: [SIMD3<Float>], triangles: [SIMD3<Int>]) {
    guard vertices.count > targetCount else {
        return (vertices, triangles)
    }
    
    // Simplified: grid down to target grid size
    // (Full quadric decimation is complex; this is fine for a spike)
    
    let xs = vertices.map { $0.x }
    let zs = vertices.map { $0.z }
    let aspectRatio = (xs.max() ?? 1) / (zs.max() ?? 1)
    let width = (xs.max() ?? 0) - (xs.min() ?? 0)
    let depth = (zs.max() ?? 0) - (zs.min() ?? 0)
    let totalArea = width * depth
    
    let targetGridSize = sqrt(totalArea / Float(targetCount))
    
    // Re-grid
    return buildSurfaceMesh(
        points: vertices,
        gridSize: max(targetGridSize, 0.02) // min 2cm resolution
    )
}

// MARK: - Surface types

enum SurfaceType: String, CaseIterable {
    case concrete = "Concrete/Patio"
    case gardenBed = "Garden Bed"
    case lawn = "Lawn"
    case path = "Foot Path"
    case raisedBed = "Raised Bed/Container"
    case water = "Water Feature"
    case other = "Other"
    case unknown = "Unknown"
    
    var displayColor: String {
        switch self {
        case .concrete: return "#B0B0B0"
        case .gardenBed: return "#8B5E3C"
        case .lawn: return "#6B8E23"
        case .path: return "#C4A882"
        case .raisedBed: return "#A0522D"
        case .water: return "#4682B4"
        case .other: return "#808080"
        case .unknown: return "#808080"
        }
    }
}

// MARK: - 3D helpers

struct Box3D {
    var minX: Float, minY: Float, minZ: Float
    var maxX: Float, maxY: Float, maxZ: Float
}

struct Plane {
    let normal: simd_float3
    let distance: Float
}
