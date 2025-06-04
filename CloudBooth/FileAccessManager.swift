import Foundation
import AppKit

@MainActor
class FileAccessManager {
    static let shared = FileAccessManager()
    
    // Keys for UserDefaults
    private let permissionsGrantedKey = "FileAccessPermissionsGranted"
    private let iCloudBookmarkKey = "iCloudBookmarkData"
    
    private init() {
        // Try to restore any saved bookmarks on init
        restoreSavedBookmarks()
    }
    
    // MARK: - Bookmark Management
    
    // Restore any saved security-scoped bookmarks
    private func restoreSavedBookmarks() {
        // Try to restore iCloud bookmark if available
        if let bookmarkData = UserDefaults.standard.data(forKey: iCloudBookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, 
                                  options: [.withSecurityScope], 
                                  relativeTo: nil, 
                                  bookmarkDataIsStale: &isStale)
                
                // If bookmark is stale, we'll need to request access again
                if isStale {
                    print("⚠️ iCloud bookmark is stale - will need to request access again")
                    UserDefaults.standard.removeObject(forKey: iCloudBookmarkKey)
                } else {
                    print("✅ Successfully restored iCloud bookmark to: \(url.path)")
                }
            } catch {
                print("❌ Failed to restore iCloud bookmark: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: iCloudBookmarkKey)
            }
        }
    }
    
    // Request explicit iCloud access from user and store bookmark
    func requestExplicitiCloudAccess() -> URL? {
        let openPanel = NSOpenPanel()
        openPanel.message = "Please select your iCloud Drive folder to grant CloudBooth access"
        openPanel.prompt = "Grant Access"
        
        // Try to start in the iCloud folder if possible
        let containerPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        if let possibleiCloud = containerPath?.deletingLastPathComponent().appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs") {
            if FileManager.default.fileExists(atPath: possibleiCloud.path) {
                openPanel.directoryURL = possibleiCloud
            }
        }
        
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.level = .modalPanel
        
        // Bring app to front
        NSApp.activate(ignoringOtherApps: true)
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            // Try to create a security-scoped bookmark
            do {
                // Start accessing
                if !selectedURL.startAccessingSecurityScopedResource() {
                    print("⚠️ Could not access security-scoped resource")
                }
                
                // Create a security scoped bookmark
                let bookmarkData = try selectedURL.bookmarkData(options: .withSecurityScope, 
                                                               includingResourceValuesForKeys: nil, 
                                                               relativeTo: nil)
                
                // Save the bookmark
                UserDefaults.standard.set(bookmarkData, forKey: iCloudBookmarkKey)
                
                print("✅ Successfully created security-scoped bookmark for: \(selectedURL.path)")
                
                // Stop accessing
                selectedURL.stopAccessingSecurityScopedResource()
                
                return selectedURL
            } catch {
                print("❌ Failed to create security-scoped bookmark: \(error.localizedDescription)")
                return nil
            }
        }
        
        print("❌ User cancelled iCloud folder selection")
        return nil
    }
    
    // Get iCloud Drive with access to user-selected location
    func iCloudDrive() -> URL {
        // First try to use security-scoped bookmark if available
        if let bookmarkData = UserDefaults.standard.data(forKey: iCloudBookmarkKey) {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, 
                                  options: [.withSecurityScope], 
                                  relativeTo: nil, 
                                  bookmarkDataIsStale: &isStale)
                
                // Start accessing the security-scoped resource
                if url.startAccessingSecurityScopedResource() {
                    print("🔍 Using security-scoped bookmarked iCloud path: \(url.path)")
                    return url
                } else {
                    print("⚠️ Failed to start accessing security-scoped resource")
                }
            } catch {
                print("❌ Failed to use iCloud bookmark: \(error.localizedDescription)")
                UserDefaults.standard.removeObject(forKey: iCloudBookmarkKey)
            }
        }
        
        // Fall back to container path if we can't use the bookmark
        // For sandboxed apps, we need to accept that we're in a container
        let fileManager = FileManager.default
        
        // Check for the container-specific path to iCloud which is most reliable
        let containerPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        if let containerURL = containerPath?.deletingLastPathComponent().appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs") {
            print("🔍 Using container iCloud path (fallback): \(containerURL.path)")
            return containerURL
        }
        
        // Final fallback to using home directory
        let homeDir = fileManager.homeDirectoryForCurrentUser
        let directiCloudPath = homeDir.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        
        print("🔍 Using home iCloud path (final fallback): \(directiCloudPath.path)")
        return directiCloudPath
    }
    
    // Get the path to the user's Photo Booth library
    func photoBooth(subFolder: String? = nil) -> URL {
        let fileManager = FileManager.default
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        
        // Standard Photo Booth location
        let standardPath = homeDirectory.appendingPathComponent("Pictures/Photo Booth Library")
        
        // Check if the standard path exists
        var isDirectory: ObjCBool = false
        if fileManager.fileExists(atPath: standardPath.path, isDirectory: &isDirectory) && isDirectory.boolValue {
            print("✅ Standard Photo Booth library path exists")
            
            // Add subfolder if requested
            if let subFolder = subFolder {
                return standardPath.appendingPathComponent(subFolder)
            }
            
            return standardPath
        }
        
        // If the standard path doesn't exist, try to search for it
        print("⚠️ Standard Photo Booth library path not found, attempting to locate...")
        
        // Try searching in the Pictures directory
        do {
            let picturesPath = homeDirectory.appendingPathComponent("Pictures")
            if fileManager.fileExists(atPath: picturesPath.path, isDirectory: &isDirectory) && isDirectory.boolValue {
                let contents = try fileManager.contentsOfDirectory(at: picturesPath, includingPropertiesForKeys: nil)
                
                // Look for "Photo Booth Library" directory
                for item in contents {
                    if item.lastPathComponent == "Photo Booth Library" && 
                       fileManager.fileExists(atPath: item.path, isDirectory: &isDirectory) && 
                       isDirectory.boolValue {
                        print("✅ Found Photo Booth library at: \(item.path)")
                        
                        // Add subfolder if requested
                        if let subFolder = subFolder {
                            return item.appendingPathComponent(subFolder)
                        }
                        
                        return item
                    }
                }
            }
        } catch {
            print("⚠️ Error searching for Photo Booth library: \(error.localizedDescription)")
        }
        
        // If we still can't find it, use the standard path
        print("⚠️ Could not locate Photo Booth library, using standard path")
        
        // Add subfolder if requested
        if let subFolder = subFolder {
            return standardPath.appendingPathComponent(subFolder)
        }
        
        return standardPath
    }
    
    // Check if iCloud Drive is available
    func isiCloudDriveAvailable() -> Bool {
        do {
            let url = iCloudDrive()
            let _ = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            return true
        } catch {
            print("⚠️ iCloud Drive is not available: \(error.localizedDescription)")
            return false
        }
    }
    
    func requestAccessPermission(to url: URL) -> Bool {
        print("Requesting access permission to: \(url.path)")
        
        // Verify the directory exists
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        let exists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
        
        if !exists {
            print("⚠️ ERROR: Directory does not exist: \(url.path)")
            // Try to create the directory if it doesn't exist and it's the CloudBooth directory in iCloud
            if url.path.contains("CloudBooth") && url.path.contains("com~apple~CloudDocs") {
                do {
                    try fileManager.createDirectory(at: url, withIntermediateDirectories: true)
                    print("📁 Created directory: \(url.path)")
                    
                    // Verify it was created successfully
                    let nowExists = fileManager.fileExists(atPath: url.path, isDirectory: &isDirectory)
                    print("Directory created successfully: \(nowExists), isDirectory: \(isDirectory.boolValue)")
                    
                    if !nowExists {
                        print("⚠️ Failed to create directory even though no error was thrown")
                        return false
                    }
                } catch {
                    print("⚠️ Failed to create directory: \(error.localizedDescription)")
                    // Display an alert to the user with more info
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Failed to Create Directory"
                        alert.informativeText = "Could not create the CloudBooth directory in iCloud Drive. Error: \(error.localizedDescription)\n\nPath: \(url.path)"
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                    return false
                }
            } else {
                // Display an alert to the user with more info
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Directory Not Found"
                    alert.informativeText = "The required directory does not exist: \(url.path)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return false
            }
        }
        
        if !isDirectory.boolValue {
            print("⚠️ ERROR: Path exists but is not a directory: \(url.path)")
            // Display an alert to the user with more info
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Not a Directory"
                alert.informativeText = "The path exists but is not a directory: \(url.path)"
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return false
        }
        
        // Check if we already have access by trying to read the directory
        if canAccessDirectory(url) {
            print("✅ Already have access to: \(url.path)")
            return true
        }
        
        print("🔒 Need to request access for: \(url.path)")
        
        // Request access via open panel
        let openPanel = NSOpenPanel()
        
        // Make the message more clear about what folder to select
        if url.path.contains("Photo Booth Library") {
            openPanel.message = "Please select your Photo Booth Library folder:\n/Users/[username]/Pictures/Photo Booth Library"
        } else if url.path.contains("com~apple~CloudDocs") {
            openPanel.message = "Please select your iCloud Drive folder"
        } else {
            openPanel.message = "CloudBooth needs access to \(url.path)\nPlease select this exact folder to continue."
        }
        
        openPanel.prompt = "Grant Access"
        openPanel.directoryURL = url
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        openPanel.level = .modalPanel
        
        // Bring to front and focus
        NSApp.activate(ignoringOtherApps: true)
        
        if openPanel.runModal() == .OK, let selectedURL = openPanel.url {
            // Check if we got access to the correct directory
            print("User selected directory: \(selectedURL.path)")
            
            // Use a smarter path comparison based on the type of directory
            let isCorrectSelection = isSelectedPathCorrect(expected: url, selected: selectedURL)
            
            if isCorrectSelection {
                let hasAccess = canAccessDirectory(selectedURL)
                print(hasAccess ? "✅ Successfully gained access to selected path" : "❌ Still cannot access selected path")
                
                if hasAccess {
                    // If the selected path is different but correct, we should use this path
                    // going forward for this session
                    if selectedURL.path.lowercased() != url.path.lowercased() {
                        print("⚠️ Note: User selected an equivalent path but not exactly matching.")
                    }
                    return true
                } else {
                    // Display an error alert
                    DispatchQueue.main.async {
                        let alert = NSAlert()
                        alert.messageText = "Permission Error"
                        alert.informativeText = "CloudBooth still cannot access the selected folder. Please ensure you have the necessary permissions."
                        alert.alertStyle = .warning
                        alert.addButton(withTitle: "OK")
                        alert.runModal()
                    }
                    return false
                }
            } else {
                print("❌ User selected different directory than needed")
                // Display an error alert with more details about the expected path
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Incorrect Selection"
                    alert.informativeText = self.createPathErrorMessage(expected: url, selected: selectedURL)
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return false
            }
        } else {
            print("❌ User cancelled permission dialog")
            return false
        }
    }
    
    // Helper to determine if the selected path is the correct type of path we need
    private func isSelectedPathCorrect(expected: URL, selected: URL) -> Bool {
        // Exact match is always valid
        if selected.path.lowercased() == expected.path.lowercased() {
            return true
        }
        
        // For Photo Booth Library folders
        if expected.path.contains("Photo Booth Library") {
            // Check if it's a valid Photo Booth path with the right subfolder
            let isPhotoBooth = selected.path.contains("Photo Booth Library")
            
            // Check if we're looking at the correct subfolder (Originals or Pictures)
            if let expectedSubfolder = getPhotoBoothSubfolder(from: expected.path),
               let selectedSubfolder = getPhotoBoothSubfolder(from: selected.path) {
                return isPhotoBooth && (expectedSubfolder == selectedSubfolder)
            }
            
            // If we couldn't extract subfolders, just check if it's Photo Booth
            return isPhotoBooth
        }
        
        // For iCloud Drive folders
        if expected.path.contains("CloudDocs") || expected.path.contains("iCloud Drive") {
            return selected.path.contains("CloudDocs") || selected.path.contains("iCloud Drive")
        }
        
        // For CloudBooth folder in iCloud
        if expected.lastPathComponent == "CloudBooth" && expected.path.contains("CloudDocs") {
            return selected.lastPathComponent == "CloudBooth" &&
                   (selected.path.contains("CloudDocs") || selected.path.contains("iCloud Drive"))
        }
        
        // Default to exact match for other paths
        return false
    }
    
    // Helper to extract the Photo Booth subfolder (Originals or Pictures)
    private func getPhotoBoothSubfolder(from path: String) -> String? {
        if path.hasSuffix("/Originals") {
            return "Originals"
        } else if path.hasSuffix("/Pictures") {
            return "Pictures"
        }
        return nil
    }
    
    // Create a friendly error message for path selection issues
    private func createPathErrorMessage(expected: URL, selected: URL) -> String {
        // For Photo Booth paths
        if expected.path.contains("Photo Booth Library") {
            let subfolder = expected.path.hasSuffix("/Originals") ? "Originals" : 
                           expected.path.hasSuffix("/Pictures") ? "Pictures" : ""
            
            return "Please select the correct Photo Booth Library \(subfolder) folder.\n\n" +
                   "Expected folder: Pictures/Photo Booth Library/\(subfolder)\n" +
                   "You selected: \(selected.path)"
        }
        
        // For iCloud paths
        if expected.path.contains("CloudDocs") {
            return "Please select your iCloud Drive folder.\n\n" +
                   "You selected: \(selected.path)"
        }
        
        // Generic message
        return "You selected a different folder than the one CloudBooth needs access to.\n\n" +
               "Needed: \(expected.path)\n" +
               "Selected: \(selected.path)"
    }
    
    // Check if we can actually access a directory by trying to list its contents
    private func canAccessDirectory(_ url: URL) -> Bool {
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil)
            print("📂 Can access directory \(url.path). Contents count: \(contents.count)")
            return true
        } catch {
            print("❌ Cannot access directory \(url.path): \(error.localizedDescription)")
            return false
        }
    }
    
    func ensureDirectoryAccess() async -> Bool {
        print("🔍 Checking directory access permissions...")
        
        // Check if permissions were already granted
        let permissionsAlreadyGranted = UserDefaults.standard.bool(forKey: permissionsGrantedKey)
        print("Permissions previously granted: \(permissionsAlreadyGranted)")
        
        if permissionsAlreadyGranted {
            // Verify we can still access all directories
            let originalsURL = photoBooth(subFolder: "Originals")
            let picturesURL = photoBooth(subFolder: "Pictures")
            
            // Get the direct iCloud path instead of container path
            let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            let destinationURL = directiCloudURL.appendingPathComponent("CloudBooth")
            
            print("Verifying access to previously granted directories...")
            print("Photo Booth Originals: \(originalsURL.path)")
            print("Photo Booth Pictures: \(picturesURL.path)")
            print("iCloud destination: \(destinationURL.path)")
            
            let canAccessOriginals = canAccessDirectory(originalsURL)
            let canAccessPictures = canAccessDirectory(picturesURL)
            let canAccessDestination = canAccessDirectory(destinationURL)
            
            if canAccessOriginals && canAccessPictures && canAccessDestination {
                print("✅ All permissions still valid")
                // Save the direct iCloud path as a bookmark for future use
                if UserDefaults.standard.data(forKey: iCloudBookmarkKey) == nil {
                    _ = requestExplicitiCloudAccess()
                }
                return true
            }
            
            print("⚠️ Some directories are no longer accessible, resetting permissions")
            // If we can't access one of the directories, reset the stored permission state
            UserDefaults.standard.set(false, forKey: permissionsGrantedKey)
        }
        
        // Simulate an async operation by adding a small delay
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01 second
        
        // Source directories
        let originalsURL = photoBooth(subFolder: "Originals")
        let picturesURL = photoBooth(subFolder: "Pictures")
        
        print("Photo Booth directories to request access:")
        print("- Originals: \(originalsURL.path)")
        print("- Pictures: \(picturesURL.path)")
        
        // First check if the Photo Booth directories exist before requesting permission
        let fileManager = FileManager.default
        var isDirectory: ObjCBool = false
        
        let originalsExist = fileManager.fileExists(atPath: originalsURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
        let picturesExist = fileManager.fileExists(atPath: picturesURL.path, isDirectory: &isDirectory) && isDirectory.boolValue
        
        if !originalsExist || !picturesExist {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Photo Booth Folders Not Found"
                alert.informativeText = "CloudBooth could not find your Photo Booth Library folders. Please ensure Photo Booth has been launched at least once on this Mac to create these folders."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return false
        }
        
        // Get the direct iCloud path instead of container path
        let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        
        // Destination directory - create CloudBooth folder in iCloud Drive
        let destinationURL = directiCloudURL.appendingPathComponent("CloudBooth")
        
        print("Direct iCloud destination: \(destinationURL.path)")
        
        // Ask the user for permission to access the iCloud Drive folder directly
        print("Requesting explicit permission for iCloud Drive...")
        let iCloudURL = requestExplicitiCloudAccess()
        if iCloudURL == nil {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "iCloud Drive Access Required"
                alert.informativeText = "CloudBooth needs access to your iCloud Drive to sync files. Please grant access when prompted."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
            return false
        }
        
        // Create the CloudBooth folder if it doesn't exist
        if !fileManager.fileExists(atPath: destinationURL.path) {
            do {
                try fileManager.createDirectory(at: destinationURL, withIntermediateDirectories: true)
                print("📁 Created CloudBooth directory in iCloud Drive")
            } catch {
                print("⚠️ Failed to create CloudBooth directory: \(error.localizedDescription)")
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Failed to Create Directory"
                    alert.informativeText = "CloudBooth could not create a folder in your iCloud Drive. Error: \(error.localizedDescription)"
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return false
            }
        }
        
        // Request access to all directories
        print("Requesting permission for all required directories...")
        let originalsAccess = requestAccessPermission(to: originalsURL)
        
        if !originalsAccess {
            print("❌ Failed to get access to Originals folder")
            return false
        }
        
        let picturesAccess = requestAccessPermission(to: picturesURL)
        
        if !picturesAccess {
            print("❌ Failed to get access to Pictures folder")
            return false
        }
        
        let destAccess = requestAccessPermission(to: destinationURL)
        
        if !destAccess {
            print("❌ Failed to get access to iCloud destination folder")
            return false
        }
        
        // Final verification
        let allAccessGranted = originalsAccess && picturesAccess && destAccess
        
        // Store permission state
        UserDefaults.standard.set(allAccessGranted, forKey: permissionsGrantedKey)
        print(allAccessGranted ? "✅ All permissions granted and saved" : "❌ Not all permissions were granted")
        
        return allAccessGranted
    }
    
    // Helper to get the resolved destination URL
    func resolvedDestinationURL() -> URL? {
        let destinationURL = iCloudDrive().appendingPathComponent("CloudBooth")
        return destinationURL
    }
    
    // Reset bookmarks when permissions need to be requested again
    func resetAllBookmarks() {
        print("🔄 Resetting all saved permissions")
        UserDefaults.standard.set(false, forKey: permissionsGrantedKey)
    }
} 