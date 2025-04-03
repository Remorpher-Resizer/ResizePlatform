import Foundation

// Project status
enum ProjectStatus: String, Codable, CaseIterable {
    case draft
    case review
    case approved
    case published
    case archived
    
    var displayName: String {
        switch self {
        case .draft: return "Draft"
        case .review: return "In Review"
        case .approved: return "Approved"
        case .published: return "Published"
        case .archived: return "Archived"
        }
    }
}

// Project roles
enum ProjectRole: String, Codable, CaseIterable {
    case owner
    case editor
    case reviewer
    case viewer
    
    var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .editor: return "Editor"
        case .reviewer: return "Reviewer"
        case .viewer: return "Viewer"
        }
    }
    
    var permissions: [ProjectPermission] {
        switch self {
        case .owner:
            return ProjectPermission.allCases
        case .editor:
            return [.view, .edit, .comment]
        case .reviewer:
            return [.view, .comment, .approve]
        case .viewer:
            return [.view]
        }
    }
}

// Project permissions
enum ProjectPermission: String, Codable, CaseIterable {
    case view
    case edit
    case comment
    case approve
    case publish
    case manageMembers
    case delete
}

// Project member
struct ProjectMember: Identifiable, Codable {
    var id: String
    var userId: String
    var userName: String
    var role: ProjectRole
    var addedAt: Date
    var invitedBy: String?
    var lastActivity: Date?
}

// Project comment
struct ProjectComment: Identifiable, Codable {
    var id: String
    var projectId: String
    var designId: String?
    var userId: String
    var userName: String
    var text: String
    var createdAt: Date
    var updatedAt: Date
    var parentId: String?
    var resolved: Bool
    var attachmentURL: URL?
    
    // Position of the comment on a design (if applicable)
    var x: CGFloat?
    var y: CGFloat?
}

// Project activity log entry
struct ProjectActivity: Identifiable, Codable {
    var id: String
    var projectId: String
    var userId: String
    var userName: String
    var activityType: String
    var description: String
    var timestamp: Date
    var metadata: [String: String]?
    var designId: String?
}

// Project asset (design or other file)
struct ProjectAsset: Identifiable, Codable {
    var id: String
    var name: String
    var type: String // "design", "image", "document", etc.
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var status: ProjectStatus
    var version: Int
    var designId: String?
    var fileURL: URL?
    var thumbnailURL: URL?
    var metadata: [String: String]?
    var dimensions: (width: CGFloat, height: CGFloat)?
    var platformId: String?
    var platformDimension: String?
    var publishSchedule: Date?
    
    // Get formatted dimensions string
    var dimensionsText: String? {
        if let dimensions = dimensions {
            return "\(Int(dimensions.width))x\(Int(dimensions.height))"
        }
        return nil
    }
}

// Complete project
struct Project: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var createdAt: Date
    var updatedAt: Date
    var createdBy: String
    var status: ProjectStatus
    var dueDate: Date?
    var members: [ProjectMember]
    var assets: [ProjectAsset]
    var comments: [ProjectComment]
    var activities: [ProjectActivity]
    var tags: [String]
    var metadata: [String: String]?
    var brandKitId: String?
    var templateIds: [String]?
    var platforms: [String]?
    var campaignId: String?
    var parentProjectId: String?
    var childProjectIds: [String]?
    
    // Get assets of a specific type
    func assets(ofType type: String) -> [ProjectAsset] {
        return assets.filter { $0.type == type }
    }
    
    // Get assets with a specific status
    func assets(withStatus status: ProjectStatus) -> [ProjectAsset] {
        return assets.filter { $0.status == status }
    }
    
    // Check if a user has a specific permission
    func userHasPermission(_ userId: String, permission: ProjectPermission) -> Bool {
        guard let member = members.first(where: { $0.userId == userId }) else {
            return false
        }
        
        return member.role.permissions.contains(permission)
    }
    
    // Get the role of a specific user
    func roleForUser(_ userId: String) -> ProjectRole? {
        return members.first(where: { $0.userId == userId })?.role
    }
    
    // Get comments for a specific asset
    func comments(forAsset assetId: String) -> [ProjectComment] {
        return comments.filter { $0.designId == assetId }
    }
    
    // Get activities for a specific user
    func activities(forUser userId: String) -> [ProjectActivity] {
        return activities.filter { $0.userId == userId }
    }
    
    // Get activities of a specific type
    func activities(ofType type: String) -> [ProjectActivity] {
        return activities.filter { $0.activityType == type }
    }
    
    // Get recent activities
    func recentActivities(limit: Int = 10) -> [ProjectActivity] {
        return Array(activities.sorted { $0.timestamp > $1.timestamp }.prefix(limit))
    }
}

// Project template for starting new projects
struct ProjectTemplate: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var defaultMembers: [ProjectMember]
    var assetTypes: [String]
    var workflowSteps: [ProjectStatus]
    var platforms: [String]?
    var defaultTags: [String]
    var brandKitId: String?
    var templateIds: [String]?
    var metadata: [String: String]?
    
    // Create a new project from this template
    func createProject(name: String, description: String? = nil, createdBy: String) -> Project {
        let projectId = UUID().uuidString
        let now = Date()
        
        return Project(
            id: projectId,
            name: name,
            description: description,
            createdAt: now,
            updatedAt: now,
            createdBy: createdBy,
            status: .draft,
            members: defaultMembers.map {
                var member = $0
                member.addedAt = now
                member.invitedBy = createdBy
                return member
            },
            assets: [],
            comments: [],
            activities: [
                ProjectActivity(
                    id: UUID().uuidString,
                    projectId: projectId,
                    userId: createdBy,
                    userName: "System", // Would be replaced with actual name
                    activityType: "project_created",
                    description: "Project created",
                    timestamp: now
                )
            ],
            tags: defaultTags,
            metadata: metadata,
            brandKitId: brandKitId,
            templateIds: templateIds,
            platforms: platforms
        )
    }
}

// Campaign grouping multiple projects
struct Campaign: Identifiable, Codable {
    var id: String
    var name: String
    var description: String?
    var startDate: Date
    var endDate: Date
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var status: ProjectStatus
    var projectIds: [String]
    var tags: [String]
    var metadata: [String: String]?
    var budget: Double?
    var platforms: [String]?
} 