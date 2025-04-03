import Foundation
import AppKit

// Result of a constraint check
struct ConstraintViolation {
    enum Severity {
        case error
        case warning
        case info
    }
    
    var message: String
    var severity: Severity
    var propertyName: String
    var value: String
    var requirement: String
}

class PlatformConstraintChecker {
    
    // Main validation function for design
    func validateDesign(design: Design, 
                        platform: Platform, 
                        dimension: PlatformDimension,
                        exportSettings: ExportSettings) -> [ConstraintViolation] {
        
        var violations: [ConstraintViolation] = []
        
        // Check dimensions
        violations.append(contentsOf: validateDimensions(design: design, dimension: dimension))
        
        // Check file format compatibility
        violations.append(contentsOf: validateFileFormat(exportSettings: exportSettings, dimension: dimension))
        
        // Check file size (estimated)
        if let estimatedFileSize = estimateFileSize(design: design, exportSettings: exportSettings) {
            violations.append(contentsOf: validateFileSize(fileSize: estimatedFileSize, dimension: dimension))
        }
        
        // Check safe zones
        if let safeZone = dimension.safeZone {
            violations.append(contentsOf: validateSafeZones(design: design, safeZone: safeZone))
        }
        
        // Check for logo presence if required
        if platform.logoRequirement {
            violations.append(contentsOf: validateLogoPresence(design: design))
        }
        
        return violations
    }
    
    // Validate physical file against constraints
    func validateFile(fileURL: URL, platform: Platform, dimension: PlatformDimension) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        
        do {
            // Check file size
            let fileAttributes = try FileManager.default.attributesOfItem(atPath: fileURL.path)
            if let fileSize = fileAttributes[.size] as? Int {
                let fileSizeKB = fileSize / 1024
                violations.append(contentsOf: validateFileSize(fileSize: fileSizeKB, dimension: dimension))
            }
            
            // Check file format
            let fileExtension = fileURL.pathExtension.lowercased()
            let formatMatches = dimension.supportedFormats.contains { $0.fileExtension == fileExtension }
            
            if !formatMatches {
                let supportedFormatsString = dimension.supportedFormats.map { $0.fileExtension }.joined(separator: ", ")
                violations.append(ConstraintViolation(
                    message: "File format not supported by platform",
                    severity: .error,
                    propertyName: "fileFormat",
                    value: fileExtension,
                    requirement: "Must be one of: \(supportedFormatsString)"
                ))
            }
            
            // Check image dimensions if it's an image file
            if let image = NSImage(contentsOf: fileURL) {
                let imageSize = image.size
                
                if Int(imageSize.width) != dimension.width || Int(imageSize.height) != dimension.height {
                    violations.append(ConstraintViolation(
                        message: "Image dimensions do not match required size",
                        severity: .error,
                        propertyName: "dimensions",
                        value: "\(Int(imageSize.width))x\(Int(imageSize.height))",
                        requirement: "\(dimension.width)x\(dimension.height)"
                    ))
                }
                
                // Additional checks for PNG-8 if required
                if dimension.supportedFormats.contains(.png8) && fileExtension == "png" {
                    // We would need deeper analysis of the PNG data here
                    // This is a placeholder for actual PNG bit depth analysis
                    violations.append(ConstraintViolation(
                        message: "PNG bit depth analysis not implemented yet",
                        severity: .warning,
                        propertyName: "pngFormat",
                        value: "Unknown bit depth",
                        requirement: "PNG-8 (8-bit indexed color)"
                    ))
                }
            }
            
        } catch {
            violations.append(ConstraintViolation(
                message: "Error analyzing file: \(error.localizedDescription)",
                severity: .error,
                propertyName: "fileAccess",
                value: "Error",
                requirement: "File must be accessible for validation"
            ))
        }
        
        return violations
    }
    
    // Validate dimensions
    private func validateDimensions(design: Design, dimension: PlatformDimension) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        
        if Int(design.width) != dimension.width || Int(design.height) != dimension.height {
            violations.append(ConstraintViolation(
                message: "Design dimensions do not match platform requirements",
                severity: .error,
                propertyName: "dimensions",
                value: "\(Int(design.width))x\(Int(design.height))",
                requirement: "\(dimension.width)x\(dimension.height)"
            ))
        }
        
        return violations
    }
    
    // Validate file format
    private func validateFileFormat(exportSettings: ExportSettings, dimension: PlatformDimension) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        
        if !dimension.supportedFormats.contains(exportSettings.format) {
            let supportedFormatsString = dimension.supportedFormats.map { $0.rawValue }.joined(separator: ", ")
            violations.append(ConstraintViolation(
                message: "Export format not supported by platform",
                severity: .error,
                propertyName: "fileFormat",
                value: exportSettings.format.rawValue,
                requirement: "Must be one of: \(supportedFormatsString)"
            ))
        }
        
        // Special checks for PNG-8
        if dimension.supportedFormats.contains(.png8) && exportSettings.format == .png {
            if exportSettings.pngColorType != .indexed {
                violations.append(ConstraintViolation(
                    message: "Platform requires PNG-8 (indexed color)",
                    severity: .error,
                    propertyName: "pngColorType",
                    value: exportSettings.pngColorType.rawValue,
                    requirement: "indexed (PNG-8)"
                ))
            }
        }
        
        return violations
    }
    
    // Validate file size
    private func validateFileSize(fileSize: Int, dimension: PlatformDimension) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        
        if fileSize > dimension.maxFileSizeKB {
            violations.append(ConstraintViolation(
                message: "File size exceeds platform limit",
                severity: .error,
                propertyName: "fileSize",
                value: "\(fileSize)KB",
                requirement: "Maximum \(dimension.maxFileSizeKB)KB"
            ))
        } else if fileSize > dimension.maxFileSizeKB * 9 / 10 {
            // Warning if within 90% of the limit
            violations.append(ConstraintViolation(
                message: "File size is close to platform limit",
                severity: .warning,
                propertyName: "fileSize",
                value: "\(fileSize)KB",
                requirement: "Maximum \(dimension.maxFileSizeKB)KB"
            ))
        }
        
        return violations
    }
    
    // Validate safe zones
    private func validateSafeZones(design: Design, safeZone: SafeZone) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        
        // Check critical elements (high importance) against safe zones
        for element in design.elements where element.importance == .critical || element.importance == .high {
            let elementRect = CGRect(x: element.x, y: element.y, width: element.width, height: element.height)
            
            // Calculate safe zone rect
            let safeRect = CGRect(
                x: safeZone.left,
                y: safeZone.top,
                width: design.width - safeZone.left - safeZone.right,
                height: design.height - safeZone.top - safeZone.bottom
            )
            
            // Check if element extends outside the safe zone
            if !safeRect.contains(elementRect) {
                violations.append(ConstraintViolation(
                    message: "Critical element extends outside safe zone",
                    severity: .warning,
                    propertyName: "safeZone",
                    value: "Element ID: \(element.id)",
                    requirement: "Critical elements should be within safe zone"
                ))
            }
        }
        
        return violations
    }
    
    // Validate logo presence
    private func validateLogoPresence(design: Design) -> [ConstraintViolation] {
        var violations: [ConstraintViolation] = []
        
        let hasLogo = design.elements.contains { $0.type == .logo }
        
        if !hasLogo {
            violations.append(ConstraintViolation(
                message: "Logo element required but not found",
                severity: .error,
                propertyName: "logoPresence",
                value: "Missing",
                requirement: "Design must include a logo element"
            ))
        }
        
        return violations
    }
    
    // Estimate file size based on design and export settings
    private func estimateFileSize(design: Design, exportSettings: ExportSettings) -> Int? {
        // This is a very rough estimate and would need to be calibrated
        // For a real implementation, we would render the design and compress it to get accurate file size
        
        let pixelCount = Double(design.width * design.height)
        var bytesPerPixel: Double
        
        switch exportSettings.format {
        case .jpg, .jpeg:
            bytesPerPixel = 0.25 * (1.0 - Double(exportSettings.jpegQuality) / 100.0)
        case .png:
            switch exportSettings.pngColorType {
            case .indexed:
                bytesPerPixel = 0.125 // 1 byte per 8 pixels for 8-bit indexed
            case .rgb:
                bytesPerPixel = 3.0 / 8.0
            case .rgba:
                bytesPerPixel = 4.0 / 8.0
            }
        case .png8:
            bytesPerPixel = 0.125
        case .gif:
            bytesPerPixel = 0.125
        case .svg, .html5:
            // SVG and HTML5 size depends on complexity, not dimensions
            return nil
        }
        
        // Account for complexity based on number of elements
        let complexityFactor = 1.0 + log10(Double(max(1, design.elements.count)) / 10.0)
        
        let estimatedBytes = pixelCount * bytesPerPixel * complexityFactor
        return Int(estimatedBytes / 1024) // Convert to KB
    }
}

// Export settings for the design
struct ExportSettings {
    enum PNGColorType: String {
        case indexed // PNG-8
        case rgb     // PNG-24
        case rgba    // PNG-32
    }
    
    var format: FileFormat
    var jpegQuality: Int = 85 // 0-100
    var pngColorType: PNGColorType = .rgba
    var includeMetadata: Bool = true
    var optimizeForWeb: Bool = true
    
    // Default settings for web export
    static var defaultWebExport: ExportSettings {
        return ExportSettings(format: .png, jpegQuality: 85, pngColorType: .rgba, includeMetadata: false, optimizeForWeb: true)
    }
    
    // Settings optimized for minimum file size
    static func minimumSizeSettings(for format: FileFormat) -> ExportSettings {
        switch format {
        case .jpg, .jpeg:
            return ExportSettings(format: format, jpegQuality: 60, includeMetadata: false, optimizeForWeb: true)
        case .png, .png8:
            return ExportSettings(format: format, pngColorType: .indexed, includeMetadata: false, optimizeForWeb: true)
        default:
            return ExportSettings(format: format, includeMetadata: false, optimizeForWeb: true)
        }
    }
} 