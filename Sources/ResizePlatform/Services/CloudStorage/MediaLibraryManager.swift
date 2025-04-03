import Foundation
import SwiftUI

// Cache entry for a cloud file
struct CloudFileCache {
    let file: CloudFile
    let data: Data?
    let thumbnail: NSImage?
    let fetchDate: Date
    let expiryDate: Date
}

// Media library manager to provide unified access to multiple cloud providers
class MediaLibraryManager: ObservableObject {
    // Providers and authentication
    @Published var providers: [CloudStorageProvider] = []
    @Published var activeProviders: [CloudProviderType: CloudStorageProvider] = [:]
    @Published var isAuthenticating: Bool = false
    
    // Current state
    @Published var currentPath: [String: String] = [:] // Provider type to current path mapping
    @Published var currentFiles: [CloudFile] = []
    @Published var isLoading: Bool = false
    @Published var searchResults: [CloudFile] = []
    @Published var isSearching: Bool = false
    @Published var searchQuery: String = ""
    
    // Pagination
    private var paginationInfo: [CloudProviderType: PaginationInfo] = [:]
    
    // Caching
    private var fileCache: [String: CloudFileCache] = [:]
    private let cacheExpiryInterval: TimeInterval = 3600 // 1 hour
    private let downloadQueue = DispatchQueue(label: "com.resizeplatform.mediaLibrary.download", qos: .userInitiated, attributes: .concurrent)
    
    // Initialization
    init() {
        // Create providers for all supported types
        for providerType in CloudProviderType.allCases {
            providers.append(CloudStorageProviderFactory.createProvider(type: providerType))
        }
    }
    
    // Connect to a provider
    func connectProvider(_ providerType: CloudProviderType) async throws {
        isAuthenticating = true
        
        defer {
            DispatchQueue.main.async {
                self.isAuthenticating = false
            }
        }
        
        if let provider = providers.first(where: { $0.providerType == providerType }) {
            try await provider.authenticate()
            
            DispatchQueue.main.async {
                if provider.isAuthenticated {
                    self.activeProviders[providerType] = provider
                    self.currentPath[providerType.rawValue] = "/"
                }
            }
        }
    }
    
    // Disconnect from a provider
    func disconnectProvider(_ providerType: CloudProviderType) async throws {
        if let provider = activeProviders[providerType] {
            try await provider.deauthenticate()
            
            DispatchQueue.main.async {
                self.activeProviders.removeValue(forKey: providerType)
                self.currentPath.removeValue(forKey: providerType.rawValue)
                
                // Remove this provider's files from the current files
                self.currentFiles.removeAll { $0.providerType == providerType }
                
                // Clear cache for this provider
                self.clearCacheForProvider(providerType)
            }
        }
    }
    
    // List files from all active providers (or a specific one)
    func listFiles(fromProvider providerType: CloudProviderType? = nil, inPath path: String? = nil, page: Int = 1, pageSize: Int = 50) async throws {
        DispatchQueue.main.async {
            self.isLoading = true
            self.isSearching = false
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        var allFiles: [CloudFile] = []
        
        if let providerType = providerType, let provider = activeProviders[providerType] {
            // List from a specific provider
            let providersToList = [provider]
            let filePath = path ?? currentPath[providerType.rawValue] ?? "/"
            
            let result = try await provider.listFiles(inPath: filePath, page: page, pageSize: pageSize)
            allFiles.append(contentsOf: result.files)
            
            DispatchQueue.main.async {
                self.paginationInfo[providerType] = result.pagination
                if path != nil {
                    self.currentPath[providerType.rawValue] = path
                }
            }
        } else {
            // List from all active providers
            let providersToList = Array(activeProviders.values)
            
            // Use a task group for parallel execution
            try await withThrowingTaskGroup(of: ListFilesResult.self) { group in
                for provider in providersToList {
                    let providerType = provider.providerType
                    let filePath = path ?? currentPath[providerType.rawValue] ?? "/"
                    
                    group.addTask {
                        return try await provider.listFiles(inPath: filePath, page: page, pageSize: pageSize)
                    }
                }
                
                for try await result in group {
                    if let firstFile = result.files.first {
                        let providerType = firstFile.providerType
                        DispatchQueue.main.async {
                            self.paginationInfo[providerType] = result.pagination
                        }
                    }
                    allFiles.append(contentsOf: result.files)
                }
            }
        }
        
        // Sort files by modified date
        let sortedFiles = allFiles.sorted { 
            ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast)
        }
        
        DispatchQueue.main.async {
            self.currentFiles = sortedFiles
        }
    }
    
    // Search files across all active providers
    func searchFiles(query: String, page: Int = 1, pageSize: Int = 50) async throws {
        guard !query.isEmpty else {
            DispatchQueue.main.async {
                self.searchResults = []
                self.isSearching = false
            }
            return
        }
        
        DispatchQueue.main.async {
            self.isSearching = true
            self.isLoading = true
            self.searchQuery = query
        }
        
        defer {
            DispatchQueue.main.async {
                self.isLoading = false
            }
        }
        
        var allSearchResults: [CloudFile] = []
        let providersToSearch = Array(activeProviders.values)
        
        try await withThrowingTaskGroup(of: ListFilesResult.self) { group in
            for provider in providersToSearch {
                group.addTask {
                    return try await provider.searchFiles(query: query, page: page, pageSize: pageSize)
                }
            }
            
            for try await result in group {
                allSearchResults.append(contentsOf: result.files)
            }
        }
        
        // Sort search results
        let sortedResults = allSearchResults.sorted {
            // Sort by relevance (for now, just modified date)
            ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast)
        }
        
        DispatchQueue.main.async {
            self.searchResults = sortedResults
        }
    }
    
    // Download a file with caching
    func downloadFile(_ file: CloudFile) async throws -> Data {
        // Check cache first
        if let cachedEntry = fileCache[file.id], 
           let cachedData = cachedEntry.data,
           cachedEntry.expiryDate > Date() {
            return cachedData
        }
        
        // If not in cache, download from provider
        if let provider = activeProviders[file.providerType] {
            let fileData = try await provider.downloadFile(file)
            
            // Cache the downloaded data
            let cacheEntry = CloudFileCache(
                file: file,
                data: fileData,
                thumbnail: nil,
                fetchDate: Date(),
                expiryDate: Date().addingTimeInterval(cacheExpiryInterval)
            )
            
            DispatchQueue.main.async {
                self.fileCache[file.id] = cacheEntry
            }
            
            return fileData
        } else {
            throw NSError(domain: "MediaLibraryError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Provider not available for \(file.providerType.displayName)"
            ])
        }
    }
    
    // Get thumbnail for a file with caching
    func getThumbnail(for file: CloudFile, size: CGSize = CGSize(width: 100, height: 100)) async throws -> NSImage? {
        // Check cache first
        if let cachedEntry = fileCache[file.id], 
           let thumbnail = cachedEntry.thumbnail,
           cachedEntry.expiryDate > Date() {
            return thumbnail
        }
        
        // If file is an image and we have its data already, generate thumbnail from data
        if file.isImage, let cachedEntry = fileCache[file.id], let cachedData = cachedEntry.data {
            if let image = NSImage(data: cachedData) {
                let thumbnail = resizeImage(image, to: size)
                
                // Update cache with thumbnail
                var updatedEntry = cachedEntry
                updatedEntry.thumbnail = thumbnail
                
                DispatchQueue.main.async {
                    self.fileCache[file.id] = updatedEntry
                }
                
                return thumbnail
            }
        }
        
        // Try to get thumbnail from provider
        if let provider = activeProviders[file.providerType] {
            if let thumbnailURL = try? await provider.generateThumbnailURL(for: file),
               let thumbnail = try? NSImage(contentsOf: thumbnailURL) {
                
                // Cache the thumbnail
                let cacheEntry = CloudFileCache(
                    file: file,
                    data: nil,
                    thumbnail: thumbnail,
                    fetchDate: Date(),
                    expiryDate: Date().addingTimeInterval(cacheExpiryInterval)
                )
                
                DispatchQueue.main.async {
                    if let existingEntry = self.fileCache[file.id] {
                        var updatedEntry = existingEntry
                        updatedEntry.thumbnail = thumbnail
                        self.fileCache[file.id] = updatedEntry
                    } else {
                        self.fileCache[file.id] = cacheEntry
                    }
                }
                
                return thumbnail
            }
        }
        
        // If we still don't have a thumbnail, download the file and create one
        if file.isImage {
            do {
                let fileData = try await downloadFile(file)
                if let image = NSImage(data: fileData) {
                    let thumbnail = resizeImage(image, to: size)
                    
                    // Update cache with thumbnail
                    if let existingEntry = fileCache[file.id] {
                        var updatedEntry = existingEntry
                        updatedEntry.thumbnail = thumbnail
                        
                        DispatchQueue.main.async {
                            self.fileCache[file.id] = updatedEntry
                        }
                    }
                    
                    return thumbnail
                }
            } catch {
                print("Failed to download file for thumbnail: \(error)")
            }
        }
        
        return nil
    }
    
    // Upload a file to a specific provider
    func uploadFile(data: Data, fileName: String, mimeType: String, toProvider providerType: CloudProviderType, path: String? = nil) async throws -> CloudFile {
        if let provider = activeProviders[providerType] {
            let filePath = path ?? currentPath[providerType.rawValue] ?? "/"
            let file = try await provider.uploadFile(data: data, fileName: fileName, mimeType: mimeType, toPath: filePath)
            
            // Add to current files if we're in the same path
            DispatchQueue.main.async {
                if filePath == self.currentPath[providerType.rawValue] {
                    self.currentFiles.append(file)
                    // Resort
                    self.currentFiles.sort { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
                }
            }
            
            return file
        } else {
            throw NSError(domain: "MediaLibraryError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Provider not available for \(providerType.displayName)"
            ])
        }
    }
    
    // Delete a file
    func deleteFile(_ file: CloudFile) async throws {
        if let provider = activeProviders[file.providerType] {
            try await provider.deleteFile(file)
            
            // Remove from current files if present
            DispatchQueue.main.async {
                self.currentFiles.removeAll { $0.id == file.id }
                self.fileCache.removeValue(forKey: file.id)
            }
        } else {
            throw NSError(domain: "MediaLibraryError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Provider not available for \(file.providerType.displayName)"
            ])
        }
    }
    
    // Generate a shareable link
    func generateSharableLink(for file: CloudFile, expirationInDays: Int? = 7) async throws -> URL {
        if let provider = activeProviders[file.providerType] {
            return try await provider.generateSharableLink(for: file, expirationInDays: expirationInDays)
        } else {
            throw NSError(domain: "MediaLibraryError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "Provider not available for \(file.providerType.displayName)"
            ])
        }
    }
    
    // Clear cache for a specific provider or all providers
    func clearCacheForProvider(_ providerType: CloudProviderType? = nil) {
        if let providerType = providerType {
            fileCache = fileCache.filter { $0.value.file.providerType != providerType }
        } else {
            fileCache.removeAll()
        }
    }
    
    // Get file list from cache (helpful when app comes back from background)
    func getFilesFromCache(forProvider providerType: CloudProviderType, path: String) -> [CloudFile]? {
        let pathFiles = fileCache.values
            .filter { $0.file.providerType == providerType && $0.file.path == path }
            .map { $0.file }
        
        if pathFiles.isEmpty {
            return nil
        }
        
        return pathFiles.sorted { ($0.modifiedAt ?? Date.distantPast) > ($1.modifiedAt ?? Date.distantPast) }
    }
    
    // Helper function to resize an image
    private func resizeImage(_ image: NSImage, to size: CGSize) -> NSImage {
        let resizedImage = NSImage(size: size)
        
        resizedImage.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: size),
                  from: NSRect(origin: .zero, size: image.size),
                  operation: .copy, fraction: 1.0)
        resizedImage.unlockFocus()
        
        return resizedImage
    }
} 