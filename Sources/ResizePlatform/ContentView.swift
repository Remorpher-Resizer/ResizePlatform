import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @State private var imageData: Data? = nil
    @State private var originalImage: NSImage? = nil
    @State private var resizedImage: NSImage? = nil
    @State private var width: String = ""
    @State private var height: String = ""
    @State private var isResizing: Bool = false
    @State private var maintainAspectRatio: Bool = true
    @State private var showingSavePanel = false
    @State private var errorMessage: String? = nil
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Resize Platform")
                .font(.largeTitle)
                .padding(.top)
            
            if let image = resizedImage ?? originalImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: 500, maxHeight: 300)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(8)
            } else {
                ZStack {
                    Rectangle()
                        .fill(Color.gray.opacity(0.1))
                        .frame(width: 500, height: 300)
                        .cornerRadius(8)
                    
                    Text("Drop image here or click to select")
                        .foregroundColor(.secondary)
                }
                .onTapGesture {
                    openImagePicker()
                }
            }
            
            HStack(spacing: 20) {
                Button("Select Image") {
                    openImagePicker()
                }
                .disabled(isResizing)
                
                if originalImage != nil {
                    Button("Reset") {
                        resizedImage = nil
                        width = ""
                        height = ""
                        errorMessage = nil
                    }
                    .disabled(isResizing || resizedImage == nil)
                    
                    Button("Save") {
                        showingSavePanel = true
                    }
                    .disabled(isResizing || resizedImage == nil)
                }
            }
            .padding(.horizontal)
            
            if originalImage != nil {
                VStack(spacing: 15) {
                    Toggle("Maintain Aspect Ratio", isOn: $maintainAspectRatio)
                        .frame(width: 300)
                    
                    HStack {
                        Text("Width:")
                        TextField("Width", text: $width)
                            .frame(width: 100)
                        
                        Text("Height:")
                        TextField("Height", text: $height)
                            .frame(width: 100)
                        
                        Button("Resize") {
                            resizeImage()
                        }
                        .disabled(isResizing || width.isEmpty && height.isEmpty)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(8)
                .padding(.horizontal)
            }
            
            if let errorMessage = errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
        .padding()
        .frame(minWidth: 600, minHeight: 500)
        .onDrop(of: [UTType.image.identifier], isTargeted: nil) { providers -> Bool
            providers.first?.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                guard let data = data, let image = NSImage(data: data) else { return }
                DispatchQueue.main.async {
                    self.originalImage = image
                    self.imageData = data
                    self.resizedImage = nil
                    self.errorMessage = nil
                    
                    if let imageRep = image.representations.first as? NSBitmapImageRep {
                        self.width = "\(imageRep.pixelsWide)"
                        self.height = "\(imageRep.pixelsHigh)"
                    }
                }
            }
            return true
        }
        .fileExporter(
            isPresented: $showingSavePanel,
            document: resizedImage != nil ? ImageDocument(image: resizedImage!) : nil,
            contentType: .png,
            defaultFilename: "resized_image"
        ) { result in
            switch result {
            case .success(_):
                print("Successfully saved image")
            case .failure(let error):
                self.errorMessage = "Error saving: \(error.localizedDescription)"
            }
        }
    }
    
    private func openImagePicker() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [UTType.image]
        panel.allowsMultipleSelection = false
        
        panel.begin { response in
            if response == .OK, let url = panel.url, let image = NSImage(contentsOf: url) {
                imageData = try? Data(contentsOf: url)
                originalImage = image
                resizedImage = nil
                errorMessage = nil
                
                if let imageRep = image.representations.first as? NSBitmapImageRep {
                    width = "\(imageRep.pixelsWide)"
                    height = "\(imageRep.pixelsHigh)"
                }
            }
        }
    }
    
    private func resizeImage() {
        guard let originalImage = originalImage else { return }
        
        let targetWidth = Int(width) ?? 0
        let targetHeight = Int(height) ?? 0
        
        if targetWidth <= 0 && targetHeight <= 0 {
            errorMessage = "Please enter valid dimensions"
            return
        }
        
        isResizing = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            var resizeWidth = targetWidth
            var resizeHeight = targetHeight
            
            if maintainAspectRatio {
                if let imageRep = originalImage.representations.first as? NSBitmapImageRep {
                    let originalWidth = imageRep.pixelsWide
                    let originalHeight = imageRep.pixelsHigh
                    let aspectRatio = Double(originalWidth) / Double(originalHeight)
                    
                    if targetWidth > 0 && targetHeight <= 0 {
                        resizeHeight = Int(Double(targetWidth) / aspectRatio)
                    } else if targetHeight > 0 && targetWidth <= 0 {
                        resizeWidth = Int(Double(targetHeight) * aspectRatio)
                    } else {
                        // Both dimensions provided, maintain aspect ratio based on the smallest scale
                        let widthScale = Double(targetWidth) / Double(originalWidth)
                        let heightScale = Double(targetHeight) / Double(originalHeight)
                        let scale = min(widthScale, heightScale)
                        
                        resizeWidth = Int(Double(originalWidth) * scale)
                        resizeHeight = Int(Double(originalHeight) * scale)
                    }
                }
            }
            
            if resizeWidth <= 0 {
                resizeWidth = 1
            }
            
            if resizeHeight <= 0 {
                resizeHeight = 1
            }
            
            // Perform the resize
            let resized = NSImage(size: NSSize(width: resizeWidth, height: resizeHeight))
            
            resized.lockFocus()
            NSGraphicsContext.current?.imageInterpolation = .high
            originalImage.draw(in: NSRect(x: 0, y: 0, width: resizeWidth, height: resizeHeight),
                              from: NSRect(x: 0, y: 0, width: originalImage.size.width, height: originalImage.size.height),
                              operation: .copy, fraction: 1.0)
            resized.unlockFocus()
            
            DispatchQueue.main.async {
                self.resizedImage = resized
                self.width = "\(resizeWidth)"
                self.height = "\(resizeHeight)"
                self.isResizing = false
                self.errorMessage = nil
            }
        }
    }
}

struct ImageDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.png, .jpeg] }

    var image: NSImage

    init(image: NSImage) {
        self.image = image
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let image = NSImage(data: data)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.image = image
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let tiffData = image.tiffRepresentation!
        let bitmapImage = NSBitmapImageRep(data: tiffData)!
        let pngData = bitmapImage.representation(using: .png, properties: [:])!
        return .init(regularFileWithContents: pngData)
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
    }
} 