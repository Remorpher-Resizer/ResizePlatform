import SwiftUI

public struct NewProjectView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var projectManager: ProjectManager
    
    @State private var name = ""
    @State private var description = ""
    @State private var selectedTemplate: ProjectTemplate?
    @State private var tags: [String] = []
    @State private var newTag = ""
    
    private var templates: [ProjectTemplate] {
        projectManager.templates
    }
    
    public var body: some View {
        NavigationStack {
            Form {
                Section("Project Details") {
                    TextField("Project Name", text: $name)
                    TextField("Description", text: $description, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("Template") {
                    Picker("Template", selection: $selectedTemplate) {
                        Text("No Template").tag(Optional<ProjectTemplate>.none)
                        ForEach(templates) { template in
                            Text(template.name).tag(Optional(template))
                        }
                    }
                }
                
                Section("Tags") {
                    ForEach(tags, id: \.self) { tag in
                        HStack {
                            Text(tag)
                            Spacer()
                            Button {
                                tags.removeAll { $0 == tag }
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundColor(.red)
                            }
                        }
                    }
                    
                    HStack {
                        TextField("New Tag", text: $newTag)
                        Button {
                            if !newTag.isEmpty && !tags.contains(newTag) {
                                tags.append(newTag)
                                newTag = ""
                            }
                        } label: {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.blue)
                        }
                        .disabled(newTag.isEmpty)
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
                    .disabled(name.isEmpty)
                }
            }
        }
    }
    
    private func createProject() {
        do {
            _ = try projectManager.createProject(
                name: name,
                description: description.isEmpty ? nil : description,
                template: selectedTemplate
            )
            dismiss()
        } catch {
            print("Error creating project: \(error)")
        }
    }
} 