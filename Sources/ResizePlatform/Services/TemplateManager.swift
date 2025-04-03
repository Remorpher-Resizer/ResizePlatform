import Foundation
import SwiftUI

class TemplateManager: ObservableObject {
    @Published var templates: [Template] = []
    @Published var categories: [TemplateCategory] = []
    @Published var collections: [TemplateCollection] = []
    
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let templatesDirectory: URL
    private let categoriesDirectory: URL
    private let collectionsDirectory: URL
    
    init() {
        // Set up directories
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        templatesDirectory = documentsDirectory.appendingPathComponent("Templates")
        categoriesDirectory = documentsDirectory.appendingPathComponent("TemplateCategories")
        collectionsDirectory = documentsDirectory.appendingPathComponent("TemplateCollections")
        
        // Create directories if needed
        try? fileManager.createDirectory(at: templatesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: categoriesDirectory, withIntermediateDirectories: true)
        try? fileManager.createDirectory(at: collectionsDirectory, withIntermediateDirectories: true)
        
        // Load templates, categories, and collections
        loadTemplates()
        loadCategories()
        loadCollections()
    }
    
    // MARK: - Template Operations
    
    // Load all templates
    private func loadTemplates() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: templatesDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            templates = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(Template.self, from: data)
            }
            
            // Sort templates by update date, newest first
            templates.sort { $0.updatedAt > $1.updatedAt }
            
        } catch {
            print("Error loading templates: \(error)")
        }
    }
    
    // Create a new template from a design
    func createTemplate(from design: Design, 
                        name: String, 
                        description: String? = nil,
                        type: TemplateType = .design,
                        accessLevel: TemplateAccessLevel = .private,
                        categories: [String] = [],
                        tags: [String] = [],
                        elementStates: [String: TemplateElementState]? = nil,
                        variables: [TemplateVariable]? = nil,
                        platforms: [String]? = nil,
                        brandKitId: String? = nil) throws -> Template {
        
        let templateId = UUID().uuidString
        let now = Date()
        
        // Generate element states if not provided
        let states: [String: TemplateElementState]
        if let elementStates = elementStates {
            states = elementStates
        } else {
            // By default, make all elements fixed
            states = Dictionary(uniqueKeysWithValues: design.elements.map { ($0.id, TemplateElementState.fixed) })
        }
        
        // Create template
        let template = Template(
            id: templateId,
            name: name,
            description: description,
            type: type,
            accessLevel: accessLevel,
            createdAt: now,
            updatedAt: now,
            createdById: NSUserName(),
            version: "1.0.0",
            baseDesign: design,
            categories: categories,
            tags: tags,
            variables: variables ?? [],
            elementStates: states,
            platforms: platforms,
            brandKitId: brandKitId
        )
        
        // Save template
        try saveTemplate(template)
        
        // Add to in-memory collection
        templates.insert(template, at: 0)
        
        return template
    }
    
    // Save a template to disk
    private func saveTemplate(_ template: Template) throws {
        let fileURL = templatesDirectory.appendingPathComponent("\(template.id).json")
        let data = try JSONEncoder().encode(template)
        try data.write(to: fileURL)
    }
    
    // Update an existing template
    func updateTemplate(_ template: Template) throws -> Template {
        var updatedTemplate = template
        updatedTemplate.updatedAt = Date()
        
        // Check if this is a new version
        if let existingIndex = templates.firstIndex(where: { $0.id == template.id }) {
            let existingTemplate = templates[existingIndex]
            
            // If the version changed, update version history
            if existingTemplate.version != template.version {
                var previousVersions = updatedTemplate.previousVersions ?? []
                previousVersions.append(existingTemplate.version)
                updatedTemplate.previousVersions = previousVersions
            }
            
            // Update in memory
            templates[existingIndex] = updatedTemplate
        } else {
            // Add to memory if not already present
            templates.append(updatedTemplate)
        }
        
        // Save to disk
        try saveTemplate(updatedTemplate)
        
        return updatedTemplate
    }
    
    // Create a new version of a template
    func createNewVersion(_ template: Template, newVersion: String) throws -> Template {
        var updatedTemplate = template
        
        // Store the current version in previous versions
        var previousVersions = updatedTemplate.previousVersions ?? []
        previousVersions.append(updatedTemplate.version)
        
        // Update the version
        updatedTemplate.version = newVersion
        updatedTemplate.previousVersions = previousVersions
        updatedTemplate.updatedAt = Date()
        
        // Save and return
        try saveTemplate(updatedTemplate)
        
        // Update in memory
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = updatedTemplate
        }
        
        return updatedTemplate
    }
    
    // Apply a template to create a new design
    func applyTemplate(_ template: Template, variableValues: [String: String]? = nil) -> Design {
        return template.createDesign(variableValues: variableValues)
    }
    
    // Apply a brand kit to a template
    func applyBrandKit(_ brandKit: BrandKit, to template: Template) throws -> Template {
        var updatedTemplate = template
        var updatedDesign = template.baseDesign
        
        // Apply brand colors to elements
        for i in 0..<updatedDesign.elements.count {
            var element = updatedDesign.elements[i]
            
            // Check if this element uses a brand color
            if let backgroundColor = element.backgroundColor, 
               backgroundColor.starts(with: "${brand.color.") {
                // Extract the color role from the placeholder
                let colorRole = backgroundColor.replacingOccurrences(of: "${brand.color.", with: "")
                                           .replacingOccurrences(of: "}", with: "")
                
                // Find the color in the brand kit
                if let color = brandKit.colorsForRole(colorRole).first {
                    element.backgroundColor = color.colorHex
                }
            }
            
            // Update the element
            updatedDesign.elements[i] = element
        }
        
        // Update the design in the template
        updatedTemplate.baseDesign = updatedDesign
        updatedTemplate.brandKitId = brandKit.id
        updatedTemplate.updatedAt = Date()
        
        // Save the updated template
        try saveTemplate(updatedTemplate)
        
        // Update in memory
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = updatedTemplate
        }
        
        return updatedTemplate
    }
    
    // Delete a template
    func deleteTemplate(id: String) throws {
        // Remove from memory
        templates.removeAll { $0.id == id }
        
        // Remove from disk
        let fileURL = templatesDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Find templates with specific criteria
    func findTemplates(type: TemplateType? = nil,
                       category: String? = nil,
                       platform: String? = nil,
                       dimensions: (width: CGFloat, height: CGFloat)? = nil,
                       tag: String? = nil,
                       searchText: String? = nil) -> [Template] {
        
        var filteredTemplates = templates
        
        // Filter by type
        if let type = type {
            filteredTemplates = filteredTemplates.filter { $0.type == type }
        }
        
        // Filter by category
        if let category = category {
            filteredTemplates = filteredTemplates.filter { $0.categories.contains(category) }
        }
        
        // Filter by platform
        if let platform = platform {
            filteredTemplates = filteredTemplates.filter { $0.platforms?.contains(platform) ?? false }
        }
        
        // Filter by dimensions
        if let dimensions = dimensions {
            filteredTemplates = filteredTemplates.filter {
                $0.baseDesign.width == dimensions.width && $0.baseDesign.height == dimensions.height
            }
        }
        
        // Filter by tag
        if let tag = tag {
            filteredTemplates = filteredTemplates.filter { $0.tags.contains(tag) }
        }
        
        // Filter by search text
        if let searchText = searchText, !searchText.isEmpty {
            filteredTemplates = filteredTemplates.filter {
                $0.name.localizedCaseInsensitiveContains(searchText) ||
                $0.description?.localizedCaseInsensitiveContains(searchText) ?? false ||
                $0.tags.contains { $0.localizedCaseInsensitiveContains(searchText) }
            }
        }
        
        return filteredTemplates
    }
    
    // MARK: - Category Operations
    
    // Load all categories
    private func loadCategories() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: categoriesDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            categories = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(TemplateCategory.self, from: data)
            }
            
            // Sort categories by sort order
            categories.sort { $0.sortOrder < $1.sortOrder }
            
        } catch {
            print("Error loading categories: \(error)")
        }
    }
    
    // Create a new category
    func createCategory(name: String, description: String? = nil, parentId: String? = nil) throws -> TemplateCategory {
        let categoryId = UUID().uuidString
        
        // Find the highest sort order
        let maxSortOrder = categories.map { $0.sortOrder }.max() ?? 0
        
        let category = TemplateCategory(
            id: categoryId,
            name: name,
            description: description,
            parentId: parentId,
            sortOrder: maxSortOrder + 1
        )
        
        // Save category
        try saveCategory(category)
        
        // Add to in-memory collection
        categories.append(category)
        
        return category
    }
    
    // Save a category to disk
    private func saveCategory(_ category: TemplateCategory) throws {
        let fileURL = categoriesDirectory.appendingPathComponent("\(category.id).json")
        let data = try JSONEncoder().encode(category)
        try data.write(to: fileURL)
    }
    
    // Update an existing category
    func updateCategory(_ category: TemplateCategory) throws {
        // Update in memory
        if let index = categories.firstIndex(where: { $0.id == category.id }) {
            categories[index] = category
        } else {
            categories.append(category)
        }
        
        // Save to disk
        try saveCategory(category)
    }
    
    // Delete a category
    func deleteCategory(id: String) throws {
        // Remove from memory
        categories.removeAll { $0.id == id }
        
        // Remove from disk
        let fileURL = categoriesDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Get child categories for a parent
    func getChildCategories(parentId: String?) -> [TemplateCategory] {
        return categories.filter { $0.parentId == parentId }
    }
    
    // MARK: - Collection Operations
    
    // Load all collections
    private func loadCollections() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: collectionsDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            collections = try jsonFiles.compactMap { fileURL in
                let data = try Data(contentsOf: fileURL)
                return try JSONDecoder().decode(TemplateCollection.self, from: data)
            }
            
            // Sort collections by update date, newest first
            collections.sort { $0.updatedAt > $1.updatedAt }
            
        } catch {
            print("Error loading collections: \(error)")
        }
    }
    
    // Create a new collection
    func createCollection(name: String, description: String? = nil, templateIds: [String] = [], accessLevel: TemplateAccessLevel = .private) throws -> TemplateCollection {
        let collectionId = UUID().uuidString
        let now = Date()
        
        let collection = TemplateCollection(
            id: collectionId,
            name: name,
            description: description,
            accessLevel: accessLevel,
            templateIds: templateIds,
            createdAt: now,
            updatedAt: now,
            createdById: NSUserName()
        )
        
        // Save collection
        try saveCollection(collection)
        
        // Add to in-memory collection
        collections.insert(collection, at: 0)
        
        return collection
    }
    
    // Save a collection to disk
    private func saveCollection(_ collection: TemplateCollection) throws {
        let fileURL = collectionsDirectory.appendingPathComponent("\(collection.id).json")
        let data = try JSONEncoder().encode(collection)
        try data.write(to: fileURL)
    }
    
    // Update an existing collection
    func updateCollection(_ collection: TemplateCollection) throws {
        var updatedCollection = collection
        updatedCollection.updatedAt = Date()
        
        // Update in memory
        if let index = collections.firstIndex(where: { $0.id == collection.id }) {
            collections[index] = updatedCollection
        } else {
            collections.append(updatedCollection)
        }
        
        // Save to disk
        try saveCollection(updatedCollection)
    }
    
    // Delete a collection
    func deleteCollection(id: String) throws {
        // Remove from memory
        collections.removeAll { $0.id == id }
        
        // Remove from disk
        let fileURL = collectionsDirectory.appendingPathComponent("\(id).json")
        try fileManager.removeItem(at: fileURL)
    }
    
    // Get templates in a collection
    func getTemplatesInCollection(_ collectionId: String) -> [Template] {
        guard let collection = collections.first(where: { $0.id == collectionId }) else {
            return []
        }
        
        return templates.filter { collection.templateIds.contains($0.id) }
    }
    
    // Add a template to a collection
    func addTemplateToCollection(templateId: String, collectionId: String) throws {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }),
              templates.contains(where: { $0.id == templateId }) else {
            return
        }
        
        var collection = collections[collectionIndex]
        
        // Add the template if not already in the collection
        if !collection.templateIds.contains(templateId) {
            collection.templateIds.append(templateId)
            collection.updatedAt = Date()
            
            // Update the collection
            try updateCollection(collection)
        }
    }
    
    // Remove a template from a collection
    func removeTemplateFromCollection(templateId: String, collectionId: String) throws {
        guard let collectionIndex = collections.firstIndex(where: { $0.id == collectionId }) else {
            return
        }
        
        var collection = collections[collectionIndex]
        
        // Remove the template if present
        if collection.templateIds.contains(templateId) {
            collection.templateIds.removeAll { $0 == templateId }
            collection.updatedAt = Date()
            
            // Update the collection
            try updateCollection(collection)
        }
    }
    
    // MARK: - Template Thumbnail Generation
    
    // Generate a thumbnail for a template
    func generateThumbnail(for template: Template) -> NSImage {
        // Create a preview design
        let previewDesign = TemplateUtility.generatePreview(from: template)
        
        // In a real app, we would render the design
        // For this example, we'll return a placeholder
        let placeholder = NSImage(named: "TemplatePlaceholder") ?? NSImage()
        return placeholder
    }
} 