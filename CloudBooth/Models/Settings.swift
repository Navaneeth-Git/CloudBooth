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
            UserDefaults.standard.setValue(autoSyncInterval.rawValue, forKey: "autoSyncInterval")
            if autoSyncInterval == .onNewPhotos {
                setupFolderMonitoring()
            } else {
                stopFolderMonitoring()
                scheduleNextSync()
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
                
                // Save security-scoped bookmark for the custom destination
                let url = URL(fileURLWithPath: path)
                do {
                    let bookmarkData = try url.bookmarkData(
                        options: .withSecurityScope,
                        includingResourceValuesForKeys: nil,
                        relativeTo: nil
                    )
                    UserDefaults.standard.set(bookmarkData, forKey: "customDestinationBookmark")
                } catch {
                    print("Failed to save bookmark for custom destination: \(error)")
                }
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
        let homeDirectory = FileManager.default.homeDirectoryForCurrentUser.path
        return [
            "\(homeDirectory)/Pictures/Photo Booth Library/Pictures",
            "\(homeDirectory)/Pictures/Photo Booth Library/Originals"
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
        stopFolderMonitoring() // Clear any existing monitors
        
        for folderPath in monitoredFolders {
            setupMonitorForFolder(folderPath)
        }
    }
    
    // Creates a file system monitor for a specific folder
    private func setupMonitorForFolder(_ folderPath: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folderPath) else { return }
        
        do {
            let fileDescriptor = open(folderPath, O_EVTONLY)
            if fileDescriptor < 0 {
                print("Error opening file descriptor for \(folderPath)")
                return
            }
            
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .extend, .attrib, .rename],
                queue: .main
            )
            
            source.setEventHandler {
                Task { @MainActor in
                    print("Detected changes in \(folderPath)")
                    // Wait a bit to make sure file operations are complete
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
            
            source.setCancelHandler {
                close(fileDescriptor)
            }
            
            source.resume()
            fileMonitors.append(source)
            
        }
    }
    
    // Stops all active folder monitors
    private func stopFolderMonitoring() {
        for monitor in fileMonitors {
            monitor.cancel()
        }
        fileMonitors.removeAll()
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
            // Always use explicit user directory path for iCloud, avoiding container paths
            return FileAccessManager.shared.getICloudDirectory()
        }
    }
    
    // Access custom destination with security-scoped bookmark
    func accessCustomDestination() -> URL? {
        guard useCustomDestination,
              let bookmarkData = UserDefaults.standard.data(forKey: "customDestinationBookmark") else {
            return nil
        }
        
        var isStale = false
        do {
            let url = try URL(resolvingBookmarkData: bookmarkData,
                            options: .withSecurityScope,
                            relativeTo: nil,
                            bookmarkDataIsStale: &isStale)
            
            if url.startAccessingSecurityScopedResource() {
                return url
            }
        } catch {
            print("Failed to resolve custom destination bookmark: \(error)")
        }
        
        return nil
    }
} 