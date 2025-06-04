import Foundation
import AppKit

@MainActor
class FileAccessManager {
    static let shared = FileAccessManager()
    
    private init() {}
    
    // Get the path to the user's Photo Booth library
    func photoBooth(subFolder: String? = nil) -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        let photoBooth = homeDirectory.appendingPathComponent("Pictures/Photo Booth Library")
        
        if let subFolder = subFolder {
            return photoBooth.appendingPathComponent(subFolder)
        }
        
        return photoBooth
    }
    
    // Get the path to the user's iCloud Drive
    func iCloudDrive() -> URL {
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
    }
    
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
        let originalsURL = photoBooth(subFolder: "Originals")
        let picturesURL = photoBooth(subFolder: "Pictures")
        
        // Destination directory
        let destinationURL = iCloudDrive()
        
        // Request access to all directories
        let originalsAccess = requestAccessPermission(to: originalsURL)
        let picturesAccess = requestAccessPermission(to: picturesURL)
        let destAccess = requestAccessPermission(to: destinationURL)
        
        return originalsAccess && picturesAccess && destAccess
    }
    
    // Helper to get the resolved destination URL
    func resolvedDestinationURL() -> URL? {
        let destinationURL = iCloudDrive()
        return destinationURL
    }
    
    // Reset bookmarks when permissions need to be requested again
    func resetAllBookmarks() {
        // Nothing to reset for now - will be implemented if bookmarks are used in the future
    }
} 