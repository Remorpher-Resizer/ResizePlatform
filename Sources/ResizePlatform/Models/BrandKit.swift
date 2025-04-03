import Foundation
import SwiftUI

// Brand color definition
struct BrandColor: Identifiable, Codable {
    var id: String
    var name: String
    var colorHex: String
    var role: String? // Primary, Secondary, Accent, etc.
    var usage: String? // Description of when to use this color
    
    // Convert hex string to Color
    var color: Color {
        Color(hex: colorHex)
    }
}

// Font definition
struct BrandFont: Identifiable, Codable {
    enum FontType: String, Codable {
        case system
        case custom
        case googleFont
    }
    
    var id: String
    var name: String
    var type: FontType
    var role: String // Heading, Body, Caption, etc.
    var fontName: String // System font name or Google font name
    var fontURL: URL? // For custom fonts
    var fontWeights: [String] // Available weights: "Regular", "Bold", etc.
    var usage: String? // Guidance on how to use this font
    
    // Get font for a particular weight
    func font(weight: String, size: CGFloat) -> Font {
        switch type {
        case .system:
            return Font.system(size: size).weight(fontWeightFromString(weight))
        case .custom, .googleFont:
            // In a real app, we would register and load the custom font
            return Font.custom(fontName, size: size)
        }
    }
    
    // Convert string weight to Font.Weight
    private func fontWeightFromString(_ weight: String) -> Font.Weight {
        switch weight.lowercased() {
        case "ultralight": return .ultraLight
        case "thin": return .thin
        case "light": return .light
        case "regular": return .regular
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        case "heavy": return .heavy
        case "black": return .black
        default: return .regular
        }
    }
}

// Logo usage specifications
struct LogoUsage: Identifiable, Codable {
    enum LogoBackground: String, Codable {
        case light
        case dark
        case color
        case transparent
    }
    
    var id: String
    var name: String
    var background: LogoBackground
    var imageURL: URL
    var minimumSize: CGSize
    var safeZone: SafeZone
    var usage: String? // When to use this version of the logo
}

// Typography settings
struct TypographySettings: Codable {
    struct TextStyle: Codable {
        var fontId: String
        var size: CGFloat
        var weight: String
        var lineHeight: CGFloat
        var letterSpacing: CGFloat?
    }
    
    var heading1: TextStyle
    var heading2: TextStyle
    var heading3: TextStyle
    var body: TextStyle
    var caption: TextStyle
    var button: TextStyle
    
    // Custom styles
    var customStyles: [String: TextStyle]?
}

// Space settings for layout
struct SpacingSettings: Codable {
    var baseUnit: CGFloat // Base unit of spacing
    var scale: [CGFloat] // Scale of spacing (e.g., [1, 2, 4, 8, 16])
    
    // Get spacing value at a particular scale level
    func spacing(level: Int) -> CGFloat {
        guard level >= 0, level < scale.count else {
            return baseUnit // Default fallback
        }
        return baseUnit * scale[level]
    }
}

// Complete brand kit definition
struct BrandKit: Identifiable, Codable {
    var id: String
    var name: String
    var version: String
    var createdAt: Date
    var updatedAt: Date
    
    // Brand elements
    var colors: [BrandColor]
    var fonts: [BrandFont]
    var logos: [LogoUsage]
    var typography: TypographySettings
    var spacing: SpacingSettings
    
    // Brand guidelines
    var description: String?
    var guidelines: [String: String]? // Key-value pairs for specific guidelines
    
    // Version history
    var previousVersions: [String]?
    
    // Get primary color
    var primaryColor: BrandColor? {
        colors.first { $0.role?.lowercased() == "primary" }
    }
    
    // Get all colors for a particular role
    func colorsForRole(_ role: String) -> [BrandColor] {
        colors.filter { $0.role?.lowercased() == role.lowercased() }
    }
    
    // Get font for a specific role
    func fontForRole(_ role: String) -> BrandFont? {
        fonts.first { $0.role.lowercased() == role.lowercased() }
    }
    
    // Get the appropriate logo for a background type
    func logoForBackground(_ background: LogoUsage.LogoBackground) -> LogoUsage? {
        logos.first { $0.background == background }
    }
}

// Helper extension to create a Color from hex string
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
} 