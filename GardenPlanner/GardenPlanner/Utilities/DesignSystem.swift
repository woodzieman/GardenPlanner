import SwiftUI

/// Design system tokens for the app.
/// Consistent colors, typography, and spacing across all views.

// MARK: - Colors

extension Color {
    static let gardenPrimary = Color("PrimaryGreen")
    static let gardenSecondary = Color("SecondaryGreen")
    static let gardenAccent = Color("AccentGold")
    static let gardenBackground = Color("Background")
    static let gardenSurface = Color("Surface")
    
    // Semantic colors
    static let gardenWarning = Color("WarningOrange")
    static let gardenError = Color("ErrorRed")
    static let gardenSuccess = Color("SuccessGreen")
    
    // Convenience
    static func gardenGradient() -> LinearGradient {
        LinearGradient(
            colors: [.green.opacity(0.8), .green],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Typography

extension Font {
    static let gardenTitle = Font.system(.title, design: .rounded)
    static let gardenHeadline = Font.system(.headline, design: .rounded)
    static let gardenBody = Font.system(.body, design: .rounded)
    static let gardenCaption = Font.system(.caption, design: .rounded)
    static let gardenCaption2 = Font.system(.caption2, design: .rounded)
}

// MARK: - Spacing

enum GardenSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Corner radii

enum GardenCornerRadius {
    static let sm: CGFloat = 6
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
    static let circle: CGFloat = 999
}

// MARK: - Reusable components

/// A card with garden-style styling.
struct GardenCard<Content: View>: View {
    let content: () -> Content
    
    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }
    
    var body: some View {
        content()
            .padding(GardenSpacing.md)
            .background(Color(UIColor.systemGray6))
            .cornerRadius(GardenCornerRadius.md)
    }
}

/// A section header for garden-style forms.
struct SectionHeader: View {
    let title: String
    let subtitle: String?
    
    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: GardenSpacing.xs) {
            Text(title)
                .font(.headline)
            
            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, GardenSpacing.sm)
    }
}

/// Garden-themed button.
struct GardenButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let variant: ButtonVariant
    
    enum ButtonVariant {
        case primary
        case secondary
        case danger
    }
    
    init(
        title: String,
        icon: String? = nil,
        variant: ButtonVariant = .primary,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.variant = variant
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: GardenSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, GardenSpacing.md)
            .background(buttonColor)
            .foregroundColor(.white)
            .cornerRadius(GardenCornerRadius.md)
        }
    }
    
    private var buttonColor: Color {
        switch variant {
        case .primary:
            return Color(.systemBlue)
        case .secondary:
            return Color(.systemGray5)
        case .danger:
            return Color(.systemRed)
        }
    }
}

/// Slider with garden labeling (shaded ↔ full sun).
struct GardenSlider: View {
    let value: Binding<Double>
    let range: ClosedRange<Double>
    let step: Double
    let lowLabel: String
    let highLabel: String
    
    init(
        value: Binding<Double>,
        range: ClosedRange<Double> = 0...100,
        step: Double = 1,
        lowLabel: String,
        highLabel: String
    ) {
        self.value = value
        self.range = range
        self.step = step
        self.lowLabel = lowLabel
        self.highLabel = highLabel
    }
    
    var body: some View {
        VStack(spacing: GardenSpacing.xs) {
            Slider(value: value, in: range, step: step)
            
            HStack {
                Text(lowLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(highLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Safety helper

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - Color hex convenience

extension Color {
    /// Initialize from a "#RRGGBB" string (falls back to gray on bad input).
    init(hexString: String) {
        var value: UInt64 = 0
        let cleaned = hexString.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        let scanned = Scanner(string: cleaned)
        scanned.scanHexInt64(&value)
        if scanned.currentIndex == cleaned.endIndex && cleaned.count == 6 {
            let r = Double((value >> 16) & 0xFF) / 255
            let g = Double((value >> 8) & 0xFF) / 255
            let b = Double(value & 0xFF) / 255
            self = Color(red: r, green: g, blue: b)
        } else {
            self = .gray
        }
    }
}
