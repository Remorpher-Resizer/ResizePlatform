import Foundation
import SwiftUI

class ProjectManager: ObservableObject {
    @Published var projects: [Project] = []
    @Published var templates: [ProjectTemplate] = []
    @Published var campaigns: [Campaign] = []
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let projectsDirectory: URL
    private let templatesDirectory: URL
    private let campaignsDirectory: URL
    
    // Current user
    private var currentUserId: String = NSUserName()
    private var currentUserName: String = NSFullUserName()
    
    init() {
        // Set up directories
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        projectsDirectory = documentsDirectory.appendingPathComponent("Projects")
        templatesDirectory = documentsDirectory.appendingPathComponent("ProjectTemplates")
        campaignsDirectory = documentsDirectory.appendingPathComponent("Campaigns")
        
        // Create directories if needed
        try? fileManager.createDirectory(at: projectsDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: campaignsDirectory, withIntermediateDirectories: true)
        
        // Load data
        loadProjects()
        loadTemplates()
        loadCampaigns()
    }
    
    // MARK: - Project Operations
    
    // Load all projects
    private func loadProjects() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: projectsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            projects = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(Project.self, from: data)
            }
            
            // Sort projects by update date, newest first
            projects.sort { $0.updatedAt > $1.updatedAt }
            
        } catch {
            print("Error loading projects: \(error)")
        }
    }
    
    // Save a project to disk
    private func saveProject(_ project: Project) throws {
        let fileURL = projectsDirectory.appendingPathComponent("\(project.id).json")
        let data = try JSONEncoder().encode(project)
        try data.write(to: fileURL)
    }
    
    // Create a new project
    func createProject(name: String, description: String? = nil, template: ProjectTemplate? = nil) throws -> Project {
        let projectId = UUID().uuidString
        let now = Date()
        
        // If a template is provided, use it
        if let template = template {
            let project = template.createProject(name: name, description: description, createdBy: currentUserId)
            try saveProject(project)
            projects.insert(project, at: 0)
            return project
        }
        
        // Otherwise, create a basic project
        let owner = ProjectMember(
            id: UUID().uuidString,
            userId: currentUserId,
            userName: currentUserName,
            role: .owner,
            addedAt: now
        )
        
        let project = Project(
            id: projectId,
            name: name,
            description: description,
            createdAt: now,
            updatedAt: now,
            createdBy: currentUserId,
            status: .draft,
            members: [owner],
            assets: [],
            comments: [],
            activities: [
                ProjectActivity(
                    id: UUID().uuidString,
                    projectId: projectId,
                    userId: currentUserId,
                    userName: currentUserName,
                    activityType: "project_created",
                    description: "Project created",
                    timestamp: now
                )
            ],
            tags: []
        )
        
        try saveProject(project)
        projects.insert(project, at: 0)
        return project
    }
    
    // Update a project
    func updateProject(_ project: Project) throws {
        var updatedProject = project
        updatedProject.updatedAt = Date()
        
        // Add activity log
        updatedProject.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: project.id,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "project_updated",
                description: "Project updated",
                timestamp: Date()
            )
        )
        
        // Save to disk
        try saveProject(updatedProject)
        
        // Update in memory
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = updatedProject
        } else {
            projects.append(updatedProject)
        }
    }
    
    // Delete a project
    func deleteProject(id: String) throws {
        // Remove from memory
        projects.removeAll { $0.id == id }
        
        // Remove from disk
        let fileURL = projectsDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Change project status
    func changeProjectStatus(_ projectId: String, to status: ProjectStatus) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        let oldStatus = project.status
        project.status = status
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "status_changed",
                description: "Status changed from \(oldStatus.displayName) to \(status.displayName)",
                timestamp: Date(),
                metadata: [
                    "old_status": oldStatus.rawValue,
                    "new_status": status.rawValue
                ]
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Add a member to a project
    func addMemberToProject(_ projectId: String, userId: String, userName: String, role: ProjectRole) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        
        // Check if user is already a member
        if project.members.contains(where: { $0.userId == userId }) {
            throw NSError(domain: "ProjectError", code: 400, userInfo: [NSLocalizedDescriptionKey: "User is already a member of this project"])
        }
        
        // Add the member
        let newMember = ProjectMember(
            id: UUID().uuidString,
            userId: userId,
            userName: userName,
            role: role,
            addedAt: Date(),
            invitedBy: currentUserId
        )
        
        project.members.append(newMember)
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "member_added",
                description: "Added \(userName) as \(role.displayName)",
                timestamp: Date(),
                metadata: [
                    "added_user_id": userId,
                    "added_user_name": userName,
                    "role": role.rawValue
                ]
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Change a member's role
    func changeMemberRole(_ projectId: String, userId: String, to role: ProjectRole) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        
        // Find the member
        guard let memberIndex = project.members.firstIndex(where: { $0.userId == userId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Member not found"])
        }
        
        let oldRole = project.members[memberIndex].role
        project.members[memberIndex].role = role
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "role_changed",
                description: "Changed \(project.members[memberIndex].userName) role from \(oldRole.displayName) to \(role.displayName)",
                timestamp: Date(),
                metadata: [
                    "user_id": userId,
                    "user_name": project.members[memberIndex].userName,
                    "old_role": oldRole.rawValue,
                    "new_role": role.rawValue
                ]
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Remove a member from a project
    func removeMemberFromProject(_ projectId: String, userId: String) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        
        // Find the member
        guard let member = project.members.first(where: { $0.userId == userId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Member not found"])
        }
        
        // Remove the member
        project.members.removeAll { $0.userId == userId }
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "member_removed",
                description: "Removed \(member.userName) from project",
                timestamp: Date(),
                metadata: [
                    "removed_user_id": userId,
                    "removed_user_name": member.userName
                ]
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Add an asset to a project
    func addAssetToProject(_ projectId: String, 
                           name: String, 
                           type: String, 
                           designId: String? = nil,
                           fileURL: URL? = nil,
                           dimensions: (width: CGFloat, height: CGFloat)? = nil,
                           platformId: String? = nil,
                           platformDimension: String? = nil) throws -> ProjectAsset {
        
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        let now = Date()
        
        // Create the asset
        let asset = ProjectAsset(
            id: UUID().uuidString,
            name: name,
            type: type,
            createdAt: now,
            updatedAt: now,
            createdBy: currentUserId,
            status: .draft,
            version: 1,
            designId: designId,
            fileURL: fileURL,
            dimensions: dimensions,
            platformId: platformId,
            platformDimension: platformDimension
        )
        
        // Add to project
        project.assets.append(asset)
        project.updatedAt = now
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "asset_added",
                description: "Added \(name) to project",
                timestamp: now,
                metadata: [
                    "asset_id": asset.id,
                    "asset_name": name,
                    "asset_type": type
                ],
                designId: designId
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
        
        return asset
    }
    
    // Update an asset
    func updateAsset(_ projectId: String, asset: ProjectAsset) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        
        // Find the asset
        guard let assetIndex = project.assets.firstIndex(where: { $0.id == asset.id }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }
        
        var updatedAsset = asset
        updatedAsset.updatedAt = Date()
        updatedAsset.version += 1
        
        // Update the asset
        project.assets[assetIndex] = updatedAsset
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "asset_updated",
                description: "Updated \(asset.name)",
                timestamp: Date(),
                metadata: [
                    "asset_id": asset.id,
                    "asset_name": asset.name,
                    "version": "\(updatedAsset.version)"
                ],
                designId: asset.designId
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Change asset status
    func changeAssetStatus(_ projectId: String, assetId: String, to status: ProjectStatus) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        
        // Find the asset
        guard let assetIndex = project.assets.firstIndex(where: { $0.id == assetId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Asset not found"])
        }
        
        let oldStatus = project.assets[assetIndex].status
        project.assets[assetIndex].status = status
        project.assets[assetIndex].updatedAt = Date()
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "asset_status_changed",
                description: "Changed \(project.assets[assetIndex].name) status from \(oldStatus.displayName) to \(status.displayName)",
                timestamp: Date(),
                metadata: [
                    "asset_id": assetId,
                    "asset_name": project.assets[assetIndex].name,
                    "old_status": oldStatus.rawValue,
                    "new_status": status.rawValue
                ],
                designId: project.assets[assetIndex].designId
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Add a comment to a project or asset
    func addComment(_ projectId: String, 
                   text: String, 
                   designId: String? = nil,
                   parentId: String? = nil,
                   position: CGPoint? = nil) throws -> ProjectComment {
        
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        let now = Date()
        
        // Create the comment
        let comment = ProjectComment(
            id: UUID().uuidString,
            projectId: projectId,
            designId: designId,
            userId: currentUserId,
            userName: currentUserName,
            text: text,
            createdAt: now,
            updatedAt: now,
            parentId: parentId,
            resolved: false,
            x: position?.x,
            y: position?.y
        )
        
        // Add to project
        project.comments.append(comment)
        project.updatedAt = now
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "comment_added",
                description: designId != nil ? "Added comment to design" : "Added comment to project",
                timestamp: now,
                metadata: [
                    "comment_id": comment.id,
                    "parent_id": parentId ?? ""
                ],
                designId: designId
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
        
        return comment
    }
    
    // Resolve a comment
    func resolveComment(_ projectId: String, commentId: String) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        var project = projects[projectIndex]
        
        // Find the comment
        guard let commentIndex = project.comments.firstIndex(where: { $0.id == commentId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Comment not found"])
        }
        
        project.comments[commentIndex].resolved = true
        project.comments[commentIndex].updatedAt = Date()
        project.updatedAt = Date()
        
        // Add activity log
        project.activities.append(
            ProjectActivity(
                id: UUID().uuidString,
                projectId: projectId,
                userId: currentUserId,
                userName: currentUserName,
                activityType: "comment_resolved",
                description: "Resolved comment",
                timestamp: Date(),
                metadata: [
                    "comment_id": commentId
                ],
                designId: project.comments[commentIndex].designId
            )
        )
        
        // Save changes
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // MARK: - Template Operations
    
    // Load project templates
    private func loadTemplates() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            templates = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(ProjectTemplate.self, from: data)
            }
            
            // Sort templates by update date
            templates.sort { $0.updatedAt > $1.updatedAt }
            
        } catch {
            print("Error loading templates: \(error)")
        }
    }
    
    // Save a template to disk
    private func saveTemplate(_ template: ProjectTemplate) throws {
        let fileURL = templatesDirectory.appendingPathComponent("\(template.id).json")
        let data = try JSONEncoder().encode(template)
        try data.write(to: fileURL)
    }
    
    // Create a new project template
    func createProjectTemplate(name: String, 
                              description: String? = nil,
                              defaultMembers: [ProjectMember] = [],
                              assetTypes: [String] = ["design", "image"],
                              workflowSteps: [ProjectStatus] = [.draft, .review, .approved, .published],
                              platforms: [String]? = nil,
                              defaultTags: [String] = [],
                              brandKitId: String? = nil,
                              templateIds: [String]? = nil) throws -> ProjectTemplate {
        
        let templateId = UUID().uuidString
        let now = Date()
        
        // Create the template
        let template = ProjectTemplate(
            id: templateId,
            name: name,
            description: description,
            createdBy: currentUserId,
            createdAt: now,
            updatedAt: now,
            defaultMembers: defaultMembers,
            assetTypes: assetTypes,
            workflowSteps: workflowSteps,
            platforms: platforms,
            defaultTags: defaultTags,
            brandKitId: brandKitId,
            templateIds: templateIds
        )
        
        // Save template
        try saveTemplate(template)
        
        // Add to in-memory collection
        templates.insert(template, at: 0)
        
        return template
    }
    
    // Update a project template
    func updateProjectTemplate(_ template: ProjectTemplate) throws {
        var updatedTemplate = template
        updatedTemplate.updatedAt = Date()
        
        // Save to disk
        try saveTemplate(updatedTemplate)
        
        // Update in memory
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = updatedTemplate
        } else {
            templates.append(updatedTemplate)
        }
    }
    
    // Delete a project template
    func deleteProjectTemplate(id: String) throws {
        // Remove from memory
        templates.removeAll { $0.id == id }
        
        // Remove from disk
        let fileURL = templatesDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Create a template from an existing project
    func createTemplateFromProject(_ project: Project, name: String, description: String? = nil) throws -> ProjectTemplate {
        let templateId = UUID().uuidString
        let now = Date()
        
        // Extract asset types
        let assetTypes = Array(Set(project.assets.map { $0.type }))
        
        // Create template
        let template = ProjectTemplate(
            id: templateId,
            name: name,
            description: description,
            createdBy: currentUserId,
            createdAt: now,
            updatedAt: now,
            defaultMembers: project.members.filter { $0.userId != currentUserId },
            assetTypes: assetTypes,
            workflowSteps: ProjectStatus.allCases,
            platforms: project.platforms,
            defaultTags: project.tags,
            brandKitId: project.brandKitId,
            templateIds: project.templateIds
        )
        
        // Save template
        try saveTemplate(template)
        
        // Add to in-memory collection
        templates.insert(template, at: 0)
        
        return template
    }
    
    // MARK: - Campaign Operations
    
    // Load campaigns
    private func loadCampaigns() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: campaignsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            campaigns = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(Campaign.self, from: data)
            }
            
            // Sort campaigns by update date
            campaigns.sort { $0.updatedAt > $1.updatedAt }
            
        } catch {
            print("Error loading campaigns: \(error)")
        }
    }
    
    // Save a campaign to disk
    private func saveCampaign(_ campaign: Campaign) throws {
        let fileURL = campaignsDirectory.appendingPathComponent("\(campaign.id).json")
        let data = try JSONEncoder().encode(campaign)
        try data.write(to: fileURL)
    }
    
    // Create a new campaign
    func createCampaign(name: String, 
                       description: String? = nil,
                       startDate: Date,
                       endDate: Date,
                       projectIds: [String] = [],
                       tags: [String] = [],
                       platforms: [String]? = nil,
                       budget: Double? = nil) throws -> Campaign {
        
        let campaignId = UUID().uuidString
        let now = Date()
        
        // Create campaign
        let campaign = Campaign(
            id: campaignId,
            name: name,
            description: description,
            startDate: startDate,
            endDate: endDate,
            createdBy: currentUserId,
            createdAt: now,
            updatedAt: now,
            status: .draft,
            projectIds: projectIds,
            tags: tags,
            budget: budget,
            platforms: platforms
        )
        
        // Save campaign
        try saveCampaign(campaign)
        
        // Add to in-memory collection
        campaigns.insert(campaign, at: 0)
        
        // If there are projects, update them to link to this campaign
        for projectId in projectIds {
            if let projectIndex = projects.firstIndex(where: { $0.id == projectId }) {
                var project = projects[projectIndex]
                project.campaignId = campaignId
                project.updatedAt = now
                
                try saveProject(project)
                projects[projectIndex] = project
            }
        }
        
        return campaign
    }
    
    // Update a campaign
    func updateCampaign(_ campaign: Campaign) throws {
        var updatedCampaign = campaign
        updatedCampaign.updatedAt = Date()
        
        // Save to disk
        try saveCampaign(updatedCampaign)
        
        // Update in memory
        if let index = campaigns.firstIndex(where: { $0.id == campaign.id }) {
            campaigns[index] = updatedCampaign
        } else {
            campaigns.append(updatedCampaign)
        }
    }
    
    // Delete a campaign
    func deleteCampaign(id: String) throws {
        // Get campaign to unlink projects
        if let campaign = campaigns.first(where: { $0.id == id }) {
            // Unlink projects from this campaign
            for projectId in campaign.projectIds {
                if let projectIndex = projects.firstIndex(where: { $0.id == projectId }) {
                    var project = projects[projectIndex]
                    project.campaignId = nil
                    project.updatedAt = Date()
                    
                    try saveProject(project)
                    projects[projectIndex] = project
                }
            }
        }
        
        // Remove from memory
        campaigns.removeAll { $0.id == id }
        
        // Remove from disk
        let fileURL = campaignsDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Add a project to a campaign
    func addProjectToCampaign(_ projectId: String, campaignId: String) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            throw NSError(domain: "CampaignError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Campaign not found"])
        }
        
        var project = projects[projectIndex]
        var campaign = campaigns[campaignIndex]
        
        // Update project
        project.campaignId = campaignId
        project.updatedAt = Date()
        
        // Update campaign if not already contains the project
        if !campaign.projectIds.contains(projectId) {
            campaign.projectIds.append(projectId)
            campaign.updatedAt = Date()
            
            try saveCampaign(campaign)
            campaigns[campaignIndex] = campaign
        }
        
        // Save project
        try saveProject(project)
        projects[projectIndex] = project
    }
    
    // Remove a project from a campaign
    func removeProjectFromCampaign(_ projectId: String, campaignId: String) throws {
        guard let projectIndex = projects.firstIndex(where: { $0.id == projectId }) else {
            throw NSError(domain: "ProjectError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Project not found"])
        }
        
        guard let campaignIndex = campaigns.firstIndex(where: { $0.id == campaignId }) else {
            throw NSError(domain: "CampaignError", code: 404, userInfo: [NSLocalizedDescriptionKey: "Campaign not found"])
        }
        
        var project = projects[projectIndex]
        var campaign = campaigns[campaignIndex]
        
        // Update project if it belongs to this campaign
        if project.campaignId == campaignId {
            project.campaignId = nil
            project.updatedAt = Date()
            
            try saveProject(project)
            projects[projectIndex] = project
        }
        
        // Update campaign
        campaign.projectIds.removeAll { $0 == projectId }
        campaign.updatedAt = Date()
        
        try saveCampaign(campaign)
        campaigns[campaignIndex] = campaign
    }
    
    // MARK: - Query Operations
    
    // Get projects for the current user
    func getMyProjects() -> [Project] {
        return projects.filter { project in
            project.members.contains { $0.userId == currentUserId }
        }
    }
    
    // Get projects by status
    func getProjects(withStatus status: ProjectStatus) -> [Project] {
        return projects.filter { $0.status == status }
    }
    
    // Get projects in a campaign
    func getProjects(inCampaign campaignId: String) -> [Project] {
        return projects.filter { $0.campaignId == campaignId }
    }
    
    // Get campaigns by status
    func getCampaigns(withStatus status: ProjectStatus) -> [Campaign] {
        return campaigns.filter { $0.status == status }
    }
    
    // Get active campaigns (current or future)
    func getActiveCampaigns() -> [Campaign] {
        let now = Date()
        return campaigns.filter { 
            $0.endDate >= now && 
            $0.status != .archived
        }
    }
    
    // Search projects by name or description
    func searchProjects(query: String) -> [Project] {
        guard !query.isEmpty else { return projects }
        
        return projects.filter {
            $0.name.localizedCaseInsensitiveContains(query) ||
            $0.description?.localizedCaseInsensitiveContains(query) ?? false ||
            $0.tags.contains { $0.localizedCaseInsensitiveContains(query) }
        }
    }
} 