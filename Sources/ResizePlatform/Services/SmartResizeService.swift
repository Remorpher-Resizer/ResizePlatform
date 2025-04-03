import Foundation
import SwiftUI

class SmartResizeService {
    
    // Main function to resize a design to target dimensions
    func resizeDesign(design: Design, targetWidth: CGFloat, targetHeight: CGFloat) -> Design {
        // Create a new design with updated dimensions
        var newDesign = design
        newDesign.id = UUID().uuidString
        
        // Calculate scale factors
        let widthScale = targetWidth / design.width
        let heightScale = targetHeight / design.height
        
        // Create transformed elements
        var newElements: [DesignElement] = []
        
        // Track groups to process them together
        var groups: [String: [DesignElement]] = [:]
        
        // First pass: collect groups
        for element in design.elements {
            if let groupId = element.groupId {
                if groups[groupId] == nil {
                    groups[groupId] = []
                }
                groups[groupId]?.append(element)
            }
        }
        
        // Second pass: process elements
        for element in design.elements {
            if element.groupId == nil {
                let newElement = transformElement(
                    element: element,
                    originalWidth: design.width,
                    originalHeight: design.height,
                    targetWidth: targetWidth,
                    targetHeight: targetHeight,
                    widthScale: widthScale,
                    heightScale: heightScale
                )
                newElements.append(newElement)
            }
        }
        
        // Third pass: process groups
        for (groupId, groupElements) in groups {
            // Find group bounds
            let groupBounds = calculateGroupBounds(elements: groupElements)
            
            // Transform the group as a whole
            let transformedElements = transformGroupElements(
                elements: groupElements,
                groupBounds: groupBounds,
                originalWidth: design.width,
                originalHeight: design.height,
                targetWidth: targetWidth,
                targetHeight: targetHeight,
                widthScale: widthScale,
                heightScale: heightScale
            )
            
            newElements.append(contentsOf: transformedElements)
        }
        
        // Update design with new elements
        newDesign.width = targetWidth
        newDesign.height = targetHeight
        newDesign.elements = newElements
        newDesign.updatedAt = Date()
        
        return newDesign
    }
    
    // Transform a single element based on its properties and constraints
    private func transformElement(
        element: DesignElement, 
        originalWidth: CGFloat, 
        originalHeight: CGFloat,
        targetWidth: CGFloat, 
        targetHeight: CGFloat,
        widthScale: CGFloat, 
        heightScale: CGFloat
    ) -> DesignElement {
        var newElement = element
        
        // Determine scaling approach based on element importance and type
        let scale: CGFloat
        
        switch element.importance {
        case .critical, .high:
            // Critical elements use the minimum scale to ensure visibility
            scale = min(widthScale, heightScale)
        case .medium:
            // Medium importance elements use average scale
            scale = (widthScale + heightScale) / 2
        case .low:
            // Low importance elements can use the maximum scale and be adjusted later
            scale = max(widthScale, heightScale)
        }
        
        // Handle position based on constraints
        if element.constraints.keepRelativePosition {
            // Maintain relative position within the design
            newElement.x = element.x * widthScale
            newElement.y = element.y * heightScale
        } else {
            // Apply proportional scaling
            newElement.x = element.x * widthScale
            newElement.y = element.y * heightScale
            
            // Apply margins if specified
            if let marginLeft = element.constraints.marginLeft {
                newElement.x = marginLeft
            }
            if let marginTop = element.constraints.marginTop {
                newElement.y = marginTop
            }
            if let marginRight = element.constraints.marginRight {
                newElement.x = targetWidth - element.width * scale - marginRight
            }
            if let marginBottom = element.constraints.marginBottom {
                newElement.y = targetHeight - element.height * scale - marginBottom
            }
        }
        
        // Handle size based on type and constraints
        switch element.type {
        case .text:
            handleTextResize(element: &newElement, scale: scale, targetWidth: targetWidth)
        case .logo:
            handleLogoResize(element: &newElement, scale: min(widthScale, heightScale))
        default:
            // Default resizing handling
            handleDefaultResize(element: &newElement, scale: scale)
        }
        
        // Apply constraints for min/max dimensions
        applyDimensionConstraints(element: &newElement)
        
        return newElement
    }
    
    // Handle text element resizing (special case)
    private func handleTextResize(element: inout DesignElement, scale: CGFloat, targetWidth: CGFloat) {
        if element.constraints.lockAspectRatio {
            element.width *= scale
            element.height *= scale
            if let fontSize = element.fontSize {
                element.fontSize = fontSize * scale
            }
        } else {
            // Allow text to reflow
            let newWidth = min(element.width * scale, targetWidth * 0.9)
            element.width = newWidth
            
            // Calculate approximate new height based on text size and width
            if let fontSize = element.fontSize {
                let newFontSize = max(fontSize * scale, 9) // Ensure text remains readable
                element.fontSize = newFontSize
                
                // Rough estimate of height based on text content and width
                if let content = element.content {
                    let textHeight = estimateTextHeight(text: content, fontSize: newFontSize, width: newWidth)
                    element.height = textHeight
                } else {
                    element.height *= scale
                }
            } else {
                element.height *= scale
            }
        }
    }
    
    // Handle logo resizing (preserve visibility)
    private func handleLogoResize(element: inout DesignElement, scale: CGFloat) {
        // Logos should maintain their aspect ratio and have a minimum visible size
        let minLogoSize: CGFloat = 32
        
        if element.constraints.lockAspectRatio {
            let aspectRatio = element.width / element.height
            
            let newWidth = max(element.width * scale, minLogoSize)
            let newHeight = newWidth / aspectRatio
            
            element.width = newWidth
            element.height = newHeight
        } else {
            element.width = max(element.width * scale, minLogoSize)
            element.height = max(element.height * scale, minLogoSize)
        }
    }
    
    // Handle default element resizing
    private func handleDefaultResize(element: inout DesignElement, scale: CGFloat) {
        if element.constraints.lockAspectRatio {
            let aspectRatio = element.width / element.height
            element.width *= scale
            element.height = element.width / aspectRatio
        } else {
            element.width *= scale
            element.height *= scale
        }
    }
    
    // Apply min/max dimension constraints
    private func applyDimensionConstraints(element: inout DesignElement) {
        if let minWidth = element.constraints.minWidth {
            element.width = max(element.width, minWidth)
        }
        
        if let minHeight = element.constraints.minHeight {
            element.height = max(element.height, minHeight)
        }
        
        if let maxWidth = element.constraints.maxWidth {
            element.width = min(element.width, maxWidth)
        }
        
        if let maxHeight = element.constraints.maxHeight {
            element.height = min(element.height, maxHeight)
        }
    }
    
    // Calculate bounds for a group of elements
    private func calculateGroupBounds(elements: [DesignElement]) -> CGRect {
        guard !elements.isEmpty else { return .zero }
        
        var minX = CGFloat.greatestFiniteMagnitude
        var minY = CGFloat.greatestFiniteMagnitude
        var maxX = CGFloat.leastNormalMagnitude
        var maxY = CGFloat.leastNormalMagnitude
        
        for element in elements {
            minX = min(minX, element.x)
            minY = min(minY, element.y)
            maxX = max(maxX, element.x + element.width)
            maxY = max(maxY, element.y + element.height)
        }
        
        return CGRect(x: minX, y: minY, width: maxX - minX, height: maxY - minY)
    }
    
    // Transform elements within a group
    private func transformGroupElements(
        elements: [DesignElement],
        groupBounds: CGRect,
        originalWidth: CGFloat,
        originalHeight: CGFloat,
        targetWidth: CGFloat,
        targetHeight: CGFloat,
        widthScale: CGFloat,
        heightScale: CGFloat
    ) -> [DesignElement] {
        // Determine group scaling factor
        let groupWidthScale = targetWidth / originalWidth
        let groupHeightScale = targetHeight / originalHeight
        let groupScale = min(groupWidthScale, groupHeightScale)
        
        var transformedElements: [DesignElement] = []
        
        // New group bounds
        let newGroupX = groupBounds.origin.x * widthScale
        let newGroupY = groupBounds.origin.y * heightScale
        let newGroupWidth = groupBounds.width * groupScale
        let newGroupHeight = groupBounds.height * groupScale
        
        for element in elements {
            var newElement = element
            
            // Calculate relative position within the group
            let relativeX = (element.x - groupBounds.origin.x) / groupBounds.width
            let relativeY = (element.y - groupBounds.origin.y) / groupBounds.height
            let relativeWidth = element.width / groupBounds.width
            let relativeHeight = element.height / groupBounds.height
            
            // Maintain relative positioning within the transformed group
            newElement.x = newGroupX + relativeX * newGroupWidth
            newElement.y = newGroupY + relativeY * newGroupHeight
            newElement.width = relativeWidth * newGroupWidth
            newElement.height = relativeHeight * newGroupHeight
            
            // Scale text properties proportionally
            if element.type == .text, let fontSize = element.fontSize {
                newElement.fontSize = fontSize * groupScale
            }
            
            transformedElements.append(newElement)
        }
        
        return transformedElements
    }
    
    // Estimate text height based on content and font size
    private func estimateTextHeight(text: String, fontSize: CGFloat, width: CGFloat) -> CGFloat {
        let estimatedCharsPerLine = Int(width / (fontSize * 0.6))
        if estimatedCharsPerLine <= 0 {
            return fontSize * 1.5 // Fallback
        }
        
        let numberOfLines = ceil(Double(text.count) / Double(estimatedCharsPerLine))
        return CGFloat(numberOfLines) * fontSize * 1.5 // 1.5 for line spacing
    }
} 