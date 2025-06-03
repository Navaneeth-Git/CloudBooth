import Foundation
import AppKit

@MainActor
class FileAccessManager {
    static let shared = FileAccessManager()
    
    private init() {}
    
    func requestAccessPermission(to url: URL) -> Bool {
        // Check if we already have access
        if url.startAccessingSecurityScopedResource() {
            url.stopAccessingSecurityScopedResource()
            return true
        }
        
        // Request access via open panel
        let openPanel = NSOpenPanel()
        openPanel.message = "Please grant access to \(url.path)"
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = url
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            // Check if we got access to the correct directory
            if selectedURL.path.lowercased() == url.path.lowercased() {
                return true
            }
        }
        
        return false
    }
    
    func ensureDirectoryAccess() async -> Bool {
        // Simulate an async operation by adding a small delay
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 second
        
        // Source directories
        let originalsPath = "/Users/navaneeth/Pictures/Photo Booth Library/Originals"
        let originalsURL = URL(fileURLWithPath: originalsPath)
        
        let picturesPath = "/Users/navaneeth/Pictures/Photo Booth Library/Pictures"
        let picturesURL = URL(fileURLWithPath: picturesPath)
        
        // Destination directory
        let destinationBase = "/Users/navaneeth/Library/Mobile Documents/com~apple~CloudDocs"
        let destinationURL = URL(fileURLWithPath: destinationBase)
        
        // Request access to all directories
        let originalsAccess = requestAccessPermission(to: originalsURL)
        let picturesAccess = requestAccessPermission(to: picturesURL)
        let destAccess = requestAccessPermission(to: destinationURL)
        
        return originalsAccess && picturesAccess && destAccess
    }
} 