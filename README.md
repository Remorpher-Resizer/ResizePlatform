# Resize Platform

A macOS application for resizing images with a clean and intuitive user interface.

## Features

- Drag and drop image loading
- Manual file selection
- Width and height adjustment
- Aspect ratio preservation
- High-quality resizing
- Export to PNG format

## Requirements

- macOS 11.0 or later
- Xcode 13.0 or later
- Swift 5.5 or later

## Building the App

There are two ways to build and run this app:

### Option 1: Using Xcode (Recommended)

1. Create a new macOS App project in Xcode
   - Open Xcode
   - Select "File > New > Project"
   - Choose "macOS > App"
   - Name it "ResizePlatform" and set a location

2. Replace the generated files with our source files:
   - Replace the default ContentView.swift with our ContentView.swift
   - Replace the generated App file with our ResizePlatformApp.swift

3. Make sure to set the deployment target to macOS 11.0 or later

4. Build and run the project in Xcode

### Option 2: Fix Swift Package Manager Issues

If you're experiencing Swift toolchain compatibility issues:

1. Make sure you have the latest version of Xcode installed
2. Use Xcode's built-in Swift toolchain:
   ```
   sudo xcode-select --switch /Applications/Xcode.app
   ```
3. Then build and run:
   ```
   swift build
   swift run
   ```

## Usage

1. Launch the application
2. Click "Select Image" or drag and drop an image into the app
3. Enter your desired width and/or height (maintaining aspect ratio is enabled by default)
4. Click "Resize" to perform the resize operation
5. Click "Save" to export the resized image

## License

MIT 