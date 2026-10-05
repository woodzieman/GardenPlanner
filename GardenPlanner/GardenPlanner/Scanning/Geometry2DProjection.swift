import Foundation
import simd

/// 2D projection utilities for converting 3D scans to garden maps.
///
/// Handles:
/// - Orthographic projection onto the ground plane
/// - Bounding box extraction
/// - Boundary polygon computation (convex hull)
/// - Coordinate system normalization (so maps are consistent)

// MARK: - 3D to 2D projection

/// Project 3D points to 2D top-down coordinates on the ground plane.
/// Returns a list of [x, z] coordinate pairs and the transformation matrix.
func projectTo2D(
    points: [SIMD3<Float>],
    groundPlane: Plane
) -> (points2D: [[Double]], transform: simd_float4x4) {
    assert(!points.isEmpty)
    
    // Build a transform matrix that maps world space to 2D garden space:
    // X axis → forward along garden
    // Y axis → right along garden
    // Z (height) → dropped
    
    let worldUp = simd_float3(0, 1, 0)
    var right = normalize(cross(groundPlane.normal, worldUp))
    // If normal is too close to (0, 1, 0), cross product is tiny; use (1, 0, 0)
    if abs(dot(groundPlane.normal, simd_float3(0, 1, 0))) > 0.95 {
        right = normalize(cross(groundPlane.normal, simd_float3(1, 0, 0)))
    }
    let forward = cross(right, groundPlane.normal)
    
    // Translation: center the garden at origin
    let centroid = points.reduce(SIMD3<Float>(repeating: 0)) { $0 + $1 } / Float(points.count)
    
    // 4x4 transform matrix: world → 2D
    // Columns: right, forward, up, origin
    let transform = simd_float4x4(
        simd_float4(right.x, right.y, right.z, 0),
        simd_float4(forward.x, forward.y, forward.z, 0),
        simd_float4(0, 0, 1, 0),
        simd_float4(-dot(right, centroid), -dot(forward, centroid), 0, 1)
    )
    
    // Project each point
    var points2D: [[Double]] = []
    for p in points {
        let projected = transform * simd_float4(p, 1)
        points2D.append([Double(projected.x), Double(projected.y)])
    }
    
    return (points2D, transform)
}

// MARK: - Boundary computation

/// Compute the bounding box of 2D points.
func boundingBox(points2D: [[Double]]) -> (minX: Double, maxX: Double, minZ: Double, maxZ: Double) {
    assert(!points2D.isEmpty)
    
    var minX: Double = .infinity
    var maxX: Double = -.infinity
    var minZ: Double = .infinity
    var maxZ: Double = -.infinity
    
    for p in points2D {
        minX = min(minX, p[0])
        maxX = max(maxX, p[0])
        minZ = min(minZ, p[1])
        maxZ = max(maxZ, p[1])
    }
    
    return (minX, maxX, minZ, maxZ)
}

/// Compute the convex hull of 2D points using Graham scan.
func convexHull(points2D: [[Double]]) -> [[Double]] {
    guard points2D.count >= 3 else {
        return points2D
    }
    
    // Find bottom-left point (minimum y, then minimum x)
    let origin = points2D.min(by: { p1, p2 in
        p1[1] < p2[1] || (p1[1] == p2[1] && p1[0] < p2[0])
    })!
    
    // Sort by polar angle from origin
    let sorted = points2D.filter { $0 != origin }.sorted { p1, p2 in
        let angle1 = atan2(p1[1] - origin[1], p1[0] - origin[0])
        let angle2 = atan2(p2[1] - origin[1], p2[0] - origin[0])
        return angle1 < angle2
    }
    
    // Graham scan
    var hull: [[Double]] = [origin]
    for point in sorted {
        while hull.count >= 2 {
            let a = hull[hull.count - 2]
            let b = hull[hull.count - 1]
            // Cross product of (b-a) × (point-b)
            let cross = (b[0] - a[0]) * (point[1] - b[1]) - (b[1] - a[1]) * (point[0] - b[0])
            if cross <= 0 {
                hull.removeLast()
            } else {
                break
            }
        }
        hull.append(point)
    }
    
    return hull
}

// MARK: - Simplification

/// Simplify a boundary polygon using the Ramer-Douglas-Peucker algorithm.
func simplifyPolygon(points: [[Double]], tolerance: Double) -> [[Double]] {
    guard points.count > 3 else { return points }
    
    // Find the point farthest from the line between endpoints
    var maxDist: Double = 0
    var maxIndex = 0
    
    let (x0, y0) = (points[0][0], points[0][1])
    let (x1, y1) = (points[points.count - 1][0], points[points.count - 1][1])
    
    for i in 1..<points.count - 1 {
        let dist = perpendicularDistance(
            point: points[i],
            lineStart: (x0, y0),
            lineEnd: (x1, y1)
        )
        if dist > maxDist {
            maxDist = dist
            maxIndex = i
        }
    }
    
    if maxDist > tolerance {
        let left = simplifyPolygon(points: Array(points[0...maxIndex]), tolerance: tolerance)
        let right = simplifyPolygon(points: Array(points[maxIndex...points.count - 1]), tolerance: tolerance)
        return Array(left.dropLast()) + Array(right)
    } else {
        return [points.first!, points.last!]
    }
}

private func perpendicularDistance(point: [Double], lineStart: (Double, Double), lineEnd: (Double, Double)) -> Double {
    let (x0, y0) = lineStart
    let (x1, y1) = lineEnd
    let (x2, y2) = (point[0], point[1])
    
    let numerator = abs((y1 - y0) * x2 - (x1 - x0) * y2 + x1 * y0 - y1 * x0)
    let denominator = sqrt(pow(y1 - y0, 2) + pow(x1 - x0, 2))
    
    return denominator > 0 ? numerator / denominator : 0
}

// MARK: - Scale computation

/// Compute an approximate real-world scale (meters) from the point cloud.
/// Uses the assumption that LiDAR point spacing gives relative distances.
func estimateScale(points: [SIMD3<Float>]) -> (widthMeters: Double, heightMeters: Double) {
    guard points.count > 0 else {
        return (0, 0)
    }
    
    let minX = points.map { $0.x }.min() ?? 0
    let maxX = points.map { $0.x }.max() ?? 0
    let minZ = points.map { $0.z }.min() ?? 0
    let maxZ = points.map { $0.z }.max() ?? 0
    
    return (Double(maxX - minX), Double(maxZ - minZ))
}
