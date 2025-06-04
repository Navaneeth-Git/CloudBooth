import Foundation
import SwiftUI
import Combine
import AppKit
#if canImport(Darwin)
import Darwin
#elseif canImport(Glibc)
import Glibc
#endif

// Represents different auto-sync intervals
enum SyncInterval: String, CaseIterable, Identifiable {
    case never = "Never"
    case onNewPhotos = "When New Photos Added"
    case sixHours = "Every 6 Hours"
    case daily = "Daily"
    case weekly = "Weekly" 
    case monthly = "Monthly"
    
    var id: String { rawValue }
    
    // Convert intervals to seconds
    var seconds: TimeInterval {
        switch self {
        case .never: return 0
        case .onNewPhotos: return -1 // Special value to indicate real-time monitoring
        case .sixHours: return 6 * 60 * 60
        case .daily: return 24 * 60 * 60
        case .weekly: return 7 * 24 * 60 * 60
        case .monthly: return 30 * 24 * 60 * 60
        }
    }
}

// Represents a single sync operation record
struct SyncRecord: Codable, Identifiable {
    var id: UUID 
    var date: Date
    var filesTransferred: Int
    var success: Bool
    var errorMessage: String?
    
    init(id: UUID = UUID(), date: Date, filesTransferred: Int, success: Bool, errorMessage: String? = nil) {
        self.id = id
        self.date = date
        self.filesTransferred = filesTransferred
        self.success = success
        self.errorMessage = errorMessage
    }
}

@MainActor
class Settings: ObservableObject {
    static let shared = Settings()
    
    // Auto-sync interval preference
    @Published var autoSyncInterval: SyncInterval = .never {
        didSet {
            print("🔄 Auto-sync interval changed to: \(autoSyncInterval.rawValue)")
            UserDefaults.standard.setValue(autoSyncInterval.rawValue, forKey: "autoSyncInterval")
            
            // Stop existing monitoring/timer
            stopFolderMonitoring()
            timer?.invalidate()
            timer = nil
            
            // Set up appropriate monitoring
            if autoSyncInterval == .onNewPhotos {
                print("🔍 Using folder monitoring for real-time sync")
                setupFolderMonitoring()
            } else if autoSyncInterval != .never {
                print("⏰ Using timer-based sync")
                scheduleNextSync()
            } else {
                print("❌ Auto-sync disabled")
            }
        }
    }
    
    // Custom destination path
    @Published var useCustomDestination: Bool = false {
        didSet {
            UserDefaults.standard.setValue(useCustomDestination, forKey: "useCustomDestination")
        }
    }
    
    @Published var customDestinationPath: String? {
        didSet {
            if let path = customDestinationPath {
                UserDefaults.standard.setValue(path, forKey: "customDestinationPath")
            }
        }
    }
    
    // Last sync date for display and calculations
    @Published var lastSyncDate: Date? {
        didSet {
            if let date = lastSyncDate {
                UserDefaults.standard.setValue(date, forKey: "lastSyncDate")
            }
        }
    }
    
    // Next scheduled sync date for display
    @Published var nextScheduledSync: Date?
    
    // History of sync operations
    @Published var syncHistory: [SyncRecord] = [] {
        didSet {
            saveSyncHistory()
        }
    }
    
    private var timer: Timer?
    private var fileMonitors: [DispatchSourceFileSystemObject] = []
    private var monitoredFolders: [String] {
        // Use FileAccessManager to get the correct Photo Booth paths
        return [
            FileAccessManager.shared.photoBooth(subFolder: "Pictures").path,
            FileAccessManager.shared.photoBooth(subFolder: "Originals").path
        ]
    }
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load auto sync preference
        if let intervalString = UserDefaults.standard.string(forKey: "autoSyncInterval"),
           let interval = SyncInterval(rawValue: intervalString) {
            autoSyncInterval = interval
        }
        
        // Load custom destination settings
        useCustomDestination = UserDefaults.standard.bool(forKey: "useCustomDestination")
        customDestinationPath = UserDefaults.standard.string(forKey: "customDestinationPath")
        
        // Load last sync date
        lastSyncDate = UserDefaults.standard.object(forKey: "lastSyncDate") as? Date
        
        // Load sync history
        loadSyncHistory()
        
        // Setup appropriate syncing mechanism
        if autoSyncInterval == .onNewPhotos {
            setupFolderMonitoring()
        } else {
            scheduleNextSync()
        }
    }
    
    func addSyncRecord(_ record: SyncRecord) {
        syncHistory.insert(record, at: 0)
        lastSyncDate = record.date
        
        // Keep only the last 50 records to avoid bloat
        if syncHistory.count > 50 {
            syncHistory = Array(syncHistory.prefix(50))
        }
    }
    
    func scheduleNextSync() {
        // Cancel any existing timer
        timer?.invalidate()
        timer = nil
        
        // If auto sync is disabled or using folder monitoring, do nothing
        if autoSyncInterval == .never || autoSyncInterval == .onNewPhotos {
            nextScheduledSync = nil
            return
        }
        
        // Calculate the next sync time
        let nextSync: Date
        
        if let lastSync = lastSyncDate {
            nextSync = lastSync.addingTimeInterval(autoSyncInterval.seconds)
        } else {
            // If no previous sync, schedule from now
            nextSync = Date().addingTimeInterval(autoSyncInterval.seconds)
        }
        
        nextScheduledSync = nextSync
        
        // Schedule the timer
        let timeInterval = nextSync.timeIntervalSinceNow
        if timeInterval > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                Task { @MainActor in
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
        } else {
            // If the next sync time is in the past, schedule it for soon
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                Task { @MainActor in
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
        }
    }
    
    // Sets up folder monitoring for both source folders
    private func setupFolderMonitoring() {
        print("🔍 Setting up folder monitoring for auto-sync...")
        
        // First, stop any existing monitors
        stopFolderMonitoring()
        
        // Ensure we have permissions
        Task {
            // Check permissions before setting up monitors
            let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
            
            if !hasAccess {
                print("⚠️ Cannot set up folder monitoring - missing permissions")
                
                // Show alert to user on main thread
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Auto-Sync Disabled"
                    alert.informativeText = "CloudBooth needs permission to access Photo Booth folders for auto-sync to work. Please grant access in the app."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return
            }
            
            // Get the paths we want to monitor
            let paths = monitoredFolders
            
            print("📁 Setting up monitoring for \(paths.count) folders")
            
            // Set up monitors for each folder
            for folderPath in paths {
                setupMonitorForFolder(folderPath)
            }
            
            print("✅ Folder monitoring setup completed")
        }
    }
    
    // Creates a file system monitor for a specific folder
    private func setupMonitorForFolder(_ folderPath: String) {
        let fileManager = FileManager.default
        
        print("📂 Setting up monitoring for: \(folderPath)")
        
        // Check if folder exists first
        var isDirectory: ObjCBool = false
        guard fileManager.fileExists(atPath: folderPath, isDirectory: &isDirectory) && isDirectory.boolValue else { 
            print("⚠️ Cannot monitor folder - doesn't exist or isn't a directory: \(folderPath)")
            return 
        }
        
        // Verify we can access the folder
        do {
            let _ = try fileManager.contentsOfDirectory(atPath: folderPath)
            print("✅ Successfully accessed folder for monitoring: \(folderPath)")
        } catch {
            print("❌ Cannot access folder for monitoring: \(folderPath)")
            print("   Error: \(error.localizedDescription)")
            return
        }
        
        do {
            let fileDescriptor = open(folderPath, O_EVTONLY)
            if fileDescriptor < 0 {
                let errorString = String(cString: strerror(errno))
                print("❌ Error opening file descriptor for \(folderPath): \(errorString) (errno: \(errno))")
                return
            }
            
            print("✅ Successfully opened file descriptor (\(fileDescriptor)) for: \(folderPath)")
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: .write,
                queue: .main
            )
            
            source.setEventHandler {
                Task { @MainActor in
                    print("🔔 Detected changes in \(folderPath)")
                    // Wait a bit to make sure file operations are complete
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    
                    // Post notification for auto-sync
                    print("🔄 Triggering auto-sync due to changes in: \(folderPath)")
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
            
            source.setCancelHandler {
                print("🛑 Closing file descriptor (\(fileDescriptor)) for: \(folderPath)")
                close(fileDescriptor)
            }
            
            source.resume()
            fileMonitors.append(source)
            print("✅ File monitoring activated for: \(folderPath)")
        } catch {
            print("❌ Failed to set up file monitoring for \(folderPath): \(error.localizedDescription)")
        }
    }
    
    // Stops all active folder monitors
    private func stopFolderMonitoring() {
        if fileMonitors.isEmpty {
            print("ℹ️ No active file monitors to stop")
            return
        }
        
        print("🛑 Stopping \(fileMonitors.count) active file monitors...")
        
        for monitor in fileMonitors {
            monitor.cancel()
        }
        
        fileMonitors.removeAll()
        print("✅ All file monitors stopped")
    }
    
    private func saveSyncHistory() {
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(syncHistory)
            UserDefaults.standard.set(data, forKey: "syncHistory")
        } catch {
            print("Failed to save sync history: \(error)")
        }
    }
    
    private func loadSyncHistory() {
        if let data = UserDefaults.standard.data(forKey: "syncHistory") {
            do {
                let decoder = JSONDecoder()
                syncHistory = try decoder.decode([SyncRecord].self, from: data)
            } catch {
                print("Failed to load sync history: \(error)")
                syncHistory = []
            }
        }
    }
    
    // Get the destination base path based on user preference
    func getDestinationBasePath() -> String {
        if useCustomDestination, let customPath = customDestinationPath {
            return customPath
        } else {
            // First try to use security-scoped bookmark if available
            if let bookmarkData = UserDefaults.standard.data(forKey: "iCloudBookmarkData") {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: bookmarkData, 
                                      options: [.withSecurityScope], 
                                      relativeTo: nil, 
                                      bookmarkDataIsStale: &isStale)
                    
                    // Start accessing the security-scoped resource
                    if url.startAccessingSecurityScopedResource() {
                        print("🔍 Using security-scoped bookmarked iCloud path for destination: \(url.path)")
                        return url.path
                    }
                } catch {
                    print("❌ Failed to use iCloud bookmark for destination: \(error.localizedDescription)")
                }
            }
            
            // Always use the direct iCloud path instead of container path
            let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
            print("🔍 Using direct iCloud path for destination: \(directiCloudURL.path)")
            return directiCloudURL.path
        }
    }
} 