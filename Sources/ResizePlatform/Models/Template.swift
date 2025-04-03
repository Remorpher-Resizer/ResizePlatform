import Foundation

// The type of template
enum TemplateType: String, Codable, CaseIterable {
    case design
    case platform
    case campaign
    case brand
    case custom
    
    var displayName: String {
        switch self {
        case .design: return "Design Template"
        case .platform: return "Platform Template"
        case .campaign: return "Campaign Template"
        case .brand: return "Brand Template"
        case .custom: return "Custom Template"
        }
    }
}

// Access level for templates
enum TemplateAccessLevel: String, Codable, CaseIterable {
    case `private`
    case team
    case organization
    case public
    
    var displayName: String {
        switch self {
        case .private: return "Private"
        case .team: return "Team"
        case .organization: return "Organization"
        case .public: return "Public"
        }
    }
}

// The state of a template field (variable or fixed)
enum TemplateElementState: String, Codable {
    case fixed // Element cannot be changed
    case variable // Element can be customized
    case locked // Element can't be moved but can be edited
    case hidden // Element exists but is hidden by default
    case required // Must be filled in before use
}

// A variable element in a template
struct TemplateVariable: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var elementId: String
    var defaultValue: String?
    var allowedValues: [String]?
    var required: Bool
    var dataType: String // text, color, image, number, etc.
}

// A complete template
struct Template: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var type: TemplateType
    var accessLevel: TemplateAccessLevel
    var createdAt: Date
    var updatedAt: Date
    var createdById: String
    var version: String
    var baseDesign: Design
    var thumbnailURL: URL?
    var categories: [String]
    var tags: [String]
    var variables: [TemplateVariable]
    var elementStates: [String: TemplateElementState] // Map of element ID to state
    var platforms: [String]? // Applicable platforms
    var previousVersions: [String]?
    var brandKitId: String?
    
    // Calculate if a template has editable elements
    var hasEditableElements: Bool {
        return elementStates.values.contains { $0 == .variable || $0 == .locked }
    }
    
    // Get all variable elements
    var variableElements: [DesignElement] {
        return baseDesign.elements.filter { elementStates[$0.id] == .variable }
    }
    
    // Get all fixed elements
    var fixedElements: [DesignElement] {
        return baseDesign.elements.filter { elementStates[$0.id] == .fixed }
    }
    
    // Create a design from this template with the given variable values
    func createDesign(variableValues: [String: String]?) -> Design {
        var newDesign = baseDesign
        newDesign.id = UUID().uuidString
        
        // If variables are provided, update the design elements
        if let variableValues = variableValues {
            for variable in variables {
                if let value = variableValues[variable.id],
                   let elementIndex = newDesign.elements.firstIndex(where: { $0.id == variable.elementId }) {
                    
                    // Update the element based on the variable type
                    var updatedElement = newDesign.elements[elementIndex]
                    
                    switch variable.dataType {
                    case "text":
                        updatedElement.content = value
                    case "color":
                        updatedElement.backgroundColor = value
                    case "image":
                        // In a real app, we would handle image URLs differently
                        if let url = URL(string: value) {
                            updatedElement.sourceURL = url
                        }
                    case "number":
                        if let number = Double(value) {
                            // Apply numeric value based on element type or other criteria
                            // This is just a placeholder
                        }
                    default:
                        break
                    }
                    
                    newDesign.elements[elementIndex] = updatedElement
                }
            }
        }
        
        // Remove any hidden elements
        newDesign.elements.removeAll { element in
            elementStates[element.id] == .hidden
        }
        
        newDesign.updatedAt = Date()
        return newDesign
    }
}

// Template category for organization
struct TemplateCategory: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var parentId: String?
    var sortOrder: Int
}

// A collection of templates
struct TemplateCollection: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var accessLevel: TemplateAccessLevel
    var templateIds: [String]
    var createdAt: Date
    var updatedAt: Date
    var createdById: String
    var thumbnailURL: URL?
}

// Utility to find templates by various criteria
class TemplateUtility {
    
    // Find templates by type
    static func findTemplates(ofType type: TemplateType, in templates: [Template]) -> [Template] {
        return templates.filter { $0.type == type }
    }
    
    // Find templates by category
    static func findTemplates(inCategory category: String, in templates: [Template]) -> [Template] {
        return templates.filter { $0.categories.contains(category) }
    }
    
    // Find templates by platform
    static func findTemplates(forPlatform platform: String, in templates: [Template]) -> [Template] {
        return templates.filter { $0.platforms?.contains(platform) ?? false }
    }
    
    // Find templates by dimensions
    static func findTemplates(withWidth width: CGFloat, height: CGFloat, in templates: [Template]) -> [Template] {
        return templates.filter { 
            $0.baseDesign.width == width && $0.baseDesign.height == height
        }
    }
    
    // Find templates by tag
    static func findTemplates(withTag tag: String, in templates: [Template]) -> [Template] {
        return templates.filter { $0.tags.contains(tag) }
    }
    
    // Generate a preview design from a template
    static func generatePreview(from template: Template) -> Design {
        // Create default variable values for preview
        var previewValues: [String: String] = [:]
        
        for variable in template.variables {
            if let defaultValue = variable.defaultValue {
                previewValues[variable.id] = defaultValue
            } else {
                // Generate a placeholder value based on data type
                switch variable.dataType {
                case "text":
                    previewValues[variable.id] = "Sample Text"
                case "color":
                    previewValues[variable.id] = "#CCCCCC"
                case "image":
                    previewValues[variable.id] = "placeholder_image_url"
                case "number":
                    previewValues[variable.id] = "0"
                default:
                    previewValues[variable.id] = ""
                }
            }
        }
        
        return template.createDesign(variableValues: previewValues)
    }
} 