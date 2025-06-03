import Foundation
import AppKit

@MainActor
class FileAccessManager {
    static let shared = FileAccessManager()
    
    private init() {}
    
    // Keys for UserDefaults
    private let originalsBookmarkKey = "originalsBookmark"
    private let picturesBookmarkKey = "picturesBookmark"
    private let destinationBookmarkKey = "destinationBookmark"
    
    // Helper to get or request access and store bookmark
    private func getOrRequestAccess(for url: URL, bookmarkKey: String) -> Bool {
        // Try to load bookmark from UserDefaults
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                if isStale {
                    UserDefaults.standard.removeObject(forKey: bookmarkKey)
                } else if resolvedURL.startAccessingSecurityScopedResource() {
                    resolvedURL.stopAccessingSecurityScopedResource()
                    return true
                }
            } catch {
                UserDefaults.standard.removeObject(forKey: bookmarkKey)
            }
        }
        // Request access via open panel on main thread
        var accessGranted = false
        if Thread.isMainThread {
            accessGranted = presentOpenPanel(for: url, bookmarkKey: bookmarkKey)
        } else {
            DispatchQueue.main.sync {
                accessGranted = presentOpenPanel(for: url, bookmarkKey: bookmarkKey)
            }
        }
        return accessGranted
    }
    
    private func presentOpenPanel(for url: URL, bookmarkKey: String) -> Bool {
        let openPanel = NSOpenPanel()
        openPanel.message = "Please grant access to \(url.path)"
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = url
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            if selectedURL.path.lowercased() == url.path.lowercased() {
                do {
                    let bookmark = try selectedURL.bookmarkData(options: .withSecurityScope, includingResourceValuesForKeys: nil, relativeTo: nil)
                    UserDefaults.standard.set(bookmark, forKey: bookmarkKey)
                    return true
                } catch {
                    return false
                }
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
        let originalsAccess = getOrRequestAccess(for: originalsURL, bookmarkKey: originalsBookmarkKey)
        let picturesAccess = getOrRequestAccess(for: picturesURL, bookmarkKey: picturesBookmarkKey)
        let destAccess = getOrRequestAccess(for: destinationURL, bookmarkKey: destinationBookmarkKey)
        
        return originalsAccess && picturesAccess && destAccess
    }
    
    // Helper to get the resolved destination URL with security scope
    func resolvedDestinationURL() -> URL? {
        if let bookmarkData = UserDefaults.standard.data(forKey: destinationBookmarkKey) {
            var isStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                return resolvedURL
            } catch {
                return nil
            }
        }
        return nil
    }
    
    func resetAllBookmarks() {
        UserDefaults.standard.removeObject(forKey: originalsBookmarkKey)
        UserDefaults.standard.removeObject(forKey: picturesBookmarkKey)
        UserDefaults.standard.removeObject(forKey: destinationBookmarkKey)
    }
} 