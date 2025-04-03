import SwiftUI

public struct ProjectsView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State private var showNewProjectSheet = false
    @State private var searchQuery = ""
    @State private var selectedStatusFilter: ProjectStatus?
    @State private var selectedProject: Project?
    
    private var filteredProjects: [Project] {
        var result = projectManager.projects
        
        // Apply status filter if selected
        if let status = selectedStatusFilter {
            result = result.filter { $0.status == status }
        }
        
        // Apply search filter if not empty
        if !searchQuery.isEmpty {
            result = result.filter {
                $0.name.localizedCaseInsensitiveContains(searchQuery) ||
                $0.description?.localizedCaseInsensitiveContains(searchQuery) ?? false ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchQuery) }
            }
        }
        
        return result
    }
    
    public var body: some View {
        NavigationSplitView {
            VStack {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.gray)
                    TextField("Search projects...", text: $searchQuery)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal)
                
                // Status filter
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        Button(action: {
                            selectedStatusFilter = nil
                        }) {
                            Text("All")
                                .padding(.vertical, 5)
                                .padding(.horizontal, 10)
                                .background(selectedStatusFilter == nil ? Color.blue : Color.gray.opacity(0.2))
                                .foregroundColor(selectedStatusFilter == nil ? .white : .primary)
                                .cornerRadius(8)
                        }
                        
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            Button(action: {
                                selectedStatusFilter = status
                            }) {
                                Text(status.displayName)
                                    .padding(.vertical, 5)
                                    .padding(.horizontal, 10)
                                    .background(selectedStatusFilter == status ? Color.blue : Color.gray.opacity(0.2))
                                    .foregroundColor(selectedStatusFilter == status ? .white : .primary)
                                    .cornerRadius(8)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical, 8)
                
                // Project list
                List(filteredProjects, id: \.id, selection: $selectedProject) { project in
                    NavigationLink(value: project) {
                        ProjectListItemView(project: project)
                    }
                    .contextMenu {
                        // Status change options
                        Menu("Change Status") {
                            ForEach(ProjectStatus.allCases, id: \.self) { status in
                                if status != project.status {
                                    Button(status.displayName) {
                                        changeProjectStatus(project, to: status)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        // Duplicate project
                        Button {
                            duplicateProject(project)
                        } label: {
                            Label("Duplicate", systemImage: "doc.on.doc")
                        }
                        
                        // Delete project
                        Button(role: .destructive) {
                            deleteProject(project)
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .navigationTitle("Projects")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showNewProjectSheet = true
                    } label: {
                        Label("New Project", systemImage: "plus")
                    }
                }
            }
            .sheet(isPresented: $showNewProjectSheet) {
                NewProjectView()
                    .environmentObject(projectManager)
            }
        } detail: {
            if let project = selectedProject {
                ProjectDetailView(project: project)
                    .environmentObject(projectManager)
            } else {
                Text("Select a project")
                    .font(.title)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private func changeProjectStatus(_ project: Project, to status: ProjectStatus) {
        do {
            try projectManager.changeProjectStatus(project.id, to: status)
        } catch {
            print("Error changing project status: \(error)")
        }
    }
    
    private func duplicateProject(_ project: Project) {
        do {
            let newName = "Copy of \(project.name)"
            let newProject = try projectManager.createProject(name: newName, description: project.description)
            
            // Copy project attributes (this would be more extensive in a real app)
            for tag in project.tags {
                var updatedProject = newProject
                updatedProject.tags.append(tag)
                try projectManager.updateProject(updatedProject)
            }
        } catch {
            print("Error duplicating project: \(error)")
        }
    }
    
    private func deleteProject(_ project: Project) {
        do {
            try projectManager.deleteProject(id: project.id)
            if selectedProject?.id == project.id {
                selectedProject = nil
            }
        } catch {
            print("Error deleting project: \(error)")
        }
    }
}

struct ProjectListItemView: View {
    let project: Project
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(project.name)
                    .font(.headline)
                
                Spacer()
                
                // Project status
                Text(project.status.displayName)
                    .font(.caption)
                    .padding(.vertical, 2)
                    .padding(.horizontal, 6)
                    .background(statusColor(for: project.status).opacity(0.2))
                    .foregroundColor(statusColor(for: project.status))
                    .cornerRadius(4)
            }
            
            if let description = project.description, !description.isEmpty {
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack {
                // Last updated
                Text("Updated \(dateFormatter.string(from: project.updatedAt))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                // Assets count if any
                if !project.assets.isEmpty {
                    HStack(spacing: 2) {
                        Image(systemName: "photo")
                            .font(.caption2)
                        Text("\(project.assets.count)")
                            .font(.caption2)
                    }
                    .foregroundColor(.secondary)
                }
                
                // Members count
                HStack(spacing: 2) {
                    Image(systemName: "person.2")
                        .font(.caption2)
                    Text("\(project.members.count)")
                        .font(.caption2)
                }
                .foregroundColor(.secondary)
            }
            
            // Tags if any
            if !project.tags.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(project.tags, id: \.self) { tag in
                            Text(tag)
                                .font(.caption2)
                                .padding(.vertical, 2)
                                .padding(.horizontal, 6)
                                .background(Color.gray.opacity(0.2))
                                .cornerRadius(4)
                        }
                    }
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .draft:
            return .gray
        case .review:
            return .orange
        case .approved:
            return .green
        case .published:
            return .blue
        case .archived:
            return .purple
        }
    }
}

struct NewProjectView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var projectName = ""
    @State private var projectDescription = ""
    @State private var selectedTemplate: ProjectTemplate?
    @State private var showTemplateSelector = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Information")) {
                    TextField("Project Name", text: $projectName)
                    
                    TextField("Description (optional)", text: $projectDescription)
                        .frame(height: 100, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                }
                
                Section(header: Text("Template")) {
                    Button {
                        showTemplateSelector = true
                    } label: {
                        HStack {
                            Text(selectedTemplate?.name ?? "None")
                                .foregroundColor(selectedTemplate == nil ? .secondary : .primary)
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("New Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createProject()
                    }
                    .disabled(projectName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .sheet(isPresented: $showTemplateSelector) {
                TemplateSelectionView(selectedTemplate: $selectedTemplate)
                    .environmentObject(projectManager)
            }
        }
    }
    
    private func createProject() {
        do {
            let cleanedName = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
            let cleanedDescription = projectDescription.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = cleanedDescription.isEmpty ? nil : cleanedDescription
            
            _ = try projectManager.createProject(
                name: cleanedName,
                description: description,
                template: selectedTemplate
            )
            
            dismiss()
        } catch {
            print("Error creating project: \(error)")
        }
    }
}

struct TemplateSelectionView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedTemplate: ProjectTemplate?
    
    var body: some View {
        NavigationStack {
            List(selection: $selectedTemplate) {
                Section {
                    Button {
                        selectedTemplate = nil
                        dismiss()
                    } label: {
                        HStack {
                            Text("No Template")
                                .foregroundColor(.primary)
                            Spacer()
                            if selectedTemplate == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                
                Section("Available Templates") {
                    ForEach(projectManager.templates, id: \.id) { template in
                        Button {
                            selectedTemplate = template
                            dismiss()
                        } label: {
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(template.name)
                                        .foregroundColor(.primary)
                                    
                                    if let description = template.description {
                                        Text(description)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                                
                                if selectedTemplate?.id == template.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .navigationTitle("Select Template")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct ProjectDetailView: View {
    @EnvironmentObject var projectManager: ProjectManager
    @State var project: Project
    @State private var isEditingProject = false
    @State private var showAddMemberSheet = false
    @State private var showAddAssetSheet = false
    @State private var selectedTab = "overview"
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Overview tab
            ProjectOverviewView(project: $project)
                .tabItem {
                    Label("Overview", systemImage: "doc.text")
                }
                .tag("overview")
            
            // Assets tab
            ProjectAssetsView(project: $project)
                .tabItem {
                    Label("Assets", systemImage: "photo.on.rectangle")
                }
                .tag("assets")
            
            // Comments tab
            ProjectCommentsView(project: $project)
                .tabItem {
                    Label("Comments", systemImage: "text.bubble")
                }
                .tag("comments")
            
            // Activity tab
            ProjectActivityView(project: $project)
                .tabItem {
                    Label("Activity", systemImage: "clock")
                }
                .tag("activity")
            
            // Members tab
            ProjectMembersView(project: $project)
                .tabItem {
                    Label("Members", systemImage: "person.2")
                }
                .tag("members")
        }
        .navigationTitle(project.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        isEditingProject = true
                    } label: {
                        Label("Edit Project", systemImage: "pencil")
                    }
                    
                    Menu("Change Status") {
                        ForEach(ProjectStatus.allCases, id: \.self) { status in
                            if status != project.status {
                                Button(status.displayName) {
                                    changeProjectStatus(to: status)
                                }
                            }
                        }
                    }
                    
                    Divider()
                    
                    if selectedTab == "members" {
                        Button {
                            showAddMemberSheet = true
                        } label: {
                            Label("Add Member", systemImage: "person.badge.plus")
                        }
                    }
                    
                    if selectedTab == "assets" {
                        Button {
                            showAddAssetSheet = true
                        } label: {
                            Label("Add Asset", systemImage: "plus.rectangle.on.rectangle")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $isEditingProject) {
            EditProjectView(project: project) { updatedProject in
                do {
                    try projectManager.updateProject(updatedProject)
                    self.project = updatedProject
                } catch {
                    print("Error updating project: \(error)")
                }
            }
        }
        .sheet(isPresented: $showAddMemberSheet) {
            AddMemberView(project: project) { userID, userName, role in
                do {
                    try projectManager.addMemberToProject(project.id, userId: userID, userName: userName, role: role)
                    
                    // Update local project state
                    if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                        self.project = updatedProject
                    }
                } catch {
                    print("Error adding member: \(error)")
                }
            }
        }
        .sheet(isPresented: $showAddAssetSheet) {
            AddAssetView(project: project) { name, type, dimensions in
                do {
                    _ = try projectManager.addAssetToProject(
                        project.id,
                        name: name,
                        type: type,
                        dimensions: dimensions
                    )
                    
                    // Update local project state
                    if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                        self.project = updatedProject
                    }
                } catch {
                    print("Error adding asset: \(error)")
                }
            }
        }
    }
    
    private func changeProjectStatus(to status: ProjectStatus) {
        do {
            try projectManager.changeProjectStatus(project.id, to: status)
            
            // Update local project state
            if let updatedProject = projectManager.projects.first(where: { $0.id == project.id }) {
                self.project = updatedProject
            }
        } catch {
            print("Error changing project status: \(error)")
        }
    }
}

struct ProjectOverviewView: View {
    @Binding var project: Project
    
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Project header
                VStack(alignment: .leading, spacing: 8) {
                    // Status indicator
                    HStack {
                        Text(project.status.displayName)
                            .font(.subheadline)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(statusColor(for: project.status).opacity(0.2))
                            .foregroundColor(statusColor(for: project.status))
                            .cornerRadius(6)
                        
                        Spacer()
                        
                        // Date info
                        VStack(alignment: .trailing, spacing: 4) {
                            Text("Created \(dateFormatter.string(from: project.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            
                            Text("Updated \(dateFormatter.string(from: project.updatedAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    // Description if available
                    if let description = project.description, !description.isEmpty {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .padding(.vertical, 4)
                    }
                    
                    // Tags
                    if !project.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(project.tags, id: \.self) { tag in
                                    Text(tag)
                                        .font(.caption)
                                        .padding(.vertical, 3)
                                        .padding(.horizontal, 8)
                                        .background(Color.gray.opacity(0.2))
                                        .cornerRadius(6)
                                }
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Stats summary
                HStack(spacing: 18) {
                    Spacer()
                    
                    statsItem(
                        count: project.assets.count,
                        label: "Assets",
                        icon: "photo.on.rectangle"
                    )
                    
                    statsItem(
                        count: project.members.count,
                        label: "Members",
                        icon: "person.2"
                    )
                    
                    statsItem(
                        count: project.comments.count,
                        label: "Comments",
                        icon: "text.bubble"
                    )
                    
                    Spacer()
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
                
                // Recent activity
                VStack(alignment: .leading, spacing: 12) {
                    Text("Recent Activity")
                        .font(.headline)
                    
                    if project.activities.isEmpty {
                        Text("No activity yet")
                            .foregroundColor(.secondary)
                            .padding()
                    } else {
                        ForEach(project.activities.prefix(5), id: \.id) { activity in
                            activityRow(activity)
                        }
                    }
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .padding()
        }
    }
    
    private func statusColor(for status: ProjectStatus) -> Color {
        switch status {
        case .draft:
            return .gray
        case .review:
            return .orange
        case .approved:
            return .green
        case .published:
            return .blue
        case .archived:
            return .purple
        }
    }
    
    private func statsItem(count: Int, label: String, icon: String) -> some View {
        VStack {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)
            
            Text("\(count)")
                .font(.title3)
                .fontWeight(.semibold)
            
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 70)
    }
    
    private func activityRow(_ activity: ProjectActivity) -> some View {
        HStack(alignment: .top) {
            // Activity icon
            Image(systemName: activityIcon(for: activity.activityType))
                .foregroundColor(activityColor(for: activity.activityType))
                .frame(width: 24, height: 24)
                .background(activityColor(for: activity.activityType).opacity(0.2))
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 4) {
                // Activity description
                Text(activity.description)
                    .font(.subheadline)
                
                // User who performed the activity
                Text("by \(activity.userName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                // Timestamp
                Text(timeAgoFormatter(from: activity.timestamp))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
    }
    
    private func activityIcon(for type: String) -> String {
        switch type {
        case "project_created":
            return "doc.badge.plus"
        case "project_updated":
            return "doc.badge.gearshape"
        case "status_changed":
            return "arrow.triangle.swap"
        case "member_added", "member_invited":
            return "person.badge.plus"
        case "member_removed":
            return "person.badge.minus"
        case "role_changed":
            return "person.fill.questionmark"
        case "asset_added":
            return "plus.rectangle.on.rectangle"
        case "asset_updated":
            return "square.and.pencil"
        case "asset_status_changed":
            return "arrow.triangle.swap"
        case "comment_added":
            return "bubble.left.and.text.bubble.right"
        case "comment_resolved":
            return "checkmark.bubble"
        default:
            return "doc.text"
        }
    }
    
    private func activityColor(for type: String) -> Color {
        switch type {
        case "project_created":
            return .green
        case "project_updated":
            return .blue
        case "status_changed":
            return .purple
        case "member_added", "member_invited":
            return .blue
        case "member_removed":
            return .red
        case "role_changed":
            return .orange
        case "asset_added":
            return .green
        case "asset_updated":
            return .blue
        case "asset_status_changed":
            return .purple
        case "comment_added":
            return .blue
        case "comment_resolved":
            return .green
        default:
            return .gray
        }
    }
    
    private func timeAgoFormatter(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour) hour\(hour == 1 ? "" : "s") ago"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute) minute\(minute == 1 ? "" : "s") ago"
        } else {
            return "just now"
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()
}

struct EditProjectView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let onSave: (Project) -> Void
    
    @State private var name: String
    @State private var description: String
    @State private var tags: [String]
    
    init(project: Project, onSave: @escaping (Project) -> Void) {
        self.project = project
        self.onSave = onSave
        
        _name = State(initialValue: project.name)
        _description = State(initialValue: project.description ?? "")
        _tags = State(initialValue: project.tags)
    }
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Project Information")) {
                    TextField("Project Name", text: $name)
                    
                    TextField("Description (optional)", text: $description)
                        .frame(height: 100, alignment: .topLeading)
                        .multilineTextAlignment(.leading)
                }
                
                Section(header: Text("Tags")) {
                    ForEach(tags.indices, id: \.self) { index in
                        HStack {
                            TextField("Tag", text: $tags[index])
                            
                            Button {
                                tags.remove(at: index)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(BorderlessButtonStyle())
                        }
                    }
                    
                    Button {
                        tags.append("")
                    } label: {
                        Label("Add Tag", systemImage: "plus")
                    }
                }
            }
            .navigationTitle("Edit Project")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveProject()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func saveProject() {
        var updatedProject = project
        updatedProject.name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        let cleanedDescription = description.trimmingCharacters(in: .whitespacesAndNewlines)
        updatedProject.description = cleanedDescription.isEmpty ? nil : cleanedDescription
        
        // Filter out empty tags
        updatedProject.tags = tags.map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        
        onSave(updatedProject)
        dismiss()
    }
}

// Placeholder views for project details tabs
struct ProjectAssetsView: View {
    @Binding var project: Project
    
    var body: some View {
        List {
            ForEach(project.assets, id: \.id) { asset in
                VStack(alignment: .leading) {
                    Text(asset.name)
                        .font(.headline)
                    Text("Type: \(asset.type)")
                        .font(.subheadline)
                    Text("Status: \(asset.status.displayName)")
                        .font(.subheadline)
                }
            }
        }
    }
}

struct ProjectCommentsView: View {
    @Binding var project: Project
    
    var body: some View {
        List {
            ForEach(project.comments, id: \.id) { comment in
                VStack(alignment: .leading) {
                    HStack {
                        Text(comment.userName)
                            .font(.headline)
                        Spacer()
                        Text(dateFormatter.string(from: comment.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(comment.text)
                        .font(.body)
                        .padding(.vertical, 2)
                    
                    if comment.resolved {
                        Text("Resolved")
                            .font(.caption)
                            .foregroundColor(.green)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ProjectActivityView: View {
    @Binding var project: Project
    
    var body: some View {
        List {
            ForEach(project.activities, id: \.id) { activity in
                VStack(alignment: .leading) {
                    HStack {
                        Text(activity.description)
                            .font(.headline)
                        Spacer()
                        Text(dateFormatter.string(from: activity.timestamp))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text("By: \(activity.userName)")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }()
}

struct ProjectMembersView: View {
    @Binding var project: Project
    
    var body: some View {
        List {
            ForEach(project.members, id: \.id) { member in
                VStack(alignment: .leading) {
                    HStack {
                        Text(member.userName)
                            .font(.headline)
                        Spacer()
                        Text(member.role.displayName)
                            .font(.subheadline)
                            .foregroundColor(roleColor(for: member.role))
                    }
                    
                    Text("Added: \(dateFormatter.string(from: member.addedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 4)
            }
        }
    }
    
    private func roleColor(for role: ProjectRole) -> Color {
        switch role {
        case .owner:
            return .red
        case .editor:
            return .blue
        case .reviewer:
            return .orange
        case .viewer:
            return .gray
        }
    }
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        return formatter
    }()
}

struct AddMemberView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let onAdd: (String, String, ProjectRole) -> Void
    
    @State private var userId = ""
    @State private var userName = ""
    @State private var selectedRole: ProjectRole = .viewer
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Member Information")) {
                    TextField("User ID", text: $userId)
                    TextField("User Name", text: $userName)
                }
                
                Section(header: Text("Role")) {
                    Picker("Role", selection: $selectedRole) {
                        ForEach(ProjectRole.allCases, id: \.self) { role in
                            Text(role.displayName).tag(role)
                        }
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Permissions:")
                            .font(.headline)
                        
                        ForEach(selectedRole.permissions, id: \.self) { permission in
                            HStack {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                
                                Text(displayName(for: permission))
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Add Member")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addMember()
                    }
                    .disabled(userId.isEmpty || userName.isEmpty)
                }
            }
        }
    }
    
    private func addMember() {
        let cleanUserId = userId.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanUserName = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanUserId.isEmpty && !cleanUserName.isEmpty {
            onAdd(cleanUserId, cleanUserName, selectedRole)
            dismiss()
        }
    }
    
    private func displayName(for permission: ProjectPermission) -> String {
        switch permission {
        case .view:
            return "View project and assets"
        case .edit:
            return "Edit project and assets"
        case .comment:
            return "Add and resolve comments"
        case .approve:
            return "Approve designs and changes"
        case .publish:
            return "Publish project"
        case .manageMembers:
            return "Manage project members"
        case .delete:
            return "Delete project"
        }
    }
}

struct AddAssetView: View {
    @Environment(\.dismiss) private var dismiss
    let project: Project
    let onAdd: (String, String, (width: CGFloat, height: CGFloat)?) -> Void
    
    @State private var name = ""
    @State private var type = "design"
    @State private var width = ""
    @State private var height = ""
    
    private let assetTypes = ["design", "image", "video", "document"]
    
    var body: some View {
        NavigationStack {
            Form {
                Section(header: Text("Asset Information")) {
                    TextField("Asset Name", text: $name)
                    
                    Picker("Asset Type", selection: $type) {
                        ForEach(assetTypes, id: \.self) { type in
                            Text(type.capitalized).tag(type)
                        }
                    }
                }
                
                Section(header: Text("Dimensions (optional)")) {
                    HStack {
                        TextField("Width", text: $width)
                            .keyboardType(.numberPad)
                        Text("×")
                        TextField("Height", text: $height)
                            .keyboardType(.numberPad)
                    }
                }
            }
            .navigationTitle("Add Asset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addAsset()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
    }
    
    private func addAsset() {
        let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if !cleanName.isEmpty {
            // Parse dimensions if provided
            var dimensions: (width: CGFloat, height: CGFloat)? = nil
            
            if let widthValue = Float(width), let heightValue = Float(height),
               widthValue > 0, heightValue > 0 {
                dimensions = (width: CGFloat(widthValue), height: CGFloat(heightValue))
            }
            
            onAdd(cleanName, type, dimensions)
            dismiss()
        }
    }
}

struct ProjectsView_Previews: PreviewProvider {
    static var previews: some View {
        ProjectsView()
            .environmentObject(ProjectManager())
    }
} 