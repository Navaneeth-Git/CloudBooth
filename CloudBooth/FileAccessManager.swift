import Foundation
import AppKit

@MainActor
class FileAccessManager {
    static let shared = FileAccessManager()
    
    // Keys for storing security-scoped bookmarks in UserDefaults
    let originalsBookmarkKey = "originalsBookmark"
    let picturesBookmarkKey = "picturesBookmark" 
    let iCloudBookmarkKey = "iCloudBookmark"
    
    // Track which folders exist
    @Published var originalsExists = false
    @Published var picturesExists = false
    
    private init() {}
    
    // Get the real home directory (not container path)
    func getRealHomeDirectory() -> String {
        // Get the actual username from process info
        let currentUser = NSUserName()
        return "/Users/\(currentUser)"
    }
    
    // Get iCloud Drive path
    func getICloudDirectory() -> String {
        return "\(getRealHomeDirectory())/Library/Mobile Documents/com~apple~CloudDocs"
    }
    
    // Request access and save a security-scoped bookmark
    func requestAccessPermission(to url: URL, bookmarkKey: String) -> Bool {
        // First check if the directory exists
        var isDirectory: ObjCBool = false
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            // Directory doesn't exist
            return false
        }
        
        // Check if we have a saved bookmark
        if let bookmarkData = UserDefaults.standard.data(forKey: bookmarkKey) {
            var isStale = false
            do {
                let resolvedURL = try URL(resolvingBookmarkData: bookmarkData,
                                          options: .withSecurityScope,
                                          relativeTo: nil,
                                          bookmarkDataIsStale: &isStale)
                
                if resolvedURL.startAccessingSecurityScopedResource() {
                    // Stop accessing for now (we'll start again when needed)
                    resolvedURL.stopAccessingSecurityScopedResource()
                    
                    // If the bookmark is stale but we still got access, update it
                    if isStale {
                        saveSecurityScopedBookmark(for: resolvedURL, key: bookmarkKey)
                    }
                    
                    return true
                }
            } catch {
                print("Error resolving bookmark for \(url.path): \(error)")
                // Continue to request access again
            }
        }
        
        // Request access via open panel
        let openPanel = NSOpenPanel()
        openPanel.message = "Please select the \(url.lastPathComponent) folder to grant access"
        openPanel.prompt = "Grant Access"
        
        // Navigate to the parent directory instead to make selection easier
        let parentURL = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parentURL.path) {
            openPanel.directoryURL = parentURL
        } else {
            // If parent doesn't exist, try to navigate to the Pictures folder
            let homeDir = getRealHomeDirectory()
            let picturesDir = URL(fileURLWithPath: "\(homeDir)/Pictures")
            if FileManager.default.fileExists(atPath: picturesDir.path) {
                openPanel.directoryURL = picturesDir
            }
        }
        
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.showsHiddenFiles = false
        openPanel.canCreateDirectories = false
        openPanel.treatsFilePackagesAsDirectories = true // Important for Photo Booth Library
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            // Check if the selected directory matches what we expect
            print("Selected URL: \(selectedURL.path)")
            print("Target URL: \(url.path)")
            
            // If user selected a parent directory, try to resolve to target directory
            var targetURL = selectedURL
            if selectedURL.lastPathComponent != url.lastPathComponent {
                // Check if they selected a parent directory
                let potentialTargetURL = selectedURL.appendingPathComponent(url.lastPathComponent)
                if FileManager.default.fileExists(atPath: potentialTargetURL.path) {
                    targetURL = potentialTargetURL
                    print("Resolved to target subdirectory: \(targetURL.path)")
                }
            }
            
            // Save the security-scoped bookmark
            return saveSecurityScopedBookmark(for: targetURL, key: bookmarkKey)
        }
        
        return false
    }
    
    // Save a security-scoped bookmark
    private func saveSecurityScopedBookmark(for url: URL, key: String) -> Bool {
        do {
            let bookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                  includingResourceValuesForKeys: nil,
                                                  relativeTo: nil)
            UserDefaults.standard.set(bookmarkData, forKey: key)
            return true
        } catch {
            print("Failed to create security-scoped bookmark for \(url.path): \(error)")
            return false
        }
    }
    
    // Access a URL using a stored bookmark - with better error handling and persistence
    func accessURLWithBookmark(_ key: String) -> URL? {
        guard let bookmarkData = UserDefaults.standard.data(forKey: key) else {
            print("No bookmark data found for key: \(key)")
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale)
            
            if isStale {
                print("Bookmark is stale for \(key), attempting to refresh")
                // Try to refresh the bookmark
                if url.startAccessingSecurityScopedResource() {
                    do {
                        let newBookmarkData = try url.bookmarkData(options: .withSecurityScope,
                                                              includingResourceValuesForKeys: nil,
                                                              relativeTo: nil)
                        UserDefaults.standard.set(newBookmarkData, forKey: key)
                        print("Successfully refreshed bookmark for \(key)")
                    } catch {
                        print("Failed to refresh bookmark: \(error)")
                    }
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            // Try again with the potentially refreshed bookmark
            if url.startAccessingSecurityScopedResource() {
                print("Successfully accessed URL for key: \(key), path: \(url.path)")
                return url
            } else {
                print("Failed to access resource with bookmark: \(key)")
            }
        } catch {
            print("Failed to resolve bookmark for key \(key): \(error)")
        }
        
        return nil
    }
    
    // Stop accessing a URL
    func stopAccessingURL(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
    
    // Check if a directory exists
    private func directoryExists(at path: String) -> Bool {
        var isDirectory: ObjCBool = false
        let exists = FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory)
        return exists && isDirectory.boolValue
    }
    
    // Simple direct method to show file selection dialog and get permission
    func directlyRequestAccess(to path: String, message: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        
        if !FileManager.default.fileExists(atPath: path) {
            print("Path does not exist: \(path)")
            return false
        }
        
        let openPanel = NSOpenPanel()
        openPanel.message = message
        openPanel.prompt = "Grant Access"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.showsHiddenFiles = false
        
        // Special handling for Photo Booth Library which is a package
        if path.contains("Photo Booth Library") {
            openPanel.treatsFilePackagesAsDirectories = true
        }
        
        // Navigate to the parent directory
        let parentURL = url.deletingLastPathComponent()
        if FileManager.default.fileExists(atPath: parentURL.path) {
            openPanel.directoryURL = parentURL
        } else {
            // Fallback to home directory
            openPanel.directoryURL = URL(fileURLWithPath: getRealHomeDirectory())
        }
        
        // Debug info
        print("Requesting access to: \(path)")
        print("Setting initial directory to: \(openPanel.directoryURL?.path ?? "unknown")")
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            print("Selected URL: \(selectedURL.path)")
            
            // Try to save a security-scoped bookmark for future use
            do {
                let bookmarkKey = "bookmark_\(url.lastPathComponent)"
                let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope,
                                                             includingResourceValuesForKeys: nil,
                                                             relativeTo: nil)
                UserDefaults.standard.set(bookmarkData, forKey: bookmarkKey)
                
                // Also save to the specific bookmark key for this folder type
                if path.contains("Originals") {
                    UserDefaults.standard.set(bookmarkData, forKey: originalsBookmarkKey)
                } else if path.contains("Pictures") && path.contains("Photo Booth") {
                    UserDefaults.standard.set(bookmarkData, forKey: picturesBookmarkKey)
                } else if path.contains("iCloud") || path.contains("CloudDocs") {
                    UserDefaults.standard.set(bookmarkData, forKey: iCloudBookmarkKey)
                }
                
                return true
            } catch {
                print("Failed to save bookmark: \(error)")
                return false
            }
        }
        
        return false
    }
    
    // Force permission request for all paths - more direct approach
    func forceRequestPermissions() async -> Bool {
        print("Starting force request permissions")
        
        // Get the correct Photo Booth paths first
        let (originalsPath, picturesPath) = getCorrectPhotoBooth()
        
        // Check which folders actually exist
        originalsExists = directoryExists(at: originalsPath)
        picturesExists = directoryExists(at: picturesPath)
        
        // Check for Pictures folder first
        let homeDir = getRealHomeDirectory()
        let picturesDirPath = "\(homeDir)/Pictures"
        
        // Check if we already have bookmarks
        let hasOriginalsBookmark = UserDefaults.standard.data(forKey: originalsBookmarkKey) != nil
        let hasPicturesBookmark = UserDefaults.standard.data(forKey: picturesBookmarkKey) != nil
        let hasICloudBookmark = UserDefaults.standard.data(forKey: iCloudBookmarkKey) != nil
        
        print("Existing bookmarks check - Originals: \(hasOriginalsBookmark), Pictures: \(hasPicturesBookmark), iCloud: \(hasICloudBookmark)")
        
        // If we have all necessary bookmarks and they work, don't request again
        if (originalsExists && hasOriginalsBookmark || picturesExists && hasPicturesBookmark) && hasICloudBookmark {
            let canAccessOriginals = originalsExists ? accessOriginalsDirectory() != nil : true
            let canAccessPictures = picturesExists ? accessPicturesDirectory() != nil : true
            let canAccessICloud = accessICloudDirectory() != nil
            
            print("Testing bookmark access - Originals: \(canAccessOriginals), Pictures: \(canAccessPictures), iCloud: \(canAccessICloud)")
            
            if (canAccessOriginals || canAccessPictures) && canAccessICloud {
                print("Successfully accessed directories with existing bookmarks")
                return true
            }
        }
        
        // If we got here, we need to request permissions
        print("Need to request new permissions")
        
        // First, request access to Pictures folder
        if !directlyRequestAccess(to: picturesDirPath, message: "Please select your Pictures folder") {
            print("Could not get access to Pictures folder")
            return false
        }
        
        // Check for Photo Booth Library folder
        let photoBoothLibPath = "\(picturesDirPath)/Photo Booth Library"
        if directoryExists(at: photoBoothLibPath) {
            _ = directlyRequestAccess(to: photoBoothLibPath, message: "Please select the Photo Booth Library folder")
        }
        
        // Check for alternative Photo Booth folder
        let altPhotoBoothPath = "\(picturesDirPath)/Photo Booth" 
        if directoryExists(at: altPhotoBoothPath) {
            _ = directlyRequestAccess(to: altPhotoBoothPath, message: "Please select the Photo Booth folder")
        }
        
        var hasSourceFolder = false
        
        // Now request access to the actual source folders if they exist
        if originalsExists {
            print("Requesting access to Originals folder: \(originalsPath)")
            hasSourceFolder = true
            let originalsAccess = directlyRequestAccess(to: originalsPath, message: "Please select the Originals folder")
            
            // Explicitly save bookmark for originals
            if originalsAccess {
                let originalsURL = URL(fileURLWithPath: originalsPath)
                if originalsURL.startAccessingSecurityScopedResource() {
                    do {
                        let bookmarkData = try originalsURL.bookmarkData(options: .withSecurityScope,
                                                                     includingResourceValuesForKeys: nil,
                                                                     relativeTo: nil)
                        UserDefaults.standard.set(bookmarkData, forKey: originalsBookmarkKey)
                        print("Successfully saved originals bookmark")
                        originalsURL.stopAccessingSecurityScopedResource()
                    } catch {
                        print("Failed to save originals bookmark: \(error)")
                    }
                }
            }
        }
        
        if picturesExists {
            print("Requesting access to Pictures folder: \(picturesPath)")
            hasSourceFolder = true
            let picturesAccess = directlyRequestAccess(to: picturesPath, message: "Please select the Pictures folder")
            
            // Explicitly save bookmark for pictures
            if picturesAccess {
                let picturesURL = URL(fileURLWithPath: picturesPath)
                if picturesURL.startAccessingSecurityScopedResource() {
                    do {
                        let bookmarkData = try picturesURL.bookmarkData(options: .withSecurityScope,
                                                                    includingResourceValuesForKeys: nil,
                                                                    relativeTo: nil)
                        UserDefaults.standard.set(bookmarkData, forKey: picturesBookmarkKey)
                        print("Successfully saved pictures bookmark")
                        picturesURL.stopAccessingSecurityScopedResource()
                    } catch {
                        print("Failed to save pictures bookmark: \(error)")
                    }
                }
            }
        }
        
        // Get iCloud access
        let iCloudPath = getICloudDirectory()
        let iCloudAccess = directlyRequestAccess(to: iCloudPath, message: "Please select your iCloud Drive folder")
        
        // Explicitly save bookmark for iCloud
        if iCloudAccess {
            let iCloudURL = URL(fileURLWithPath: iCloudPath)
            if iCloudURL.startAccessingSecurityScopedResource() {
                do {
                    let bookmarkData = try iCloudURL.bookmarkData(options: .withSecurityScope,
                                                              includingResourceValuesForKeys: nil,
                                                              relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: iCloudBookmarkKey)
                    print("Successfully saved iCloud bookmark")
                    iCloudURL.stopAccessingSecurityScopedResource()
                } catch {
                    print("Failed to save iCloud bookmark: \(error)")
                }
            }
        }
        
        // Store the discovered paths in UserDefaults so we don't need to rediscover
        UserDefaults.standard.set(originalsPath, forKey: "discoveredOriginalsPath")
        UserDefaults.standard.set(picturesPath, forKey: "discoveredPicturesPath")
        UserDefaults.standard.set(iCloudPath, forKey: "discoveredICloudPath")
        
        // Check if we now have valid bookmarks
        let hasOriginalsBookmarkNow = UserDefaults.standard.data(forKey: originalsBookmarkKey) != nil
        let hasPicturesBookmarkNow = UserDefaults.standard.data(forKey: picturesBookmarkKey) != nil
        let hasICloudBookmarkNow = UserDefaults.standard.data(forKey: iCloudBookmarkKey) != nil
        
        print("Post-request bookmarks check - Originals: \(hasOriginalsBookmarkNow), Pictures: \(hasPicturesBookmarkNow), iCloud: \(hasICloudBookmarkNow)")
        
        return hasSourceFolder
    }

    // Get the actual correct paths for Photo Booth folders
    func getCorrectPhotoBooth() -> (originals: String, pictures: String) {
        let homeDir = getRealHomeDirectory()
        
        // Use exactly the paths specified by the user
        let originalsPath = "\(homeDir)/Pictures/Photo Booth Library/Originals"
        let picturesPath = "\(homeDir)/Pictures/Photo Booth Library/Pictures"
        
        // Verify paths exist
        let fileManager = FileManager.default
        let originalsExists = fileManager.fileExists(atPath: originalsPath)
        let picturesExists = fileManager.fileExists(atPath: picturesPath)
        
        print("Photo Booth paths - Originals exists: \(originalsExists), Pictures exists: \(picturesExists)")
        print("Originals path: \(originalsPath)")
        print("Pictures path: \(picturesPath)")
        
        return (originalsPath, picturesPath)
    }

    func ensureDirectoryAccess() async -> Bool {
        // Get the correct Photo Booth paths
        let (originalsPath, picturesPath) = getCorrectPhotoBooth()
        
        // Check which directories exist
        originalsExists = directoryExists(at: originalsPath)
        picturesExists = directoryExists(at: picturesPath)
        
        // If we already have valid bookmarks, don't request again
        let hasOriginalsBookmark = UserDefaults.standard.data(forKey: originalsBookmarkKey) != nil
        let hasPicturesBookmark = UserDefaults.standard.data(forKey: picturesBookmarkKey) != nil
        let hasICloudBookmark = UserDefaults.standard.data(forKey: iCloudBookmarkKey) != nil
        
        // First try to use existing bookmarks before requesting new ones
        if (originalsExists && hasOriginalsBookmark || picturesExists && hasPicturesBookmark) && hasICloudBookmark {
            // Try to access with existing bookmarks to verify they still work
            let canAccessOriginals = originalsExists ? accessURLWithBookmark(originalsBookmarkKey) != nil : true
            let canAccessPictures = picturesExists ? accessURLWithBookmark(picturesBookmarkKey) != nil : true
            let canAccessICloud = accessURLWithBookmark(iCloudBookmarkKey) != nil
            
            if (canAccessOriginals || canAccessPictures) && canAccessICloud {
                print("Successfully accessed directories with existing bookmarks")
                return true
            }
        }
        
        // Otherwise, we need to request permissions
        return await forceRequestPermissions()
    }
    
    // Helper method to get access to originals directory
    func accessOriginalsDirectory() -> URL? {
        // First check if the directory exists
        if !originalsExists {
            return nil
        }
        
        // Try to use the bookmark
        if let url = accessURLWithBookmark(originalsBookmarkKey) {
            print("Successfully accessed originals directory via bookmark")
            return url
        }
        
        // If bookmark access fails, try direct access
        let (originalsPath, _) = getCorrectPhotoBooth()
        let originalsURL = URL(fileURLWithPath: originalsPath)
        
        // If the file exists, try to create a new bookmark
        if FileManager.default.fileExists(atPath: originalsPath) {
            // Try to create a new bookmark for future use
            if originalsURL.startAccessingSecurityScopedResource() {
                do {
                    let bookmarkData = try originalsURL.bookmarkData(options: .withSecurityScope,
                                                                  includingResourceValuesForKeys: nil,
                                                                  relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: originalsBookmarkKey)
                    print("Created new originals bookmark for direct access")
                    return originalsURL
                } catch {
                    print("Failed to create originals bookmark: \(error)")
                    originalsURL.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        // If all else fails, return nil
        return nil
    }
    
    // Helper method to get access to pictures directory
    func accessPicturesDirectory() -> URL? {
        // First check if the directory exists
        if !picturesExists {
            return nil
        }
        
        // Try to use the bookmark
        if let url = accessURLWithBookmark(picturesBookmarkKey) {
            print("Successfully accessed pictures directory via bookmark")
            return url
        }
        
        // If bookmark access fails, try direct access
        let (_, picturesPath) = getCorrectPhotoBooth()
        let picturesURL = URL(fileURLWithPath: picturesPath)
        
        // If the file exists, try to create a new bookmark
        if FileManager.default.fileExists(atPath: picturesPath) {
            // Try to create a new bookmark for future use
            if picturesURL.startAccessingSecurityScopedResource() {
                do {
                    let bookmarkData = try picturesURL.bookmarkData(options: .withSecurityScope,
                                                                  includingResourceValuesForKeys: nil,
                                                                  relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: picturesBookmarkKey)
                    print("Created new pictures bookmark for direct access")
                    return picturesURL
                } catch {
                    print("Failed to create pictures bookmark: \(error)")
                    picturesURL.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        // If all else fails, return nil
        return nil
    }
    
    // Helper method to get access to iCloud directory
    func accessICloudDirectory() -> URL? {
        // Try to use the bookmark
        if let url = accessURLWithBookmark(iCloudBookmarkKey) {
            print("Successfully accessed iCloud directory via bookmark")
            return url
        }
        
        // If bookmark access fails, try direct access
        let iCloudPath = getICloudDirectory()
        let iCloudURL = URL(fileURLWithPath: iCloudPath)
        
        // If the file exists, try to create a new bookmark
        if FileManager.default.fileExists(atPath: iCloudPath) {
            // Try to create a new bookmark for future use
            if iCloudURL.startAccessingSecurityScopedResource() {
                do {
                    let bookmarkData = try iCloudURL.bookmarkData(options: .withSecurityScope,
                                                              includingResourceValuesForKeys: nil,
                                                              relativeTo: nil)
                    UserDefaults.standard.set(bookmarkData, forKey: iCloudBookmarkKey)
                    print("Created new iCloud bookmark for direct access")
                    return iCloudURL
                } catch {
                    print("Failed to create iCloud bookmark: \(error)")
                    iCloudURL.stopAccessingSecurityScopedResource()
                }
            }
        }
        
        // If all else fails, return nil
        return nil
    }
} 