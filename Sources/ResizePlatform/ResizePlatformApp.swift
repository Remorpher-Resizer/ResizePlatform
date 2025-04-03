import SwiftUI

@main
struct ResizePlatformApp: App {
    @StateObject private var projectManager = ProjectManager()
    @AppStorage("didLoadDemoData") private var didLoadDemoData = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(projectManager)
                .onAppear {
                    // Load demo data on first launch
                    if !didLoadDemoData {
                        projectManager.createDemoData()
                        didLoadDemoData = true
                    }
                }
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .windowToolbarStyle(UnifiedCompactWindowToolbarStyle())
    }
}

struct ContentView: View {
    @State private var selectedTab = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            // Dashboard
            NavigationStack {
                Text("Dashboard")
                    .navigationTitle("Dashboard")
            }
            .tabItem {
                Label("Dashboard", systemImage: "chart.bar")
            }
            .tag(0)
            
            // Projects
            ProjectsView()
                .tabItem {
                    Label("Projects", systemImage: "folder")
                }
                .tag(1)
            
            // Assets
            NavigationStack {
                Text("Assets")
                    .navigationTitle("Assets")
            }
            .tabItem {
                Label("Assets", systemImage: "photo.on.rectangle")
            }
            .tag(2)
            
            // Analytics
            NavigationStack {
                Text("Analytics")
                    .navigationTitle("Analytics")
            }
            .tabItem {
                Label("Analytics", systemImage: "chart.xyaxis.line")
            }
            .tag(3)
            
            // Settings
            NavigationStack {
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(4)
        }
    }
} 