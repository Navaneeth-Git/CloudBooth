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
                stopFolderMonitoring()
                startPollingForNewPhotos()
            } else {
                stopPollingForNewPhotos()
                stopFolderMonitoring()
                scheduleNextSync()
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
    private var monitoredFolders: [String] = [
        "/Users/navaneeth/Pictures/Photo Booth Library/Pictures",
        "/Users/navaneeth/Pictures/Photo Booth Library/Originals"
    ]
    
    private var pollingTimer: Timer?
    private var lastPolledFileCounts: [String: Int] = [:]
    
    private init() {
        loadSettings()
    }
    
    func loadSettings() {
        // Load auto sync preference
        if let intervalString = UserDefaults.standard.string(forKey: "autoSyncInterval"),
           let interval = SyncInterval(rawValue: intervalString) {
            autoSyncInterval = interval
        }
        
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
        print("[AutoSync] Scheduling next sync. Interval: \(autoSyncInterval.rawValue)")
        // If auto sync is disabled or using folder monitoring, do nothing
        if autoSyncInterval == .never || autoSyncInterval == .onNewPhotos {
            print("[AutoSync] Auto sync disabled or using folder monitoring.")
            nextScheduledSync = nil
            return
        }
        // Calculate the next sync time
        let nextSync: Date
        if let lastSync = lastSyncDate {
            nextSync = lastSync.addingTimeInterval(autoSyncInterval.seconds)
        } else {
            nextSync = Date().addingTimeInterval(autoSyncInterval.seconds)
        }
        nextScheduledSync = nextSync
        let timeInterval = nextSync.timeIntervalSinceNow
        print("[AutoSync] Next sync scheduled for: \(nextSync) (in \(timeInterval) seconds)")
        if timeInterval > 0 {
            timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
                print("[AutoSync] Timer fired, posting AutoSyncRequested notification.")
                Task { @MainActor in
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
        } else {
            timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: false) { _ in
                print("[AutoSync] Timer fired (late), posting AutoSyncRequested notification.")
                Task { @MainActor in
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
        }
    }
    
    // Sets up folder monitoring for both source folders
    private func setupFolderMonitoring() {
        stopFolderMonitoring() // Clear any existing monitors
        print("[AutoSync] Setting up folder monitoring for: \(monitoredFolders)")
        for folderPath in monitoredFolders {
            setupMonitorForFolder(folderPath)
        }
    }
    
    // Creates a file system monitor for a specific folder
    private func setupMonitorForFolder(_ folderPath: String) {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: folderPath) else {
            print("[AutoSync] Folder does not exist: \(folderPath)")
            return
        }
        do {
            let fileDescriptor = open(folderPath, O_EVTONLY)
            if fileDescriptor < 0 {
                print("[AutoSync] Error opening file descriptor for \(folderPath)")
                return
            }
            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fileDescriptor,
                eventMask: [.write, .extend, .attrib, .rename],
                queue: .main
            )
            source.setEventHandler {
                Task { @MainActor in
                    print("[AutoSync] Detected changes in \(folderPath) (event mask: .write/.extend/.attrib/.rename)")
                    try? await Task.sleep(nanoseconds: 2_000_000_000) // 2 seconds
                    NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
                }
            }
            source.setCancelHandler {
                close(fileDescriptor)
            }
            source.resume()
            fileMonitors.append(source)
            print("[AutoSync] Monitoring started for: \(folderPath)")
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
    
    private func startPollingForNewPhotos() {
        stopPollingForNewPhotos()
        print("[AutoSync] Starting polling for new photos...")
        pollingTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.pollForNewFiles()
        }
        pollingTimer?.tolerance = 1
        pollForNewFiles() // Initial check
    }
    
    private func stopPollingForNewPhotos() {
        pollingTimer?.invalidate()
        pollingTimer = nil
        print("[AutoSync] Stopped polling for new photos.")
    }
    
    private func pollForNewFiles() {
        let folders = monitoredFolders
        var foundNewFiles = false
        for folder in folders {
            let fileManager = FileManager.default
            if let files = try? fileManager.contentsOfDirectory(atPath: folder) {
                let count = files.filter { !$0.hasPrefix(".") }.count
                if let lastCount = lastPolledFileCounts[folder], count > lastCount {
                    print("[AutoSync] New files detected in \(folder). Triggering sync...")
                    foundNewFiles = true
                }
                lastPolledFileCounts[folder] = count
            }
        }
        if foundNewFiles {
            NotificationCenter.default.post(name: Notification.Name("AutoSyncRequested"), object: nil)
        }
    }
} 