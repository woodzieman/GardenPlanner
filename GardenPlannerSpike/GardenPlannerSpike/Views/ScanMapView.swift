import SwiftUI
import simd

/// Display the 2D map + heightmap output from a LiDAR scan.
/// Shows the garden boundary, surface zones (if classified),
/// and a color-coded heightmap overlay.
struct ScanMapView: View {
    let gardenMap: GardenMap
    let pointCloud: [SIMD3<Float>]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Map info
                MapInfoView(gardenMap: gardenMap)
                
                // 2D top-down map
                TopDownMapView(
                    boundary: gardenMap.boundary,
                    pointCloud: pointCloud,
                    bounds: gardenMap.bounds
                )
                
                // Heightmap visualization
                HeightMapView(heightmap: gardenMap.heightmap)
                
                // Surface zone suggestions (from LiDAR classification)
                if !pointCloud.isEmpty {
                    SurfaceZonesView(points: pointCloud)
                }
            }
            .padding()
        }
        .navigationTitle("Scan Result")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Map information overlay

struct MapInfoView: View {
    let gardenMap: GardenMap
    
    var body: some View {
        HStack(spacing: 20) {
            StatBox(label: "Area", value: "\(String(format: "%.1f", gardenMap.approximateArea)) m²")
            StatBox(label: "Scan time", value: "\(String(format: "%.0f", gardenMap.scanDuration))s")
            StatBox(label: "Points", value: "\(gardenMap.boundary.count)")
        }
    }
}

struct StatBox: View {
    let label: String
    let value: String
    
    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(8)
        .background(.quaternary.opacity(0.3))
        .cornerRadius(8)
    }
}

// MARK: - 2D top-down map view

struct TopDownMapView: View {
    let boundary: [[Double]]
    let pointCloud: [SIMD3<Float>]
    let bounds: (minX: Double, maxX: Double, minZ: Double, maxZ: Double)
    
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width - 40 // account for padding
            let (minX, maxX, minZ, maxZ) = bounds
            
            let mapWidth = maxX > minX ? width : width
            let mapHeight = maxZ > minZ ? width * (maxZ - minZ) / (maxX > minX ? (maxX - minX) : 1) : width * 0.6
            
            Canvas { context, rect in
                // Background
                context.fill(Path(rect), with: .color(.quaternary.opacity(0.2)))
                
                // Draw the garden boundary
                if !boundary.isEmpty {
                    var path = Path()
                    
                    for (i, point) in boundary.enumerated() {
                        let x = rect.minX + (point[0] - minX) / (maxX - minX > 0 ? (maxX - minX) : 1) * (rect.width - 20)
                        let y = rect.minY + (point[1] - minZ) / (maxZ - minZ > 0 ? (maxZ - minZ) : 1) * (rect.height - 20)
                        
                        if i == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    
                    path.closeSubpath()
                    context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 2))
                    context.fill(path, with: .color(.blue.opacity(0.15)))
                }
                
                // Draw individual point cloud samples (thin line)
                if pointCloud.count < 5000 {
                    // Only draw dense clouds if we have few enough points
                    var dotPath = Path()
                    for point in pointCloud {
                        let x = rect.minX + (Double(point.x) - minX) / (maxX - minX > 0 ? (maxX - minX) : 1) * (rect.width - 20)
                        let y = rect.minY + (Double(point.z) - minZ) / (maxZ - minZ > 0 ? (maxZ - minZ) : 1) * (rect.height - 20)
                        dotPath.addEllipse(at: CGPoint(x: x, y: y), width: 1, height: 1)
                    }
                    context.fill(dotPath, with: .color(.gray.opacity(0.5)))
                }
            }
            .frame(width: mapWidth, height: min(mapHeight, 400))
            .aspectRatio(1, contentMode: fit)
        }
        .frame(height: 300)
        .padding()
        .background(.quaternary.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Heightmap visualization

struct HeightMapView: View {
    let heightmap: [Float]
    let gridSize = 64 // matches the spike's grid size
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Heightmap (color = elevation)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Canvas { context, rect in
                guard !heightmap.isEmpty else { return }
                
                let cellWidth = rect.width / Float(gridSize)
                let cellHeight = rect.height / Float(gridSize)
                
                let minH = heightmap.min() ?? 0
                let maxH = heightmap.max() ?? 1
                let range = maxH - minH > 0 ? maxH - minH : 1
                
                for y in 0..<gridSize {
                    for x in 0..<gridSize {
                        let idx = y * gridSize + x
                        let h = heightmap[idx]
                        
                        // Color: green (low/ground) → yellow → red (high/obstacles)
                        let t = (h - minH) / Float(range)
                        let color = elevationColor(t: Double(t))
                        
                        context.fill(
                            Path(
                                rect: CGRect(
                                    x: rect.minX + Float(x) * cellWidth,
                                    y: rect.minY + Float(y) * cellHeight,
                                    width: cellWidth,
                                    height: cellHeight
                                )
                            ),
                            with: .color(color)
                        )
                    }
                }
            }
            .frame(height: 250)
            .background(.quaternary.opacity(0.1))
            .cornerRadius(8)
            
            // Legend
            HStack {
                Text("0m")
                    .font(.caption2)
                
                Capsule()
                    .fill(Color.green)
                    .frame(width: 30, height: 10)
                
                Capsule()
                    .fill(Color.yellow)
                    .frame(width: 30, height: 10)
                
                Capsule()
                    .fill(Color.red)
                    .frame(width: 30, height: 10)
                
                Text("Max")
                    .font(.caption2)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func elevationColor(t: Double) -> Color {
        // Interpolate: green (0) → yellow (0.5) → red (1.0)
        if t < 0.5 {
            let u = t / 0.5
            return Color(
                red: Double(0.4 + u * 0.4),
                green: Double(0.55 + u * 0.25),
                blue: Double(0.15 + u * 0.05)
            )
        } else {
            let u = (t - 0.5) / 0.5
            return Color(
                red: Double(0.8 + u * 0.2),
                green: Double(0.8 - u * 0.65),
                blue: Double(0.2 - u * 0.15)
            )
        }
    }
}

// MARK: - Surface zone classification

struct SurfaceZonesView: View {
    let points: [SIMD3<Float>]
    
    var body: some View {
        VStack(spacing: 8) {
            Text("Suggested Surface Zones (from point cloud classification)")
                .font(.caption)
                .foregroundColor(.secondary)
            
            if let zones = classifySurfaceZones(points: points) {
                ForEach(zones, id: \.type.rawValue) { zone in
                    HStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(hex: zone.type.displayColor))
                            .frame(width: 20, height: 20)
                        
                        Text(zone.type.rawValue)
                            .font(.caption)
                        
                        Spacer()
                        
                        Text("\(String(format: "%.1f m²", zone.area))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                    .padding(8)
                    .background(.quaternary.opacity(0.2))
                    .cornerRadius(8)
                }
            } else {
                Text("Not enough data to classify surfaces.\nTry capturing a denser scan.")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
        .background(.quaternary.opacity(0.1))
        .cornerRadius(12)
    }
    
    private func classifySurfaceZones(points: [SIMD3<Float>]) -> [(type: SurfaceType, area: Double)]? {
        guard points.count >= 100 else {
            return nil
        }
        
        // Divide the point cloud into regions and classify each
        let minX = points.map { $0.x }.min() ?? 0
        let maxX = points.map { $0.x }.max() ?? 0
        let minZ = points.map { $0.z }.min() ?? 0
        let maxZ = points.map { $0.z }.max() ?? 0
        
        let midX = (minX + maxX) / 2
        let midZ = (minZ + maxZ) / 2
        
        // Split into 4 quadrants
        let quadrants: [(String, Box3D)] = [
            ("North-West", Box3D(minX: minX, minY: 0, minZ: midZ, maxX: midX, maxY: 10, maxZ: maxZ)),
            ("North-East", Box3D(minX: midX, minY: 0, minZ: midZ, maxX: maxX, maxY: 10, maxZ: maxZ)),
            ("South-West", Box3D(minX: minX, minY: 0, minZ: minZ, maxX: midX, maxY: 10, maxZ: midZ)),
            ("South-East", Box3D(minX: midX, minY: 0, minZ: minZ, maxX: maxX, maxY: 10, maxZ: midZ))
        ]
        
        var results: [(type: SurfaceType, area: Double)] = []
        
        for (label, box) in quadrants {
            let regionPoints = filterByBox(points: points, box: box)
            
            guard regionPoints.count >= 20 else {
                continue
            }
            
            let surfaceType = classifySurface(points: regionPoints, roi: box)
            
            // Estimate area from bounding box
            let width = box.maxX - box.minX
            let depth = box.maxZ - box.minZ
            let area = Double(width * depth)
            
            if area > 0.5 { // Only show significant regions
                results.append((surfaceType, area))
            }
        }
        
        return results
    }
}

// MARK: - Color helper

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex.hasPrefix("#") ? String(hex.dropFirst()) : hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        
        self.init(
            red: Double((rgb >> 16) & 0xFF) / 255.0,
            green: Double((rgb >> 8) & 0xFF) / 255.0,
            blue: Double(rgb & 0xFF) / 255.0
        )
    }
}

// MARK: - Previews (no real LiDAR data, but shows the UI)

#if DEBUG
struct ScanMapView_Previews: PreviewProvider {
    static var previews: some View {
        // Create a dummy garden map with a rectangular boundary
        let boundary = [
            [0, 0], [10, 0], [10, 8], [0, 8]
        ]
        
        let bounds: (minX: Double, maxX: Double, minZ: Double, maxZ: Double) = (0, 10, 0, 8)
        
        let dummyMap = GardenMap(
            boundary: boundary,
            heightmap: [],
            groundPlane: Plane(normal: simd_float3(0, 1, 0), distance: 0),
            scanDuration: 15.0
        )
        
        dummyMap.bounds = bounds // force bounds
        
        return ScanMapView(
            gardenMap: dummyMap,
            pointCloud: []
        )
    }
}
#endif
