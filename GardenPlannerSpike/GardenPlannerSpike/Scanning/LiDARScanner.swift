import Foundation
import ARKit
import RealityKit
import simd

/// Phase 0: Core LiDAR capture and processing module.
///
/// This module wraps ARKit's SceneCapture API (iOS 17+) to capture
/// point cloud + mesh data from a garden space, then processes it
/// to extract the ground plane and produce a 2D top-down map + heightmap.
///
/// Usage:
///   let scanner = LiDARScanner()
///   await scanner.startCapture()
///   // walk around the garden
///   await scanner.stopCapture()
///   let map = await scanner.processToMap()
///
class LiDARScanner: ObservableObject {
    @Published var status: ScannerStatus = .idle
    @Published var progress: Double = 0.0
    @Published var pointCloud: [SIMD3<Float>] = []
    @Published var meshTriangles: [SIMD3<Int>] = []
    @Published var heightmap: [Float] = []
    @Published var groundPlane: Plane? = nil
    
    /// For non-LiDAR devices, store manual map polygon instead
    @Published var manualMapPolygon: [[Double]] = []
    
    var hasLiDAR: Bool = false
    var isDepthAvailable: Bool = false
    
    private var sceneCapture: SceneCapture? = nil
    private var session: ARKitSession? = nil
    private var scanStartTime: Date? = nil
    
    // MARK: - Public API
    
    /// Start a new LiDAR/ARKit capture session.
    /// Call this before walking the garden.
    func startCapture() async {
        do {
            status = .capturing
            progress = 0.0
            
            // Determine capability
            await checkCapabilities()
            
            // Create the session
            session = ARKitSession()
            
            // Request permissions and configure
            if hasLiDAR {
                let config = ARWorldTrackingConfiguration()
                config.worldAlignment = .gravityAndHeading
                config.sceneReconstruction = .mesh
            
                do {
                    try await session?.start(configuration: config)
                } catch {
                    status = .error(message: "Failed to start AR session: \(error.localizedDescription)")
                    return
                }
            } else {
                // Non-LiDAR path: use depth estimation from stereo cameras
                let config = ARWorldTrackingConfiguration()
                config.worldAlignment = .gravity
                config.sceneReconstruction = .mesh
            
                do {
                    try await session?.start(configuration: config)
                } catch {
                    status = .error(message: "Failed to start session: \(error.localizedDescription)")
                    return
                }
            }
            
            scanStartTime = Date()
            print("📸 Capture started at \(scanStartTime!, formatter: ShortDateFormatter())")
            
        } catch {
            status = .error(message: error.localizedDescription)
        }
    }
    
    /// Stop the capture session. Returns the raw mesh data.
    func stopCapture() async -> ARReferenceScene? {
        defer {
            session = nil
            scanStartTime = nil
        }
        
        guard let session = session else {
            return nil
        }
        
        do {
            // Save the current scene as a Reality File for later analysis
            let documents = try FileManager.default.url(
                for: .documentDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: false
            )
            
            let sceneURL = documents.appending(path: "spike_scan.reality")
            
            let sceneCapture = try SceneCapture(scene: .current)
            
            // This gives us an ARReferenceScene with all mesh/point cloud data
            let refScene = try await sceneCapture.saveAsRealityFile(
                at: sceneURL
            )
            
            print("✅ Scene captured: \(sceneURL.path)")
            
            // Now start post-processing
            status = .processing
            
            await extractGroundAndBuildMap(scene: refScene)
            
            status = .ready
            
        } catch {
            status = .error(message: "Capture failed: \(error.localizedDescription)")
            print("❌ Capture error: \(error)")
        }
        
        return nil
    }
    
    /// Process the captured scene into a 2D top-down map and heightmap.
    /// This is the core of the spike: can we get a usable garden layout?
    func processToMap() async throws -> GardenMap {
        guard !pointCloud.isEmpty else {
            throw SpikeError.noPointCloud
        }
        
        print("🔍 Processing \(pointCloud.count) points...")
        
        // Step 1: Extract ground plane using RANSAC
        let groundPoints = try extractGroundPlane(points: pointCloud)
        print("  ✓ Ground plane found: \(groundPoints.count) points")
        
        // Step 2: Fit the ground plane (gravity-aligned)
        let plane = fitGroundPlane(points: groundPoints)
        self.groundPlane = plane
        print("  ✓ Ground plane normal: \(plane.normal), offset: \(plane.distance)")
        
        // Step 3: Project ground points onto 2D (top-down)
        let projected = projectTo2D(points: groundPoints, groundPlane: plane)
        print("  ✓ Projected \(projected.count) points to 2D")
        
        // Step 4: Build a simple 2D polygon boundary
        let boundary = computeBoundary(points2D: projected)
        print("  ✓ Boundary polygon: \(boundary.count) vertices")
        
        // Step 5: Build the heightmap from all non-ground points
        let heightData = computeHeightmap(
            points: pointCloud,
            groundPlane: plane,
            bounds: boundary
        )
        print("  ✓ Heightmap: \(heightData.count) samples")
        
        return GardenMap(
            boundary: boundary,
            heightmap: heightData,
            groundPlane: plane,
            scanDuration: scanDuration
        )
    }
    
    // MARK: - Private helpers
    
    private func checkCapabilities() async {
        await MainActor.run {
            let config = ARWorldTrackingConfiguration()
            self.hasLiDAR = ARWorldTrackingConfiguration.supportedScenes.contains(.depthWith9DOF)
            self.isDepthAvailable = ARWorldTrackingConfiguration.supportedScenes.contains(.deviceDepth) ||
                                    ARWorldTrackingConfiguration.supportedScenes.contains(.depthWith9DOF)
        }
    }
    
    private func extractGroundAndBuildMap(scene: ARReferenceScene) async {
        do {
            // Extract point clouds from all frames
            let allPoints = scene.pointClouds.flatMap { frame in
                frame.points.map { SIMD3<Float(Float($0.x), Float($0.y), Float($0.z)) }
            }
            
            await MainActor.run {
                self.pointCloud = allPoints
            }
            
            // Extract meshes (triangulated surface)
            let allTriangles = scene.meshes.flatMap { mesh in
                mesh.indices.map { i0, i1, i2 in
                    SIMD3<Int(Int(i0), Int(i1), Int(i2)) }
                }
            }
            
            await MainActor.run {
                self.meshTriangles = allTriangles
            }
            
            // If we have point cloud data, process it now
            if !allPoints.isEmpty {
                _ = try? await processToMap()
            }
            
        } catch {
            await MainActor.run {
                self.status = .error(message: "Processing error: \(error.localizedDescription)")
            }
        }
    }
    
    /// RANSAC to find the ground plane (normal ≈ (0, 1, 0)).
    private func extractGroundPlane(points: [SIMD3<Float>]) throws -> [SIMD3<Float>] {
        let iterations = 50
        let inlierThreshold: Float = 0.05 // 5cm tolerance
        
        var bestInliers: [SIMD3<Float>] = []
        var bestScore = 0
        
        for _ in 0..<iterations {
            // Random sample: 3 points to define a plane
            guard points.count >= 3 else {
                break
            }
            
            let s1 = points.randomElement()!
            let s2 = points.randomElement()!
            let s3 = points.randomElement()!
            
            // Compute plane normal
            let e1 = s2 - s1
            let e2 = s3 - s1
            let normal = normalize(cross(e1, e2))
            
            // Ground plane should have normal pointing up (positive Y)
            // Flip if needed
            var finalNormal = normal
            if finalNormal.y < 0 {
                finalNormal = -normal
            }
            
            // Weight towards (0, 1, 0) — prefer horizontal planes
            let groundBias = simd_float3(0, 1, 0)
            let alignment = dot(normalize(finalNormal), groundBias)
            
            // Count inliers
            var inliers: [SIMD3<Float>] = []
            for p in points {
                let dist = abs(dot(p, finalNormal) + dot(-p, finalNormal))
                // Distance from point to plane
                let d = abs(dot(finalNormal, p) - dot(finalNormal, s1))
                
                if d < inlierThreshold {
                    inliers.append(p)
                }
            }
            
            // Score: inliers * alignment with upward normal
            let score = Double(inliers.count) * Double(alignment)
            if score > Double(bestScore) * Double(alignment) || bestInliers.isEmpty {
                if inliers.count > bestScore {
                    bestInliers = inliers
                    bestScore = inliers.count
                }
            }
        }
        
        // If we got a decent ground plane, return it
        guard bestScore > points.count * 0.1 else {
            // Couldn't find a ground plane — return all points as "potential ground"
            print("⚠ Could not find clear ground plane, returning all points")
            return points
        }
        
        return bestInliers
    }
    
    /// Fit a gravity-aligned ground plane from inlier points.
    private func fitGroundPlane(points: [SIMD3<Float>]) -> Plane {
        // Simple: use the median of heights to define the ground plane
        let medians = points.reduce(SIMD3<Float>(0)) { acc, p in
            acc + p
        } / Float(points.count)
        
        // Ground plane: passes through centroid, normal is (0, 1, 0)
        let normal = simd_float3(0, 1, 0)
        let distance = -dot(normal, medians)
        
        return Plane(normal: normal, distance: distance)
    }
    
    /// Project 3D points onto the 2D ground plane (top-down, XZ → XY).
    private func projectTo2D(points: [SIMD3<Float>], groundPlane: Plane) -> [[Double]] {
        let normal = groundPlane.normal
        let offset = groundPlane.distance
        
        // Create a basis for the ground plane
        // We want: X axis → forward/in garden, Y axis → right/side
        let arbitrary = simd_float3(1, 0, 0)
        var right = normalize(cross(normal, arbitrary))
        // If normal was too close to (1, 0, 0), use (0, 0, 1)
        if abs(dot(normal, simd_float3(1, 0, 0))) > 0.9 {
            right = normalize(cross(normal, simd_float3(0, 0, 1)))
        }
        let forward = cross(right, normal)
        
        var projected: [[Double]] = []
        for p in points {
            // Project onto the plane
            let projected3D = p + (-(dot(normal, p) + offset) * normal)
            
            // 2D coordinates relative to plane origin
            let x = Double(dot(right, projected3D))
            let z = Double(dot(forward, projected3D))
            
            projected.append([x, z])
        }
        
        return projected
    }
    
    /// Compute the convex hull / boundary polygon of 2D points.
    private func computeBoundary(points2D: [[Double]]) -> [[Double]] {
        guard points2D.count >= 3 else {
            return points2D
        }
        
        // Graham scan convex hull (simple, O(n log n))
        let origin = points2D.min(by: { p1, p2 in
            p1[1] < p2[1] || (p1[1] == p2[1] && p1[0] < p2[0])
        })!
        
        let sorted = points2D.sorted { p1, p2 in
            let a1 = atan2(p1[1] - origin[1], p1[0] - origin[0])
            let a2 = atan2(p2[1] - origin[1], p2[0] - origin[0])
            return a1 < a2
        }
        
        var hull: [[Double]] = [origin]
        for p in sorted {
            while hull.count > 1 {
                let a = hull[hull.count - 2]
                let b = hull[hull.count - 1]
                let cross = (b[0] - a[0]) * (p[1] - b[1]) - (b[1] - a[1]) * (p[0] - b[0])
                if cross <= 0 {
                    hull.removeLast()
                } else {
                    break
                }
            }
            hull.append(p)
        }
        
        return hull
    }
    
    /// Compute a heightmap (grid of elevation values) from 3D points.
    private func computeHeightmap(points: [SIMD3<Float>], groundPlane: Plane, bounds: [[Double]]) -> [Float] {
        guard !bounds.isEmpty else {
            return []
        }
        
        // Find bounding box
        var minX: Double = .infinity
        var maxX: Double = -.infinity
        var minZ: Double = .infinity
        var maxZ: Double = -.infinity
        
        for p in bounds {
            minX = min(minX, p[0])
            maxX = max(maxX, p[0])
            minZ = min(minZ, p[1])
            maxZ = max(maxZ, p[1])
        }
        
        let gridSize = 64 // resolution for the heightmap
        let dx = (maxX - minX) / Double(gridSize - 1)
        let dz = (maxZ - minZ) / Double(gridSize - 1)
        
        var heightmap: [Float] = []
        
        for y in 0..<gridSize {
            for x in 0..<gridSize {
                let targetX = minX + Double(x) * dx
                let targetZ = minZ + Double(y) * dz
                
                // Find all 3D points near this grid cell
                var heights: [Float] = []
                for p in points {
                    let projX = dot(simd_float3(1, 0, 0), simd_float3(Float(p.x), Float(p.y), Float(p.z)))
                    // Simple projection onto the ground plane for height estimation
                    let distanceToPlane = abs(dot(groundPlane.normal, p) + groundPlane.distance)
                    heights.append(distanceToPlane)
                }
                
                let height = heights.isEmpty ? 0 : heights.min() ?? 0
                heightmap.append(height)
            }
        }
        
        return heightmap
    }
    
    private var scanDuration: TimeInterval {
        guard let start = scanStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }
}

// MARK: - Supporting types

enum ScannerStatus {
    case idle
    case capturing
    case processing
    case ready
    case error(message: String)
}

struct GardenMap {
    let boundary: [[Double]] // convex hull in 2D
    let heightmap: [Float]   // grid of heights (row-major)
    let groundPlane: Plane
    let scanDuration: TimeInterval
    
    var bounds: (minX: Double, maxX: Double, minZ: Double, maxZ: Double) {
        guard !boundary.isEmpty else {
            return (0, 0, 0, 0)
        }
        
        var minX: Double = .infinity
        var maxX: Double = -.infinity
        var minZ: Double = .infinity
        var maxZ: Double = -.infinity
        
        for p in boundary {
            minX = min(minX, p[0])
            maxX = max(maxX, p[0])
            minZ = min(minZ, p[1])
            maxZ = max(maxZ, p[1])
        }
        
        return (minX, maxX, minZ, maxZ)
    }
    
    var approximateArea: Double {
        // Shoelace formula
        guard boundary.count >= 3 else { return 0 }
        
        var sum = 0.0
        for i in 0..<boundary.count {
            let j = (i + 1) % boundary.count
            sum += boundary[i][0] * boundary[j][1]
            sum -= boundary[j][0] * boundary[i][1]
        }
        return abs(sum) / 2.0
    }
}

enum SpikeError: Error {
    case noPointCloud
    case noGroundPlane
    case noBoundary
}

private let ShortDateFormatter: (Date, formatter: Any) -> String = {
    let f = DateFormatter()
    f.dateFormat = "HH:mm:ss"
    return f.string(from: $0)
}
