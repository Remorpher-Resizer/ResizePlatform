import Foundation

// Element types that can be in a design
enum ElementType: String, Codable {
    case text
    case image
    case shape
    case logo
    case group
}

// Importance level for elements
enum ElementImportance: Int, Codable {
    case low = 0
    case medium = 1
    case high = 2
    case critical = 3
}

// Constraints for an element
struct ElementConstraints: Codable {
    var lockAspectRatio: Bool = false
    var minWidth: CGFloat?
    var minHeight: CGFloat?
    var maxWidth: CGFloat?
    var maxHeight: CGFloat?
    var keepRelativePosition: Bool = false
    var marginLeft: CGFloat?
    var marginTop: CGFloat?
    var marginRight: CGFloat?
    var marginBottom: CGFloat?
    var alignToParent: Bool = false
}

// Element in a design
struct DesignElement: Identifiable, Codable {
    var id: String
    var type: ElementType
    var x: CGFloat
    var y: CGFloat
    var width: CGFloat
    var height: CGFloat
    var content: String?
    var importance: ElementImportance
    var constraints: ElementConstraints
    var groupId: String?
    var zIndex: Int
    var opacity: CGFloat
    var rotation: CGFloat
    
    // For text elements
    var fontSize: CGFloat?
    var fontFamily: String?
    var fontWeight: String?
    var textColor: String?
    var textAlignment: String?
    
    // For images and shapes
    var backgroundColor: String?
    var borderColor: String?
    var borderWidth: CGFloat?
    var cornerRadius: CGFloat?
    
    // For assets with a source URL
    var sourceURL: URL?
}

// Complete design with dimensions and elements
struct Design: Identifiable, Codable {
    var id: String
    var name: String
    var width: CGFloat
    var height: CGFloat
    var elements: [DesignElement]
    var backgroundColor: String?
    var metadata: [String: String]?
    var createdAt: Date
    var updatedAt: Date
} 