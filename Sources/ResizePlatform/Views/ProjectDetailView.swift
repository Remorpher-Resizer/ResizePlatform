import SwiftUI

public struct ProjectDetailView: View {
    let project: Project
    @EnvironmentObject var projectManager: ProjectManager
    @State private var selectedTab = 0
    
    public var body: some View {
        VStack {
            // Project header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(project.name)
                        .font(.title)
                        .bold()
                    
                    Spacer()
                    
                    Text(project.status.displayName)
                        .font(.caption)
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(statusColor(for: project.status).opacity(0.2))
                        .foregroundColor(statusColor(for: project.status))
                        .cornerRadius(4)
                }
                
                if let description = project.description {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                HStack {
                    Text("Created by \(project.createdBy)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Text("Updated \(dateFormatter.string(from: project.updatedAt))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            
            // Tab view for different sections
            TabView(selection: $selectedTab) {
                // Overview tab
                ProjectOverviewTab(project: project)
                    .tabItem {
                        Label("Overview", systemImage: "doc.text")
                    }
                    .tag(0)
                
                // Assets tab
                ProjectAssetsTab(project: project)
                    .tabItem {
                        Label("Assets", systemImage: "photo.on.rectangle")
                    }
                    .tag(1)
                
                // Members tab
                ProjectMembersTab(project: project)
                    .tabItem {
                        Label("Members", systemImage: "person.2")
                    }
                    .tag(2)
                
                // Activity tab
                ProjectActivityTab(project: project)
                    .tabItem {
                        Label("Activity", systemImage: "clock")
                    }
                    .tag(3)
            }
        }
        .navigationTitle("Project Details")
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

// MARK: - Tab Views

struct ProjectOverviewTab: View {
    let project: Project
    
    var body: some View {
        List {
            Section("Project Information") {
                LabeledContent("Status", value: project.status.displayName)
                if let dueDate = project.dueDate {
                    LabeledContent("Due Date", value: dateFormatter.string(from: dueDate))
                }
            }
            
            Section("Tags") {
                FlowLayout(spacing: 8) {
                    ForEach(project.tags, id: \.self) { tag in
                        Text(tag)
                            .font(.caption)
                            .padding(.vertical, 4)
                            .padding(.horizontal, 8)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            
            Section("Statistics") {
                LabeledContent("Assets", value: "\(project.assets.count)")
                LabeledContent("Members", value: "\(project.members.count)")
                LabeledContent("Comments", value: "\(project.comments.count)")
            }
        }
    }
}

struct ProjectAssetsTab: View {
    let project: Project
    
    var body: some View {
        List {
            ForEach(project.assets) { asset in
                VStack(alignment: .leading) {
                    Text(asset.name)
                        .font(.headline)
                    if let dimensions = asset.dimensionsText {
                        Text(dimensions)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
    }
}

struct ProjectMembersTab: View {
    let project: Project
    
    var body: some View {
        List {
            ForEach(project.members) { member in
                VStack(alignment: .leading) {
                    Text(member.userName)
                        .font(.headline)
                    Text(member.role.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

struct ProjectActivityTab: View {
    let project: Project
    
    var body: some View {
        List {
            ForEach(project.recentActivities()) { activity in
                VStack(alignment: .leading) {
                    Text(activity.description)
                        .font(.headline)
                    Text("\(activity.userName) • \(dateFormatter.string(from: activity.timestamp))")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Helper Views

struct FlowLayout: Layout {
    let spacing: CGFloat
    
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, spacing: spacing, subviews: subviews)
        return result.size
    }
    
    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, spacing: spacing, subviews: subviews)
        for (index, line) in result.lines.enumerated() {
            let y = bounds.minY + result.lineOffsets[index]
            var x = bounds.minX
            for item in line {
                let position = CGPoint(x: x, y: y)
                subviews[item.index].place(at: position, proposal: .unspecified)
                x += item.size.width + spacing
            }
        }
    }
    
    private struct FlowResult {
        struct Item {
            let index: Int
            let size: CGSize
        }
        
        struct Line {
            var items: [Item] = []
            var width: CGFloat = 0
            var height: CGFloat = 0
        }
        
        let lines: [Line]
        let lineOffsets: [CGFloat]
        let size: CGSize
        
        init(in maxWidth: CGFloat, spacing: CGFloat, subviews: Subviews) {
            var lines: [Line] = [Line()]
            var currentLine = 0
            var currentX: CGFloat = 0
            var maxY: CGFloat = 0
            var lineOffsets: [CGFloat] = [0]
            
            for (index, subview) in subviews.enumerated() {
                let size = subview.sizeThatFits(.unspecified)
                
                if currentX + size.width > maxWidth {
                    currentLine += 1
                    lines.append(Line())
                    lineOffsets.append(maxY + spacing)
                    currentX = 0
                }
                
                lines[currentLine].items.append(Item(index: index, size: size))
                lines[currentLine].width += size.width + spacing
                lines[currentLine].height = max(lines[currentLine].height, size.height)
                currentX += size.width + spacing
                maxY = max(maxY, lineOffsets[currentLine] + lines[currentLine].height)
            }
            
            self.lines = lines
            self.lineOffsets = lineOffsets
            self.size = CGSize(width: maxWidth, height: maxY)
        }
    }
} 