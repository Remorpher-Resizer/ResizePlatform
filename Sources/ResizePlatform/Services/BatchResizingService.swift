import Foundation
import SwiftUI

// Status of a resize job
enum ResizeJobStatus: String, Codable {
    case queued
    case processing
    case completed
    case failed
    case waitingForAdjustment
    case cancelled
}

// Individual resize operation
struct ResizeJob: Identifiable, Codable {
    var id: String
    var sourceDesignId: String
    var targetWidth: CGFloat
    var targetHeight: CGFloat
    var status: ResizeJobStatus
    var createdAt: Date
    var updatedAt: Date
    var completedAt: Date?
    var outputDesignId: String?
    var errorMessage: String?
    var platform: String?
    var platformDimension: String?
    var exportSettings: ExportSettings?
    var requiresManualAdjustment: Bool
    var manualAdjustmentReason: String?
    
    // Human readable description
    var description: String {
        return "\(Int(targetWidth))x\(Int(targetHeight))"
    }
}

// A batch of resize operations
struct ResizeBatch: Identifiable, Codable {
    var id: String
    var name: String
    var sourceDesignId: String
    var createdAt: Date
    var updatedAt: Date
    var status: ResizeJobStatus
    var progress: Double
    var jobs: [ResizeJob]
    var createdBy: String
    
    // Calculate progress based on job statuses
    var calculatedProgress: Double {
        guard !jobs.isEmpty else { return 0 }
        
        let completedCount = jobs.filter { $0.status == .completed }.count
        let totalCount = jobs.count
        
        return Double(completedCount) / Double(totalCount)
    }
    
    // Overall status based on job statuses
    var calculatedStatus: ResizeJobStatus {
        if jobs.isEmpty {
            return .queued
        }
        
        if jobs.contains(where: { $0.status == .waitingForAdjustment }) {
            return .waitingForAdjustment
        }
        
        if jobs.contains(where: { $0.status == .processing }) {
            return .processing
        }
        
        if jobs.allSatisfy({ $0.status == .completed }) {
            return .completed
        }
        
        if jobs.allSatisfy({ $0.status == .cancelled }) {
            return .cancelled
        }
        
        if jobs.contains(where: { $0.status == .failed }) {
            return .failed
        }
        
        return .queued
    }
}

// Service for managing batch resize operations
class BatchResizingService: ObservableObject {
    private let smartResizeService = SmartResizeService()
    private let platformConstraintChecker = PlatformConstraintChecker()
    private let fileManager = FileManager.default
    private let documentsDirectory: URL
    private let batchesDirectory: URL
    
    @Published var activeBatches: [ResizeBatch] = []
    @Published var completedBatches: [ResizeBatch] = []
    @Published var isProcessing: Bool = false
    
    private var processingQueue = DispatchQueue(label: "com.resizeplatform.batchProcessing", qos: .userInteractive)
    private var resizeSemaphore = DispatchSemaphore(value: 4) // Limit concurrent operations
    
    init() {
        // Set up directories
        documentsDirectory = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        batchesDirectory = documentsDirectory.appendingPathComponent("ResizeBatches")
        
        // Create directory if needed
        try? fileManager.createDirectory(at: batchesDirectory, withIntermediateDirectories: true)
        
        // Load saved batches
        loadBatches()
    }
    
    // Load saved batches from disk
    private func loadBatches() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: batchesDirectory, includingPropertiesForKeys: nil)
            let jsonFiles = fileURLs.filter { $0.pathExtension == "json" }
            
            var loadedBatches: [ResizeBatch] = []
            
            for fileURL in jsonFiles {
                do {
                    let data = try Data(contentsOf: fileURL)
                    let batch = try JSONDecoder().decode(ResizeBatch.self, from: data)
                    loadedBatches.append(batch)
                } catch {
                    print("Error loading batch: \(error)")
                }
            }
            
            // Sort and categorize batches
            let sortedBatches = loadedBatches.sorted { $0.updatedAt > $1.updatedAt }
            
            activeBatches = sortedBatches.filter { $0.calculatedStatus != .completed && $0.calculatedStatus != .cancelled }
            completedBatches = sortedBatches.filter { $0.calculatedStatus == .completed || $0.calculatedStatus == .cancelled }
            
            // Resume any processing batches
            for batch in activeBatches where batch.calculatedStatus == .processing {
                resumeBatchProcessing(batch)
            }
            
        } catch {
            print("Error loading batches: \(error)")
        }
    }
    
    // Save a batch to disk
    private func saveBatch(_ batch: ResizeBatch) {
        do {
            var updatedBatch = batch
            updatedBatch.progress = updatedBatch.calculatedProgress
            updatedBatch.status = updatedBatch.calculatedStatus
            updatedBatch.updatedAt = Date()
            
            let fileURL = batchesDirectory.appendingPathComponent("\(batch.id).json")
            let data = try JSONEncoder().encode(updatedBatch)
            try data.write(to: fileURL)
            
            // Update memory lists
            DispatchQueue.main.async {
                if let index = self.activeBatches.firstIndex(where: { $0.id == batch.id }) {
                    self.activeBatches[index] = updatedBatch
                } else if let index = self.completedBatches.firstIndex(where: { $0.id == batch.id }) {
                    self.completedBatches[index] = updatedBatch
                } else if updatedBatch.calculatedStatus == .completed || updatedBatch.calculatedStatus == .cancelled {
                    self.completedBatches.append(updatedBatch)
                } else {
                    self.activeBatches.append(updatedBatch)
                }
                
                // Move between lists if needed
                if updatedBatch.calculatedStatus == .completed || updatedBatch.calculatedStatus == .cancelled {
                    self.activeBatches.removeAll { $0.id == updatedBatch.id }
                    if !self.completedBatches.contains(where: { $0.id == updatedBatch.id }) {
                        self.completedBatches.append(updatedBatch)
                    }
                }
            }
        } catch {
            print("Error saving batch: \(error)")
        }
    }
    
    // Create a new batch resize operation
    func createBatch(
        sourceDesign: Design,
        targetDimensions: [(width: CGFloat, height: CGFloat)],
        name: String,
        platforms: [Platform]? = nil
    ) -> ResizeBatch {
        let batchId = UUID().uuidString
        let now = Date()
        
        var jobs: [ResizeJob] = []
        
        // Create a job for each target dimension
        for (index, dimension) in targetDimensions.enumerated() {
            let jobId = UUID().uuidString
            
            // Find platform constraint if applicable
            var platformInfo: (platform: Platform, dimension: PlatformDimension)?
            if let platforms = platforms {
                for platform in platforms {
                    if let dimension = platform.getDimension(width: Int(dimension.width), height: Int(dimension.height)) {
                        platformInfo = (platform, dimension)
                        break
                    }
                }
            }
            
            let job = ResizeJob(
                id: jobId,
                sourceDesignId: sourceDesign.id,
                targetWidth: dimension.width,
                targetHeight: dimension.height,
                status: .queued,
                createdAt: now,
                updatedAt: now,
                platform: platformInfo?.platform.name,
                platformDimension: platformInfo?.dimension.dimensionText,
                exportSettings: platformInfo != nil ? 
                    ExportSettings.minimumSizeSettings(for: platformInfo!.dimension.supportedFormats.first!) :
                    ExportSettings.defaultWebExport,
                requiresManualAdjustment: false
            )
            
            jobs.append(job)
        }
        
        // Create the batch
        let batch = ResizeBatch(
            id: batchId,
            name: name,
            sourceDesignId: sourceDesign.id,
            createdAt: now,
            updatedAt: now,
            status: .queued,
            progress: 0,
            jobs: jobs,
            createdBy: NSUserName()
        )
        
        // Save and start processing
        saveBatch(batch)
        processBatch(batch, sourceDesign: sourceDesign)
        
        return batch
    }
    
    // Process a batch of resize jobs
    func processBatch(_ batch: ResizeBatch, sourceDesign: Design) {
        var updatedBatch = batch
        updatedBatch.status = .processing
        saveBatch(updatedBatch)
        
        isProcessing = true
        
        // Process all jobs in parallel with a limit
        processingQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Create task group for parallel processing
            Task {
                await withTaskGroup(of: ResizeJob.self) { group in
                    for job in updatedBatch.jobs where job.status != .completed && job.status != .cancelled {
                        group.addTask {
                            return await self.processJob(job, sourceDesign: sourceDesign)
                        }
                    }
                    
                    // As jobs complete, update the batch
                    for await completedJob in group {
                        if let index = updatedBatch.jobs.firstIndex(where: { $0.id == completedJob.id }) {
                            updatedBatch.jobs[index] = completedJob
                            self.saveBatch(updatedBatch)
                        }
                    }
                }
                
                // When all jobs are done, update batch status
                DispatchQueue.main.async {
                    self.isProcessing = false
                    updatedBatch.status = updatedBatch.calculatedStatus
                    updatedBatch.progress = 1.0
                    self.saveBatch(updatedBatch)
                }
            }
        }
    }
    
    // Resume processing for a previously interrupted batch
    func resumeBatchProcessing(_ batch: ResizeBatch) {
        // We need to load the source design first
        Task {
            do {
                // In a real app, we would load the design from storage
                // For now, just mock it with an empty design
                let sourceDesign = Design(
                    id: batch.sourceDesignId,
                    name: "Source Design",
                    width: 1200,
                    height: 800,
                    elements: [],
                    createdAt: Date(),
                    updatedAt: Date()
                )
                
                processBatch(batch, sourceDesign: sourceDesign)
            } catch {
                print("Error resuming batch: \(error)")
                var updatedBatch = batch
                updatedBatch.status = .failed
                saveBatch(updatedBatch)
            }
        }
    }
    
    // Process an individual resize job
    private func processJob(_ job: ResizeJob, sourceDesign: Design) async -> ResizeJob {
        var updatedJob = job
        updatedJob.status = .processing
        updatedJob.updatedAt = Date()
        
        // Notify on main thread
        DispatchQueue.main.async {
            self.updateJobInBatch(updatedJob)
        }
        
        do {
            // Wait for a slot to become available
            resizeSemaphore.wait()
            
            defer {
                // Release slot when done
                resizeSemaphore.signal()
            }
            
            // Execute the smart resize
            let resizedDesign = smartResizeService.resizeDesign(
                design: sourceDesign,
                targetWidth: job.targetWidth,
                targetHeight: job.targetHeight
            )
            
            // Check if this design requires constraints validation
            if let platformName = job.platform, let dimensionText = job.platformDimension, let exportSettings = job.exportSettings {
                // Mock platform and dimension objects for testing
                let platform = Platform(
                    id: UUID().uuidString,
                    name: platformName,
                    dimensions: [],
                    defaultMaxFileSizeKB: 150,
                    defaultSupportedFormats: [.png, .jpg],
                    logoRequirement: false
                )
                
                let dimension = PlatformDimension(
                    id: UUID().uuidString,
                    width: Int(job.targetWidth),
                    height: Int(job.targetHeight),
                    name: dimensionText,
                    maxFileSizeKB: 150,
                    supportedFormats: [.png, .jpg],
                    requirementType: .required
                )
                
                // Check constraints
                let violations = platformConstraintChecker.validateDesign(
                    design: resizedDesign,
                    platform: platform,
                    dimension: dimension,
                    exportSettings: exportSettings
                )
                
                // Check if there are any critical violations that require manual adjustment
                let criticalViolations = violations.filter { $0.severity == .error }
                if !criticalViolations.isEmpty {
                    updatedJob.requiresManualAdjustment = true
                    updatedJob.manualAdjustmentReason = criticalViolations.map { $0.message }.joined(separator: ", ")
                    updatedJob.status = .waitingForAdjustment
                    updatedJob.updatedAt = Date()
                    return updatedJob
                }
            }
            
            // In a real app, we would save the resized design
            // For now, just update the job status
            updatedJob.outputDesignId = UUID().uuidString
            updatedJob.status = .completed
            updatedJob.completedAt = Date()
            updatedJob.updatedAt = Date()
            
        } catch {
            updatedJob.status = .failed
            updatedJob.errorMessage = error.localizedDescription
            updatedJob.updatedAt = Date()
        }
        
        return updatedJob
    }
    
    // Update a job within its batch
    private func updateJobInBatch(_ job: ResizeJob) {
        // Find the batch containing this job
        if let batchIndex = activeBatches.firstIndex(where: { batch in
            batch.jobs.contains { $0.id == job.id }
        }) {
            var updatedBatch = activeBatches[batchIndex]
            
            // Update the job in the batch
            if let jobIndex = updatedBatch.jobs.firstIndex(where: { $0.id == job.id }) {
                updatedBatch.jobs[jobIndex] = job
                updatedBatch.updatedAt = Date()
                
                // Update status and progress
                updatedBatch.progress = updatedBatch.calculatedProgress
                updatedBatch.status = updatedBatch.calculatedStatus
                
                // Save the batch
                saveBatch(updatedBatch)
            }
        }
    }
    
    // Cancel a batch
    func cancelBatch(_ batchId: String) {
        if let batchIndex = activeBatches.firstIndex(where: { $0.id == batchId }) {
            var updatedBatch = activeBatches[batchIndex]
            
            // Update all queued jobs to cancelled
            for i in 0..<updatedBatch.jobs.count {
                if updatedBatch.jobs[i].status == .queued {
                    updatedBatch.jobs[i].status = .cancelled
                    updatedBatch.jobs[i].updatedAt = Date()
                }
            }
            
            updatedBatch.status = updatedBatch.calculatedStatus
            updatedBatch.updatedAt = Date()
            
            saveBatch(updatedBatch)
        }
    }
    
    // Approve manual adjustments and continue processing
    func approveManualAdjustment(jobId: String, adjustedDesign: Design) {
        // Find the job
        for (batchIndex, batch) in activeBatches.enumerated() {
            if let jobIndex = batch.jobs.firstIndex(where: { $0.id == jobId }) {
                var updatedBatch = batch
                var updatedJob = updatedBatch.jobs[jobIndex]
                
                // Update job status
                updatedJob.status = .completed
                updatedJob.outputDesignId = adjustedDesign.id
                updatedJob.requiresManualAdjustment = false
                updatedJob.completedAt = Date()
                updatedJob.updatedAt = Date()
                
                // Update batch
                updatedBatch.jobs[jobIndex] = updatedJob
                updatedBatch.updatedAt = Date()
                
                saveBatch(updatedBatch)
                break
            }
        }
    }
    
    // Delete a batch
    func deleteBatch(_ batchId: String) {
        // Remove from memory
        activeBatches.removeAll { $0.id == batchId }
        completedBatches.removeAll { $0.id == batchId }
        
        // Remove from disk
        let fileURL = batchesDirectory.appendingPathComponent("\(batchId).json")
        try? fileManager.removeItem(at: fileURL)
    }
    
    // Generate standard dimensions for common platforms
    static func getStandardDimensions() -> [(name: String, width: CGFloat, height: CGFloat)] {
        return [
            ("Facebook Feed", 1200, 630),
            ("Instagram Post", 1080, 1080),
            ("Instagram Story", 1080, 1920),
            ("Twitter Post", 1200, 675),
            ("LinkedIn Post", 1200, 627),
            ("Pinterest Pin", 1000, 1500),
            ("YouTube Thumbnail", 1280, 720),
            ("Banner Ad - Medium Rectangle", 300, 250),
            ("Banner Ad - Leaderboard", 728, 90),
            ("Banner Ad - Skyscraper", 160, 600)
        ]
    }
} 