import Foundation
import Combine
import ARKit
import simd
import CoreVideo

/// LiDAR / ARKit garden capture and 2D-map processing.
///
/// Builds a point cloud from the ARKit scene-depth buffer (LiDAR on Pro
/// devices, stereo elsewhere) while the user walks the garden, extracts the
/// ground plane (RANSAC), and produces a 2D top-down boundary + heightmap.
///
/// Usage:
///   let scanner = LiDARScanner()
///   await scanner.startCapture()
///   // walk around the garden
///   await scanner.stopCapture()
///   let map = try await scanner.processToMap()
///
final class LiDARScanner: NSObject, ObservableObject {
    override init() {
        super.init()
    }
    @Published var status: ScannerStatus = .idle
    @Published var progress: Double = 0.0
    @Published var pointCloud: [SIMD3<Float>] = []
    @Published var heightmap: [Float] = []
    @Published var groundPlane: Plane? = nil

    /// For non-depth devices, store the manual map polygon instead.
    @Published var manualMapPolygon: [[Double]] = []

    var hasLiDAR: Bool = false
    var isDepthAvailable: Bool = false

    private var session: ARSession? = nil
    private var scanStartTime: Date? = nil
    private var isCapturing = false
    private let maxPoints = 30_000

    // MARK: - Public API

    /// Start a new ARKit capture session. Call this before walking the garden.
    @MainActor
    func startCapture() async {
        await checkCapabilities()

        let config = ARWorldTrackingConfiguration()
        config.worldAlignment = hasLiDAR ? .gravityAndHeading : .gravity
        if isDepthAvailable {
            config.frameSemantics = [.sceneDepth]
        }

        let newSession = ARSession()
        newSession.delegate = self
        newSession.run(config, options: [.resetTracking, .removeExistingAnchors])
        self.session = newSession

        isCapturing = true
        scanStartTime = Date()
        status = .capturing
        progress = 0.0
        print("📸 Capture started at \(Self.timestamp())")
    }

    /// Stop the capture session and kick off map post-processing.
    @MainActor
    func stopCapture() async {
        session?.pause()
        isCapturing = false
        if let start = scanStartTime {
            progress = min(1.0, Date().timeIntervalSince(start) / 60.0)
        }

        if !pointCloud.isEmpty {
            status = .processing
            do {
                _ = try await processToMap()
                status = .ready
            } catch {
                status = .error(message: "Processing error: \(error.localizedDescription)")
            }
        } else {
            status = .error(message: "No points captured. Walk around the garden and scan again.")
        }
    }

    /// Process the captured point cloud into a 2D top-down map + heightmap.
    func processToMap() async throws -> GardenMap {
        guard !pointCloud.isEmpty else {
            throw SpikeError.noPointCloud
        }

        print("🔍 Processing \(pointCloud.count) points...")

        let groundPoints = try extractGroundPlane(points: pointCloud)
        print("  ✓ Ground inliers: \(groundPoints.count)")

        let plane = fitGroundPlane(points: groundPoints)
        groundPlane = plane
        print("  ✓ Ground plane normal \(plane.normal), offset \(plane.distance)")

        let projected = projectTo2D(points: groundPoints, groundPlane: plane)
        print("  ✓ Projected \(projected.count) points to 2D")

        let boundary = computeBoundary(points2D: projected)
        print("  ✓ Boundary polygon: \(boundary.count) vertices")

        let heightData = computeHeightmap(points: pointCloud, groundPlane: plane, bounds: boundary)
        heightmap = heightData
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
            self.isDepthAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics([.sceneDepth])
            self.hasLiDAR = ARWorldTrackingConfiguration.isSupported && self.isDepthAvailable
        }
    }

    private static func timestamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f.string(from: Date())
    }

    private var scanDuration: TimeInterval {
        guard let start = scanStartTime else { return 0 }
        return Date().timeIntervalSince(start)
    }

    // MARK: - Ground plane (RANSAC)

    /// Find the dominant ground plane (normal ≈ up) via RANSAC.
    private func extractGroundPlane(points: [SIMD3<Float>]) throws -> [SIMD3<Float>] {
        guard points.count >= 3 else {
            throw SpikeError.noGroundPlane
        }

        let iterations = 60
        let inlierThreshold: Float = 0.05 // 5 cm tolerance
        let up = simd_float3(0, 1, 0)

        var bestInliers: [SIMD3<Float>] = []
        var bestScore = 0

        for _ in 0..<iterations {
            guard let s1 = points.randomElement(),
                  let s2 = points.randomElement(),
                  let s3 = points.randomElement() else { break }

            let e1 = s2 - s1
            let e2 = s3 - s1
            let n = simd_length(simd_cross(e1, e2))
            guard n > 0.001 else { continue }
            let normal = simd_cross(e1, e2) / n

            // Prefer upward-facing planes (ground, not ceiling).
            let biased = normal.y < 0 ? -normal : normal
            let alignment = simd_dot(biased, up)

            var inliers: [SIMD3<Float>] = []
            for p in points {
                let d = abs(simd_dot(biased, p - s1))
                if d < inlierThreshold { inliers.append(p) }
            }

            let score = inliers.count
            if score > bestScore && alignment > 0.5 {
                bestInliers = inliers
                bestScore = score
            }
        }

        // If we couldn't find a confident ground plane, fall back to the lowest points.
        guard bestScore > points.count / 10 else {
            print("⚠ No confident ground plane; using lowest 20% of points")
            let sorted = points.sorted { $0.y < $1.y }
            return Array(sorted.prefix(max(1, points.count / 5)))
        }

        return bestInliers
    }

    /// Fit a gravity-aligned plane (normal = up) through the point centroid.
    private func fitGroundPlane(points: [SIMD3<Float>]) -> Plane {
        guard !points.isEmpty else {
            return Plane(normal: simd_float3(0, 1, 0), distance: 0)
        }
        let centroid = points.reduce(SIMD3<Float>(0)) { $0 + $1 } / Float(points.count)
        let normal = simd_float3(0, 1, 0)
        let distance = -simd_dot(normal, centroid)
        return Plane(normal: normal, distance: distance)
    }

    // MARK: - 2D projection

    /// Project 3D points onto the ground plane (top-down). Returns [x, z] pairs.
    private func projectTo2D(points: [SIMD3<Float>], groundPlane: Plane) -> [[Double]] {
        let normal = groundPlane.normal
        var right = simd_normalize(simd_cross(normal, simd_float3(1, 0, 0)))
        if simd_length(right) < 0.5 {
            right = simd_normalize(simd_cross(normal, simd_float3(0, 0, 1)))
        }
        let forward = simd_cross(right, normal)

        var projected: [[Double]] = []
        projected.reserveCapacity(points.count)
        for p in points {
            // Project the point down onto the plane first.
            let proj = p + (-(simd_dot(normal, p) + groundPlane.distance) * normal)
            let x = Double(simd_dot(right, proj))
            let z = Double(simd_dot(forward, proj))
            projected.append([x, z])
        }
        return projected
    }

    // MARK: - Boundary (convex hull, Graham scan)

    private func computeBoundary(points2D: [[Double]]) -> [[Double]] {
        guard points2D.count >= 3 else { return points2D }

        let origin = points2D.min { p1, p2 in
            p1[1] < p2[1] || (p1[1] == p2[1] && p1[0] < p2[0])
        }!

        let sorted = points2D.sorted { p1, p2 in
            let a1 = atan2(p1[1] - origin[1], p1[0] - origin[0])
            let a2 = atan2(p2[1] - origin[1], p2[0] - origin[0])
            return a1 < a2
        }

        var hull: [[Double]] = []
        for p in sorted {
            while hull.count > 1 {
                let a = hull[hull.count - 2]
                let b = hull[hull.count - 1]
                let cross = (b[0] - a[0]) * (p[1] - b[1]) - (b[1] - a[1]) * (p[0] - b[0])
                if cross <= 0 { hull.removeLast() } else { break }
            }
            hull.append(p)
        }
        return hull
    }

    // MARK: - Heightmap

    private func computeHeightmap(points: [SIMD3<Float>], groundPlane: Plane, bounds: [[Double]]) -> [Float] {
        guard !bounds.isEmpty else { return [] }

        var minX: Double = .infinity, maxX: Double = -.infinity
        var minZ: Double = .infinity, maxZ: Double = -.infinity
        for p in bounds {
            minX = min(minX, p[0]); maxX = max(maxX, p[0])
            minZ = min(minZ, p[1]); maxZ = max(maxZ, p[1])
        }
        guard maxX > minX, maxZ > minZ else { return [] }

        let gridSize = 64
        let dx = (maxX - minX) / Double(gridSize - 1)
        let dz = (maxZ - minZ) / Double(gridSize - 1)

        // Bucket points into grid cells, tracking the max height above the plane.
        var cells = Array(repeating: 0.0, count: gridSize * gridSize)
        for p in points {
            let h = Double(simd_dot(groundPlane.normal, p) + groundPlane.distance)
            guard h > 0 else { continue }
            let gx = Int((Double(p.x) - minX) / dx)
            let gz = Int((Double(p.y) - minZ) / dz)
            guard (0..<gridSize).contains(gx), (0..<gridSize).contains(gz) else { continue }
            let idx = gz * gridSize + gx
            cells[idx] = max(cells[idx], h)
        }

        return cells.map { Float($0) }
    }
}

// MARK: - ARSessionDelegate: accumulate a point cloud from the scene-depth buffer

extension LiDARScanner: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard isCapturing,
              let depth = frame.sceneDepth else { return }

        accumulatePoints(from: depth.depthMap, camera: frame.camera)
    }

    /// Convert a scene-depth CVPixelBuffer (Float32 meters) into world-space points.
    private func accumulatePoints(from depthMap: CVPixelBuffer, camera: ARCamera) {
        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)
        guard let base = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let rowBytes = CVPixelBufferGetBytesPerRow(depthMap)
        guard width > 0, height > 0, rowBytes >= width * 4 else { return }

        let basePtr = base.assumingMemoryBound(to: Float.self)
        let projection = camera.projectionMatrix
        let inverseProjection = projection.inverse
        let cameraTransform = camera.transform

        var new: [SIMD3<Float>] = []
        new.reserveCapacity(256)

        let strideY = max(1, height / 32)
        let strideX = max(1, width / 32)

        for y in Swift.stride(from: 0, to: height, by: strideY) {
            for x in Swift.stride(from: 0, to: width, by: strideX) {
                let z = basePtr[y * (rowBytes / 4) + x]
                guard z.isFinite, z > 0.03, z < 25 else { continue }

                // Normalized device coordinates (buffer origin is top-left,
                // projection matrix origin is bottom-left).
                let ndcX = (2 * Float(x) / Float(width)) - 1
                let ndcY = 1 - (2 * Float(y) / Float(height))
                let clip = SIMD4<Float>(ndcX, ndcY, -1, 1)

                // Unproject to a ray direction in camera space.
                var dirCam = inverseProjection * clip
                let dirCam3 = SIMD3<Float>(dirCam.x, dirCam.y, dirCam.z)
                let len = simd_length(dirCam3)
                guard len > 0.0001 else { continue }
                let dirCamNorm = dirCam3 / len

                // Transform the ray into the world and advance it by the measured depth.
                let worldRay4 = cameraTransform * SIMD4<Float>(dirCamNorm.x, dirCamNorm.y, dirCamNorm.z, 0)
                let worldRay3 = SIMD3<Float>(worldRay4.x, worldRay4.y, worldRay4.z)
                let worldLen = simd_length(worldRay3)
                guard worldLen > 0.0001 else { continue }
                let dirWorld = worldRay3 / worldLen
                let origin = cameraTransform.columns.3
                let origin3 = SIMD3<Float>(origin.x, origin.y, origin.z)
                new.append(origin3 + dirWorld * z)
            }
        }

        guard !new.isEmpty else { return }

        Task { @MainActor in
            if self.pointCloud.count < self.maxPoints {
                self.pointCloud.append(contentsOf: new)
            }
            self.progress = min(1.0, Double(self.pointCloud.count) / Double(self.maxPoints))
        }
    }
}

// MARK: - Supporting types

enum ScannerStatus: Equatable {
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
        guard !boundary.isEmpty else { return (0, 0, 0, 0) }
        var minX: Double = .infinity, maxX: Double = -.infinity
        var minZ: Double = .infinity, maxZ: Double = -.infinity
        for p in boundary {
            minX = min(minX, p[0]); maxX = max(maxX, p[0])
            minZ = min(minZ, p[1]); maxZ = max(maxZ, p[1])
        }
        return (minX, maxX, minZ, maxZ)
    }

    var approximateArea: Double {
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
