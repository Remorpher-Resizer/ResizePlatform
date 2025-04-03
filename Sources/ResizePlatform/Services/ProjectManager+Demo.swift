import Foundation
import SwiftUI

extension ProjectManager {
    
    /// Creates demo data for testing the project management system
    func createDemoData() {
        // Clear existing data
        projects = []
        templates = []
        campaigns = []
        
        // Create some templates
        let socialMediaTemplate = createDemoTemplate(
            name: "Social Media Campaign",
            description: "Template for creating social media assets for multiple platforms",
            assetTypes: ["image", "design"],
            defaultTags: ["social", "marketing"]
        )
        
        let printCampaignTemplate = createDemoTemplate(
            name: "Print Campaign",
            description: "Template for print media including brochures, flyers and posters",
            assetTypes: ["design", "document"],
            defaultTags: ["print", "marketing"]
        )
        
        let brandKitTemplate = createDemoTemplate(
            name: "Brand Kit",
            description: "Template for managing brand assets and style guides",
            assetTypes: ["design", "document", "image"],
            defaultTags: ["brand", "identity"]
        )
        
        // Create some demo projects
        let project1 = createDemoProject(
            name: "Summer Campaign 2023",
            description: "Marketing campaign for summer product line",
            template: socialMediaTemplate,
            status: .published,
            daysAgo: 45
        )
        
        let project2 = createDemoProject(
            name: "Product Launch - XS5000",
            description: "Marketing materials for the new XS5000 product launch",
            template: printCampaignTemplate,
            status: .review,
            daysAgo: 5
        )
        
        let project3 = createDemoProject(
            name: "Website Redesign",
            description: "Complete overhaul of the company website",
            template: nil,
            status: .draft,
            daysAgo: 2
        )
        
        let project4 = createDemoProject(
            name: "Brand Refresh 2023",
            description: "Updated brand guidelines and assets",
            template: brandKitTemplate,
            status: .approved,
            daysAgo: 15
        )
        
        let project5 = createDemoProject(
            name: "Holiday Campaign 2022",
            description: "Last year's holiday marketing campaign",
            template: socialMediaTemplate,
            status: .archived,
            daysAgo: 180
        )
        
        // Create a campaign
        let now = Date()
        let startDate = Calendar.current.date(byAdding: .day, value: -10, to: now)!
        let endDate = Calendar.current.date(byAdding: .month, value: 2, to: now)!
        
        do {
            let campaign = try createCampaign(
                name: "Q3 Marketing Initiative",
                description: "Comprehensive marketing push for Q3 products",
                startDate: startDate,
                endDate: endDate,
                projectIds: [project1.id, project2.id],
                tags: ["marketing", "q3", "priority"],
                platforms: ["instagram", "facebook", "twitter", "print"],
                budget: 25000.0
            )
            
            // Add some assets to projects
            for project in [project1, project2, project3, project4] {
                addDemoAssetsToProject(project)
            }
            
            // Add some comments to projects
            addDemoCommentsToProject(project1)
            addDemoCommentsToProject(project2)
            
            // Add members to projects
            addDemoMembersToProject(project1)
            addDemoMembersToProject(project2)
            addDemoMembersToProject(project3)
            addDemoMembersToProject(project4)
        } catch {
            print("Error creating demo data: \(error)")
        }
    }
    
    private func createDemoTemplate(
        name: String,
        description: String,
        assetTypes: [String],
        defaultTags: [String]
    ) -> ProjectTemplate {
        do {
            return try createProjectTemplate(
                name: name,
                description: description,
                assetTypes: assetTypes,
                workflowSteps: ProjectStatus.allCases,
                defaultTags: defaultTags
            )
        } catch {
            print("Error creating demo template: \(error)")
            // Create a fallback in-memory only template if saving fails
            let now = Date()
            return ProjectTemplate(
                id: UUID().uuidString,
                name: name,
                description: description,
                createdBy: currentUserId,
                createdAt: now,
                updatedAt: now,
                defaultMembers: [],
                assetTypes: assetTypes,
                workflowSteps: ProjectStatus.allCases,
                platforms: nil,
                defaultTags: defaultTags,
                brandKitId: nil,
                templateIds: nil
            )
        }
    }
    
    private func createDemoProject(
        name: String,
        description: String,
        template: ProjectTemplate?,
        status: ProjectStatus,
        daysAgo: Int
    ) -> Project {
        let now = Date()
        let createdDate = Calendar.current.date(byAdding: .day, value: -daysAgo, to: now)!
        
        do {
            var project = try createProject(
                name: name,
                description: description,
                template: template
            )
            
            // Set the status and created date to simulate a project that's been around
            var updatedProject = project
            updatedProject.status = status
            updatedProject.createdAt = createdDate
            
            // For older projects, simulate some updates
            if daysAgo > 7 {
                let updates = min(daysAgo / 3, 10) // Simulate an update every 3 days, max 10 updates
                var lastUpdate = createdDate
                
                for i in 0..<updates {
                    // Space out updates
                    let updateDayOffset = Int(Double(daysAgo) / Double(updates + 1) * Double(i + 1))
                    let updateDate = Calendar.current.date(byAdding: .day, value: -daysAgo + updateDayOffset, to: now)!
                    lastUpdate = updateDate
                    
                    updatedProject.activities.append(
                        ProjectActivity(
                            id: UUID().uuidString,
                            projectId: project.id,
                            userId: currentUserId,
                            userName: currentUserName,
                            activityType: "project_updated",
                            description: "Project updated",
                            timestamp: updateDate
                        )
                    )
                }
                
                // Set last update date
                updatedProject.updatedAt = lastUpdate
            }
            
            // Add some tags
            if let template = template {
                updatedProject.tags = template.defaultTags
                if let platforms = template.platforms {
                    updatedProject.platforms = platforms
                }
            }
            
            // Update the project in store
            try updateProject(updatedProject)
            
            return updatedProject
        } catch {
            print("Error creating demo project: \(error)")
            // Return a placeholder that won't be saved
            let projectId = UUID().uuidString
            let owner = ProjectMember(
                id: UUID().uuidString,
                userId: currentUserId,
                userName: currentUserName,
                role: .owner,
                addedAt: createdDate
            )
            
            return Project(
                id: projectId,
                name: name,
                description: description,
                createdAt: createdDate,
                updatedAt: now,
                createdBy: currentUserId,
                status: status,
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
                        timestamp: createdDate
                    )
                ],
                tags: []
            )
        }
    }
    
    private func addDemoAssetsToProject(_ project: Project) {
        let assetTypes = ["image", "design", "document"]
        let assetNames = [
            "Logo Design",
            "Banner Image",
            "Social Media Post",
            "Product Photo",
            "Website Header",
            "Advertisement",
            "Brochure Layout",
            "Email Template"
        ]
        
        let dimensions: [(width: CGFloat, height: CGFloat)] = [
            (1200, 630),    // Facebook post
            (1080, 1080),   // Instagram post
            (1500, 500),    // Twitter header
            (2550, 3300),   // Letter size document
            (1200, 800),    // Website banner
            (800, 600),     // Email header
        ]
        
        // Add 2-5 random assets
        let numberOfAssets = Int.random(in: 2...5)
        let now = Date()
        
        for _ in 0..<numberOfAssets {
            // Pick a random asset type and name
            let assetType = assetTypes.randomElement() ?? "image"
            let assetName = assetNames.randomElement() ?? "Untitled Asset"
            
            // Choose dimensions based on type
            let dimension = dimensions.randomElement()
            
            // Choose a random status weighted toward the project status
            let statusOptions: [ProjectStatus]
            switch project.status {
            case .draft:
                statusOptions = [.draft, .draft, .draft, .review]
            case .review:
                statusOptions = [.draft, .review, .review, .approved]
            case .approved:
                statusOptions = [.review, .approved, .approved, .published]
            case .published:
                statusOptions = [.approved, .published, .published]
            case .archived:
                statusOptions = [.published, .archived, .archived]
            }
            let status = statusOptions.randomElement() ?? .draft
            
            // Create an asset with random data
            do {
                let asset = try addAssetToProject(
                    project.id,
                    name: assetName,
                    type: assetType,
                    dimensions: dimension
                )
                
                // Update status if not draft
                if status != .draft {
                    try changeAssetStatus(project.id, assetId: asset.id, to: status)
                }
            } catch {
                print("Error adding demo asset: \(error)")
            }
        }
    }
    
    private func addDemoCommentsToProject(_ project: Project) {
        let commentTexts = [
            "Can we make the logo a bit bigger?",
            "I like the overall design, but can we try a different color scheme?",
            "Looking good! Ready for review.",
            "Please update the text with the latest approved copy.",
            "The image resolution seems low, can we get a higher quality version?",
            "I've approved this design. Great work!",
            "The spacing between elements needs adjustment.",
            "Font size is too small for readability.",
            "Perfect! This looks ready to publish."
        ]
        
        // Add 3-7 random comments
        let numberOfComments = Int.random(in: 3...7)
        
        // Use dates spread between project creation and now
        let creationDate = project.createdAt
        let now = Date()
        let daysSinceCreation = Calendar.current.dateComponents([.day], from: creationDate, to: now).day ?? 30
        
        for i in 0..<numberOfComments {
            // Pick a random comment text
            let commentText = commentTexts.randomElement() ?? "Please review this."
            
            // Create a date for this comment (progressively more recent)
            let commentDayOffset = Double(daysSinceCreation) / Double(numberOfComments) * Double(i)
            let commentDate = Calendar.current.date(byAdding: .day, value: Int(-daysSinceCreation + Int(commentDayOffset)), to: now) ?? now
            
            // If project has assets, choose one randomly to comment on
            var designId: String? = nil
            if !project.assets.isEmpty && Bool.random() {
                designId = project.assets.randomElement()?.id
            }
            
            // Create the comment
            do {
                var comment = try addComment(
                    project.id,
                    text: commentText,
                    designId: designId
                )
                
                // Mark some comments as resolved
                if i < numberOfComments / 2 && Bool.random() {
                    try resolveComment(project.id, commentId: comment.id)
                }
            } catch {
                print("Error adding demo comment: \(error)")
            }
        }
    }
    
    private func addDemoMembersToProject(_ project: Project) {
        let demoUsers = [
            (id: "user123", name: "Alex Johnson"),
            (id: "user456", name: "Jamie Smith"),
            (id: "user789", name: "Taylor Wilson"),
            (id: "user101", name: "Morgan Lee"),
            (id: "user202", name: "Casey Brown")
        ]
        
        // Add 2-4 random members
        let numberOfMembers = Int.random(in: 2...4)
        
        for i in 0..<numberOfMembers {
            // Get a user that's not already a member
            guard let user = demoUsers.randomElement(),
                  !project.members.contains(where: { $0.userId == user.id }) else {
                continue
            }
            
            // Assign a role based on project status and position
            let role: ProjectRole
            if i == 0 && project.status == .review {
                role = .reviewer
            } else if i == 0 && (project.status == .approved || project.status == .published) {
                role = .editor
            } else if Bool.random() {
                role = .editor
            } else {
                role = .viewer
            }
            
            // Add the member
            do {
                try addMemberToProject(
                    project.id,
                    userId: user.id,
                    userName: user.name,
                    role: role
                )
            } catch {
                print("Error adding demo member: \(error)")
            }
        }
    }
} 