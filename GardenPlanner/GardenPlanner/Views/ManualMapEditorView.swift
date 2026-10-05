import SwiftUI
import SwiftData

/// Manual map editor — for non-LiDAR devices (or when user prefers).
/// Tools: rectangle, polygon, freehand drawing.
/// A width slider maps the drawn map to real-world meters, so areas are honest.

struct ManualMapEditorView: View {
    let garden: Garden
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var points: [[Double]] = []
    @State private var drawingMode: DrawingMode = .freehand
    @State private var isDrawing = false
    @State private var canvasSize: CGSize = .zero
    /// Real-world width of the map (the canvas width maps to this many meters).
    @State private var mapWidthMeters: Double = 10
    
    enum DrawingMode: CaseIterable {
        case rectangle
        case polygon
        case freehand
    }
    
    var body: some View {
        NavigationStack {
            VStack {
                // Drawing canvas
                DrawingCanvas(
                    points: $points,
                    mode: $drawingMode,
                    isDrawing: $isDrawing,
                    size: $canvasSize
                )
                .frame(minHeight: 300)
                .background(Color(.systemGray6))
                .cornerRadius(12)
                .padding(.horizontal)
                
                // Scale control
                VStack(alignment: .leading, spacing: 4) {
                    Text("Map width: \(String(format: "%.0f", mapWidthMeters)) m")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Slider(value: $mapWidthMeters, in: 3...30, step: 1)
                }
                .padding(.horizontal)
                
                // Drawing tools
                toolBar
            }
            .navigationTitle("Draw Map")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { saveZone() }
                        .disabled(!canSave)
                }
            }
        }
    }
    
    private var canSave: Bool {
        // Rectangle needs one corner tap; polygon/freehand need a closed shape.
        drawingMode == .rectangle ? points.count >= 1 : points.count >= 3
    }
    
    private var toolBar: some View {
        HStack(spacing: 16) {
            ForEach(DrawingMode.allCases, id: \.self) { mode in
                Button {
                    drawingMode = mode
                    points = []  // Clear for new drawing
                } label: {
                    Image(systemName: toolIcon(mode))
                        .font(.title3)
                        .frame(maxWidth: .infinity)
                        .padding(8)
                        .background(drawingMode == mode ? Color.blue : Color.gray.opacity(0.3))
                        .foregroundStyle(drawingMode == mode ? .white : .secondary)
                        .cornerRadius(8)
                }
            }
        }
        .padding(.horizontal)
    }
    
    private func toolIcon(_ mode: DrawingMode) -> String {
        switch mode {
        case .rectangle: return "rectangle.dashed"
        case .polygon: return "star.fill"
        case .freehand: return "pencil"
        }
    }
    
    private func saveZone() {
        guard !points.isEmpty else { return }
        
        // Convert canvas pixels to meters using the chosen map width.
        let width = canvasSize.width > 0 ? canvasSize.width : 300
        let scale = mapWidthMeters / Double(width)
        let scaled = points.map { [$0[0] * scale, $0[1] * scale] }
        
        let polygon: [[Double]]
        if drawingMode == .rectangle, let corner = scaled.first {
            // One tap = top-left corner; complete the rectangle to the canvas edges.
            let h = canvasSize.height > 0 ? canvasSize.height * scale : mapWidthMeters
            polygon = [
                [corner[0], corner[1]],
                [mapWidthMeters, corner[1]],
                [mapWidthMeters, h],
                [corner[0], h]
            ]
        } else {
            polygon = scaled
        }
        
        let newZone = SurfaceZone(
            name: nil,
            surfaceType: .gardenBed,
            polygonPoints: polygon,
            elevation: 0,
            lightLevel: 50,
            wetness: .moderate
        )
        
        garden.surfaceZones.append(newZone)
        modelContext.insert(newZone)
        dismiss()
    }
}

// MARK: - Drawing Canvas

struct DrawingCanvas: View {
    @Binding var points: [[Double]]
    @Binding var mode: ManualMapEditorView.DrawingMode
    @Binding var isDrawing: Bool
    @Binding var size: CGSize
    
    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                self.size = size
                
                let rect = CGRect(origin: .zero, size: size)
                switch mode {
                case .rectangle:
                    drawRectangle(context, rect)
                case .polygon:
                    drawPolygon(context, rect)
                case .freehand:
                    drawFreehand(context, rect)
                }
            }
            .gesture(tapGesture(geometry))
            // Freehand: drag to draw (much more natural than tap-tap-tap).
            .gesture(mode == .freehand ? dragGesture(geometry) : nil)
        }
    }
    
    private func canvasPoint(_ x: CGFloat, _ y: CGFloat, height: CGFloat) -> [Double] {
        [Double(x), Double(height - y)]
    }
    
    private func tapGesture(_ geometry: GeometryProxy) -> some Gesture {
        SpatialTapGesture().onEnded { value in
            let location = value.location
            let point = canvasPoint(location.x, location.y, height: geometry.size.height)
            
            switch mode {
            case .rectangle:
                points = [point]  // Store one corner; completed on save
                isDrawing = true
            case .polygon:
                points.append(point)
            case .freehand:
                points.append(point)
            }
        }
    }
    
    private func dragGesture(_ geometry: GeometryProxy) -> some Gesture {
        DragGesture(minimumDistance: 0).onChanged { value in
            let point = canvasPoint(value.location.x, value.location.y, height: geometry.size.height)
            if let last = points.last {
                let dx = point[0] - last[0]
                let dy = point[1] - last[1]
                if sqrt(dx*dx + dy*dy) > 5 {
                    points.append(point)
                }
            } else {
                points.append(point)
            }
            isDrawing = true
        }
    }
    
    private func drawRectangle(_ context: GraphicsContext, _ rect: CGRect) {
        guard !points.isEmpty else { return }
        
        var path = Path()
        path.move(to: CGPoint(x: CGFloat(points[0][0]), y: CGFloat(size.height - points[0][1])))
        path.addLine(to: CGPoint(x: CGFloat(rect.width), y: CGFloat(size.height - points[0][1])))
        path.addLine(to: CGPoint(x: CGFloat(rect.width), y: CGFloat(size.height - rect.height)))
        path.addLine(to: CGPoint(x: CGFloat(points[0][0]), y: CGFloat(size.height - rect.height)))
        path.closeSubpath()
        
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 2, dash: [5]))
    }
    
    private func drawPolygon(_ context: GraphicsContext, _ rect: CGRect) {
        guard points.count >= 2 else { return }
        
        var path = Path()
        for (i, point) in points.enumerated() {
            let p = CGPoint(x: CGFloat(point[0]), y: CGFloat(size.height - point[1]))
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        path.closeSubpath()
        
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 2))
        context.fill(path, with: .color(.blue.opacity(0.1)))
        
        // Draw points
        for point in points {
            let p = CGPoint(x: CGFloat(point[0]), y: CGFloat(size.height - point[1]))
            context.fill(Path(circle: p), with: .color(.blue))
        }
    }
    
    private func drawFreehand(_ context: GraphicsContext, _ rect: CGRect) {
        guard points.count >= 2 else { return }
        
        var path = Path()
        for (i, point) in points.enumerated() {
            let p = CGPoint(x: CGFloat(point[0]), y: CGFloat(size.height - point[1]))
            if i == 0 {
                path.move(to: p)
            } else {
                path.addLine(to: p)
            }
        }
        
        context.stroke(path, with: .color(.blue), style: StrokeStyle(lineWidth: 2))
    }
}

// MARK: - Helper extension

extension Path {
    init(circle center: CGPoint) {
        self.init { p in
            p.addEllipse(in: CGRect(x: center.x - 4, y: center.y - 4, width: 8, height: 8))
        }
    }
}
