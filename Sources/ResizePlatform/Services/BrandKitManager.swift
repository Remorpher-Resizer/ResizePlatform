import Foundation
import SwiftUI

class BrandKitManager: ObservableObject {
    @Published var brandKits: [BrandKit] = []
    @Published var activeBrandKit: BrandKit?
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let brandKitsDirectory: URL
    
    init() {
        // Set up directories
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        brandKitsDirectory = documentsDirectory.appendingPathComponent("BrandKits")
        
        // Create directories if needed
        try? fileManager.createDirectory(at: brandKitsDirectory, withIntermediateDirectories: true)
        
        // Load brand kits
        loadBrandKits()
    }
    
    // Load all available brand kits
    func loadBrandKits() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: brandKitsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            brandKits = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(BrandKit.self, from: data)
            }
            
            // Sort by update date
            brandKits.sort { $0.updatedAt > $1.updatedAt }
            
            // Set the most recently updated brand kit as active
            activeBrandKit = brandKits.first
        } catch {
            print("Error loading brand kits: \(error)")
        }
    }
    
    // Save a brand kit
    func saveBrandKit(_ brandKit: BrandKit) throws -> BrandKit {
        var updatedBrandKit = brandKit
        updatedBrandKit.updatedAt = Date()
        
        // Check if this is a new version
        if let existingIndex = brandKits.firstIndex(where: { $0.id == brandKit.id }) {
            let existingKit = brandKits[existingIndex]
            
            // If this is a different version, add the current version to previous versions
            if existingKit.version != brandKit.version {
                var previousVersions = updatedBrandKit.previousVersions ?? []
                previousVersions.append(existingKit.version)
                updatedBrandKit.previousVersions = previousVersions
            }
            
            // Update in the array
            brandKits[existingIndex] = updatedBrandKit
        } else {
            // It's a new brand kit
            brandKits.append(updatedBrandKit)
        }
        
        // Save to disk
        let fileURL = brandKitsDirectory.appendingPathComponent("\(updatedBrandKit.id).json")
        let data = try JSONEncoder().encode(updatedBrandKit)
        try data.write(to: fileURL)
        
        return updatedBrandKit
    }
    
    // Create a new brand kit with default values
    func createNewBrandKit(name: String) -> BrandKit {
        let id = UUID().uuidString
        let now = Date()
        
        // Create a default brand kit
        let brandKit = BrandKit(
            id: id,
            name: name,
            version: "1.0.0",
            createdAt: now,
            updatedAt: now,
            colors: [
                BrandColor(id: UUID().uuidString, name: "Primary", colorHex: "#0066CC", role: "primary"),
                BrandColor(id: UUID().uuidString, name: "Secondary", colorHex: "#FF9900", role: "secondary"),
                BrandColor(id: UUID().uuidString, name: "Text", colorHex: "#333333", role: "text")
            ],
            fonts: [
                BrandFont(
                    id: UUID().uuidString,
                    name: "Heading Font",
                    type: .system,
                    role: "heading",
                    fontName: "SF Pro Display",
                    fontWeights: ["Regular", "Bold"]
                ),
                BrandFont(
                    id: UUID().uuidString,
                    name: "Body Font",
                    type: .system,
                    role: "body",
                    fontName: "SF Pro Text",
                    fontWeights: ["Regular", "Medium", "Bold"]
                )
            ],
            logos: [
                LogoUsage(
                    id: UUID().uuidString,
                    name: "Light Background Logo",
                    background: .light,
                    imageURL: URL(string: "file://placeholder")!,
                    minimumSize: CGSize(width: 100, height: 40),
                    safeZone: SafeZone(all: 20)
                )
            ],
            typography: TypographySettings(
                heading1: TypographySettings.TextStyle(fontId: "heading", size: 28, weight: "Bold", lineHeight: 1.2),
                heading2: TypographySettings.TextStyle(fontId: "heading", size: 24, weight: "Bold", lineHeight: 1.2),
                heading3: TypographySettings.TextStyle(fontId: "heading", size: 20, weight: "Bold", lineHeight: 1.3),
                body: TypographySettings.TextStyle(fontId: "body", size: 16, weight: "Regular", lineHeight: 1.5),
                caption: TypographySettings.TextStyle(fontId: "body", size: 14, weight: "Regular", lineHeight: 1.4),
                button: TypographySettings.TextStyle(fontId: "body", size: 16, weight: "Medium", lineHeight: 1.2)
            ),
            spacing: SpacingSettings(
                baseUnit: 4,
                scale: [1, 2, 4, 8, 16, 24, 32]
            )
        )
        
        return brandKit
    }
    
    // Delete a brand kit
    func deleteBrandKit(id: String) throws {
        // Remove from memory
        brandKits.removeAll { $0.id == id }
        
        // If this was the active brand kit, set a new one
        if activeBrandKit?.id == id {
            activeBrandKit = brandKits.first
        }
        
        // Remove from disk
        let fileURL = brandKitsDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Set the active brand kit
    func setActiveBrandKit(_ brandKit: BrandKit) {
        self.activeBrandKit = brandKit
    }
    
    // Export a brand kit to a specified URL
    func exportBrandKit(_ brandKit: BrandKit, to url: URL) throws {
        let data = try JSONEncoder().encode(brandKit)
        try data.write(to: url)
    }
    
    // Import a brand kit from a URL
    func importBrandKit(from url: URL) throws -> BrandKit {
        let data = try Data(contentsOf: url)
        let brandKit = try JSONDecoder().decode(BrandKit.self, from: data)
        
        // Check if we already have this brand kit
        if brandKits.contains(where: { $0.id == brandKit.id }) {
            // If so, update it with this version
            return try saveBrandKit(brandKit)
        } else {
            // Otherwise, it's a new brand kit
            try saveBrandKit(brandKit)
            return brandKit
        }
    }
    
    // Create a new version of a brand kit
    func createNewVersion(_ brandKit: BrandKit, newVersion: String) throws -> BrandKit {
        var updatedBrandKit = brandKit
        
        // Store the current version in previous versions
        var previousVersions = updatedBrandKit.previousVersions ?? []
        previousVersions.append(updatedBrandKit.version)
        
        // Update the version
        updatedBrandKit.version = newVersion
        updatedBrandKit.previousVersions = previousVersions
        updatedBrandKit.updatedAt = Date()
        
        // Save and return
        return try saveBrandKit(updatedBrandKit)
    }
    
    // Apply a brand kit to a design
    func applyBrandKitToDesign(_ brandKit: BrandKit, design: Design) -> Design {
        var updatedDesign = design
        
        // In a real implementation, we would apply the brand kit's colors, fonts, etc. to the design
        // For now, this is just a placeholder
        
        return updatedDesign
    }
    
    // Add a logo to a brand kit
    func addLogoToBrandKit(_ brandKit: BrandKit, logoImage: NSImage, name: String, background: LogoUsage.LogoBackground) throws -> BrandKit {
        // Create a URL to save the logo image
        let logoId = UUID().uuidString
        let logoDirectory = brandKitsDirectory.appendingPathComponent("\(brandKit.id)/logos")
        try fileManager.createDirectory(at: logoDirectory, withIntermediateDirectories: true)
        
        let logoURL = logoDirectory.appendingPathComponent("\(logoId).png")
        
        // Save the image
        guard let tiffData = logoImage.tiffRepresentation,
              let bitmapImage = NSBitmapImageRep(data: tiffData),
              let pngData = bitmapImage.representation(using: .png, properties: [:]) else {
            throw NSError(domain: "BrandKitError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert logo to PNG"])
        }
        
        try pngData.write(to: logoURL)
        
        // Create the logo usage
        let logoUsage = LogoUsage(
            id: logoId,
            name: name,
            background: background,
            imageURL: logoURL,
            minimumSize: CGSize(width: 100, height: 40), // Default, should be adjusted
            safeZone: SafeZone(all: 20) // Default, should be adjusted
        )
        
        // Add to brand kit
        var updatedBrandKit = brandKit
        updatedBrandKit.logos.append(logoUsage)
        
        // Save and return
        return try saveBrandKit(updatedBrandKit)
    }
} 