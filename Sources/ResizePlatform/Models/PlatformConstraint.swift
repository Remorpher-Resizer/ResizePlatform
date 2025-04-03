import Foundation

// Supported file formats for different platforms
enum FileFormat: String, Codable, CaseIterable {
    case jpg
    case jpeg
    case png
    case png8 // 8-bit PNG (required by some platforms)
    case gif
    case svg
    case html5
    
    var mimeType: String {
        switch self {
        case .jpg, .jpeg: return "image/jpeg"
        case .png, .png8: return "image/png"
        case .gif: return "image/gif"
        case .svg: return "image/svg+xml"
        case .html5: return "text/html"
        }
    }
    
    var fileExtension: String {
        switch self {
        case .jpg: return "jpg"
        case .jpeg: return "jpeg"
        case .png, .png8: return "png"
        case .gif: return "gif"
        case .svg: return "svg"
        case .html5: return "html"
        }
    }
}

// Requirement type for platform constraints
enum RequirementType: String, Codable {
    case required
    case recommended
    case optional
}

// Safe zone specifications for a platform
struct SafeZone: Codable {
    var top: CGFloat
    var right: CGFloat
    var bottom: CGFloat
    var left: CGFloat
    
    // Initialize with equal insets on all sides
    init(all: CGFloat) {
        self.top = all
        self.right = all
        self.bottom = all
        self.left = all
    }
    
    // Initialize with different insets
    init(top: CGFloat, right: CGFloat, bottom: CGFloat, left: CGFloat) {
        self.top = top
        self.right = right
        self.bottom = bottom
        self.left = left
    }
}

// Standard dimension set for a platform
struct PlatformDimension: Identifiable, Codable {
    var id: String
    var width: Int
    var height: Int
    var name: String
    var maxFileSizeKB: Int
    var supportedFormats: [FileFormat]
    var safeZone: SafeZone?
    var requirementType: RequirementType
    
    // Human-readable dimension (e.g., "300x250")
    var dimensionText: String {
        return "\(width)x\(height)"
    }
}

// Platform with all its constraints
struct Platform: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var dimensions: [PlatformDimension]
    var defaultMaxFileSizeKB: Int
    var defaultSupportedFormats: [FileFormat]
    var defaultSafeZone: SafeZone?
    var logoRequirement: Bool
    var specialRequirements: [String]?
    
    // Convenience method to get all standard dimensions
    var allDimensions: [String] {
        return dimensions.map { $0.dimensionText }
    }
    
    // Get a specific dimension by width and height
    func getDimension(width: Int, height: Int) -> PlatformDimension? {
        return dimensions.first { $0.width == width && $0.height == height }
    }
    
    // Get dimension by dimension string (e.g., "300x250")
    func getDimension(dimensionText: String) -> PlatformDimension? {
        let components = dimensionText.split(separator: "x")
        guard components.count == 2,
              let width = Int(components[0]),
              let height = Int(components[1]) else {
            return nil
        }
        
        return getDimension(width: width, height: height)
    }
} 