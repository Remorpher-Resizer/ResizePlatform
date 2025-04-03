import Foundation

// Project status
public enum ProjectStatus: String, Codable, CaseIterable {
    case draft
    case review
    case approved
    case published
    case archived
    
    public var displayName: String {
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
public enum ProjectRole: String, Codable, CaseIterable {
    case owner
    case editor
    case reviewer
    case viewer
    
    public var displayName: String {
        switch self {
        case .owner: return "Owner"
        case .editor: return "Editor"
        case .reviewer: return "Reviewer"
        case .viewer: return "Viewer"
        }
    }
    
    public var permissions: [ProjectPermission] {
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
public enum ProjectPermission: String, Codable, CaseIterable {
    case view
    case edit
    case comment
    case approve
    case publish
    case manageMembers
    case delete
}

// Project member
public struct ProjectMember: Identifiable, Codable {
    public var id: String
    public var userId: String
    public var userName: String
    public var role: ProjectRole
    public var addedAt: Date
    public var invitedBy: String?
    public var lastActivity: Date?
    
    public init(id: String, userId: String, userName: String, role: ProjectRole, addedAt: Date, invitedBy: String? = nil, lastActivity: Date? = nil) {
        self.id = id
        self.userId = userId
        self.userName = userName
        self.role = role
        self.addedAt = addedAt
        self.invitedBy = invitedBy
        self.lastActivity = lastActivity
    }
}

// Project comment
public struct ProjectComment: Identifiable, Codable {
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
public struct ProjectActivity: Identifiable, Codable {
    public var id: String
    public var projectId: String
    public var userId: String
    public var userName: String
    public var activityType: String
    public var description: String
    public var timestamp: Date
    public var metadata: [String: String]?
    public var designId: String?
    
    public init(id: String, projectId: String, userId: String, userName: String, activityType: String, description: String, timestamp: Date, metadata: [String: String]? = nil, designId: String? = nil) {
        self.id = id
        self.projectId = projectId
        self.userId = userId
        self.userName = userName
        self.activityType = activityType
        self.description = description
        self.timestamp = timestamp
        self.metadata = metadata
        self.designId = designId
    }
}

// Project asset (design or other file)
public struct ProjectAsset: Identifiable, Codable {
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
public struct Project: Identifiable, Codable {
    public var id: String
    public var name: String
    public var description: String?
    public var createdAt: Date
    public var updatedAt: Date
    public var createdBy: String
    public var status: ProjectStatus
    public var dueDate: Date?
    public var members: [ProjectMember]
    public var assets: [ProjectAsset]
    public var comments: [ProjectComment]
    public var activities: [ProjectActivity]
    public var tags: [String]
    public var metadata: [String: String]?
    public var brandKitId: String?
    public var templateIds: [String]?
    public var platforms: [String]?
    public var campaignId: String?
    public var parentProjectId: String?
    public var childProjectIds: [String]?
    
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
public struct ProjectTemplate: Identifiable, Codable {
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