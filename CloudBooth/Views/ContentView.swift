import SwiftUI

struct SyncStats {
    var filesCopied = 0
    var totalFiles = 0
}

struct ContentView: View {
    @EnvironmentObject var settings: Settings
    @State private var isLoading = false
    @State private var statusMessage = "Ready to sync"
    @State private var originals = SyncStats()
    @State private var pictures = SyncStats()
    @State private var showPermissionAlert = false
    @State private var showSettingsSheet = false
    @State private var showHistorySheet = false
    @State private var animateSync = false
    @State private var animateUpload = false
    @State private var syncLogs: [String] = []
    @State private var showLogViewer = false
    @State private var hasError = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            ScrollView {
                VStack(spacing: 24) {
                    // Status card
                    statusCard
                    
                    // Folders card
                    foldersCard
                    
                    // Auto-sync info
                    if settings.autoSyncInterval != .never {
                        autoSyncCard
                    }
                }
                .padding()
            }
            
            Spacer()
            
            // Bottom action bar
            actionBar
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(width: 480, height: 600)
        .alert("Permission Required", isPresented: $showPermissionAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("CloudBooth needs access to your Photo Booth and iCloud Drive folders. Please grant access when prompted.")
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .sheet(isPresented: $showHistorySheet) {
            HistoryView()
        }
        .sheet(isPresented: $showLogViewer) {
            LogViewer(logs: syncLogs)
        }
        .onAppear {
            checkPermissions()
            setupNotificationObservers()
        }
        .onDisappear {
            removeNotificationObservers()
        }
    }
    
    // MARK: - UI Components
    
    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("CloudBooth")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Photo Booth to iCloud Sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            
            Spacer()
            
            // Attribution capsule
            Link(destination: URL(string: "https://github.com/Navaneeth-Git/")!) {
                Text("By Navaneeth")
                    .font(.caption)
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        Capsule()
                            .fill(Color.blue.opacity(0.7))
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 8)
            
            // Subtle upload animation
            Image(systemName: "icloud")
                .font(.title)
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.blue)
                .opacity(isLoading ? (animateUpload ? 0.4 : 1.0) : 1.0)
                .animation(isLoading ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: animateUpload)
                .onAppear {
                    if isLoading { animateUpload = true }
                }
                .onChange(of: isLoading) { newValue in
                    animateUpload = newValue
                }
        }
        .padding()
    }
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                Image(systemName: isLoading ? "icloud" : (hasError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isLoading ? .blue : (hasError ? .red : .green))
                    .opacity(isLoading ? (animateUpload ? 0.4 : 1.0) : 1.0)
                    .animation(isLoading ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: animateUpload)
                
                Text(statusMessage)
                    .font(.headline)
                
                if hasError && !isLoading {
                    Spacer()
                    
                    Button(action: {
                        showLogViewer = true
                    }) {
                        Text("View Logs")
                            .font(.caption)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.red, lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            
            // Sync progress or history
            if isLoading {
                // Sync in progress
                VStack(alignment: .leading, spacing: 8) {
                    syncProgressView(
                        label: "Original Photos", 
                        stats: originals, 
                        color: .orange
                    )
                    
                    syncProgressView(
                        label: "Edited Photos", 
                        stats: pictures, 
                        color: .blue
                    )
                }
            } else if let record = settings.syncHistory.first {
                // Last sync info
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text("Last sync: \(record.date, formatter: dateFormatter)")
                            .font(.subheadline)
                    }
                    
                    HStack {
                        Image(systemName: "doc")
                            .foregroundStyle(.secondary)
                        Text("Files transferred: \(record.filesTransferred)")
                            .font(.subheadline)
                    }
                    
                    if !record.success, let error = record.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .padding(6)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(6)
                    }
                }
            } else {
                Text("No sync history available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(hasError ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
    
    private func syncProgressView(label: String, stats: SyncStats, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if stats.totalFiles > 0 {
                ProgressView(
                    value: Double(stats.filesCopied),
                    total: Double(stats.totalFiles)
                )
                .progressViewStyle(.linear)
                .tint(color)
                
                Text("\(stats.filesCopied) of \(stats.totalFiles) files processed")
                    .font(.caption)
            } else {
                ProgressView()
                    .progressViewStyle(.linear)
                    .tint(color)
                
                Text("Preparing...")
                    .font(.caption)
            }
        }
    }
    
    private var foldersCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Syncing Folders")
                .font(.headline)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder")
                            .foregroundStyle(.orange)
                        Text("Source")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("Photo Booth Library")
                        .font(.caption)
                    
                    if FileAccessManager.shared.originalsExists && FileAccessManager.shared.picturesExists {
                        Text("Originals & Pictures")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if FileAccessManager.shared.originalsExists {
                        Text("Originals only")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else if FileAccessManager.shared.picturesExists {
                        Text("Pictures only")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("No folders found")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
                
                Image(systemName: "arrow.forward")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: settings.useCustomDestination ? "folder.badge.gearshape" : "icloud")
                            .foregroundStyle(.blue)
                        Text("Destination")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text(settings.useCustomDestination ? "Custom Location" : "iCloud Drive")
                        .font(.caption)
                    
                    Text("CloudBooth folder")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.12))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
    
    private var autoSyncCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.headline)
                    .foregroundStyle(.blue)
                
                Text("Auto-Sync: \(settings.autoSyncInterval.rawValue)")
                    .font(.headline)
            }
            
            if settings.autoSyncInterval == .onNewPhotos {
                Text("CloudBooth will automatically sync when new photos are added to Photo Booth")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let nextSync = settings.nextScheduledSync {
                HStack {
                    Image(systemName: "calendar.badge.clock")
                        .foregroundStyle(.blue)
                    
                    Text("Next sync: \(nextSync, formatter: dateTimeFormatter)")
                        .font(.caption)
                }
            }
            
            // Caution message
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.orange)
                
                Text("CAUTION: Please keep the app running in the background for auto-sync to work. Do not quit the app if you want automatic backups.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.15))
                .shadow(color: .black.opacity(0.1), radius: 3, x: 0, y: 2)
        )
    }
    
    private var actionBar: some View {
        HStack {
            // History button
            Button(action: {
                showHistorySheet = true
            }) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("View Sync History")
            
            // Settings button
            Button(action: {
                showSettingsSheet = true
            }) {
                Image(systemName: "gear")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("Settings")
            
            Spacer()
            
            // Sync Button
            Button(action: {
                syncPhotos()
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
                .frame(minWidth: 120)
            }
            .disabled(isLoading)
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(
            Rectangle()
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.1), radius: 3, y: -2)
        )
    }
    
    // MARK: - Formatters
    
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    private var dateTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // MARK: - App Logic
    
    // Request access permissions
    private func checkPermissions() {
        Task {
            let _ = await FileAccessManager.shared.ensureDirectoryAccess()
        }
    }
    
    // Set up notification observers for menu commands and auto-sync
    private func setupNotificationObservers() {
        // Manual sync from menu
        NotificationCenter.default.addObserver(
            forName: Notification.Name("SyncNowRequested"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                syncPhotos()
            }
        }
        
        // Auto sync
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AutoSyncRequested"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                if !isLoading {
                    syncPhotos(isAutoSync: true)
                }
                // Schedule next sync
                settings.scheduleNextSync()
            }
        }
        
        // Refresh permissions
        NotificationCenter.default.addObserver(
            forName: Notification.Name("RefreshRequested"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                checkPermissions()
            }
        }
    }
    
    // Clean up observers
    private func removeNotificationObservers() {
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("SyncNowRequested"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("AutoSyncRequested"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: Notification.Name("RefreshRequested"),
            object: nil
        )
    }
    
    // Perform the sync operation
    private func syncPhotos(isAutoSync: Bool = false) {
        // Clear logs for new sync
        syncLogs.removeAll()
        hasError = false
        
        Task {
            // First check for permissions
            let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
            if !hasAccess {
                await MainActor.run {
                    showPermissionAlert = true
                    hasError = true
                    addLog("Permission denied: Unable to access required folders")
                    
                    if isAutoSync {
                        let record = SyncRecord(
                            date: Date(),
                            filesTransferred: 0,
                            success: false,
                            errorMessage: "Permission denied"
                        )
                        settings.addSyncRecord(record)
                    }
                    
                    // Notify menu bar app of sync failure
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SyncFailed"),
                        object: nil,
                        userInfo: ["errorMessage": "Permission denied"]
                    )
                }
                return
            }
            
            addLog("Starting sync process...")
            
            await MainActor.run {
                isLoading = true
                statusMessage = isAutoSync ? "Auto-syncing..." : "Syncing..."
                originals = SyncStats()
                pictures = SyncStats()
                
                // Notify menu bar app that sync has started
                NotificationCenter.default.post(
                    name: NSNotification.Name("SyncStarted"),
                    object: nil,
                    userInfo: [
                        "originalsCount": 0,
                        "picturesCount": 0
                    ]
                )
            }
            
            do {
                let totalFilesCopied = try await performSync()
                
                await MainActor.run {
                    if totalFilesCopied > 0 {
                        statusMessage = "Sync completed successfully"
                        addLog("Sync completed: \(totalFilesCopied) files copied")
                    } else {
                        statusMessage = "No new files to sync"
                        addLog("Sync completed: No new files to copy")
                    }
                    
                    let record = SyncRecord(
                        date: Date(),
                        filesTransferred: totalFilesCopied,
                        success: true
                    )
                    settings.addSyncRecord(record)
                    
                    isLoading = false
                    hasError = false
                    
                    // Notify menu bar app that sync completed successfully
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SyncCompleted"),
                        object: nil,
                        userInfo: [
                            "totalFilesCopied": totalFilesCopied
                        ]
                    )
                }
            } catch {
                await MainActor.run {
                    // Only mark as failed if it's a genuine error, not just "no files to copy"
                    let errorMessage = error.localizedDescription
                    let noFilesToCopy = originals.totalFiles == 0 && pictures.totalFiles == 0
                    let allFilesCopied = (originals.filesCopied == originals.totalFiles) && (pictures.filesCopied == pictures.totalFiles)
                    let isSuccessCase = noFilesToCopy || (originals.filesCopied + pictures.filesCopied > 0 && allFilesCopied)
                    
                    hasError = !isSuccessCase
                    
                    if isSuccessCase {
                        statusMessage = "No new files to sync"
                        addLog("No new files to copy")
                        
                        let record = SyncRecord(
                            date: Date(),
                            filesTransferred: 0, // Always set to 0 when no new files are synced
                            success: true,
                            errorMessage: nil
                        )
                        settings.addSyncRecord(record)
                        
                        // Notify menu bar app of success (but no files copied)
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SyncCompleted"),
                            object: nil,
                            userInfo: [
                                "totalFilesCopied": 0
                            ]
                        )
                    } else {
                        statusMessage = "Sync failed"
                        addLog("Error: \(errorMessage)")
                        
                        let record = SyncRecord(
                            date: Date(),
                            filesTransferred: originals.filesCopied + pictures.filesCopied,
                            success: false,
                            errorMessage: errorMessage
                        )
                        settings.addSyncRecord(record)
                        
                        // Notify menu bar app that sync failed
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SyncFailed"),
                            object: nil,
                            userInfo: [
                                "errorMessage": errorMessage
                            ]
                        )
                    }
                    
                    isLoading = false
                }
            }
        }
    }
    
    // Helper function to add timestamped logs
    private func addLog(_ message: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())
        syncLogs.append("[\(timestamp)] \(message)")
    }
    
    // Sync both folders
    private func performSync() async throws -> Int {
        // Create FileManager
        let fileManager = FileManager.default
        
        // First check if we can get the correct Photo Booth directories
        let (originalsPath, picturesPath) = FileAccessManager.shared.getCorrectPhotoBooth()
        
        // Log which directories we're checking
        addLog("Checking for Photo Booth files in:")
        addLog("- Originals: \(originalsPath)")
        addLog("- Pictures: \(picturesPath)")
        
        // Check which directories exist and have access
        let originalsExists = fileManager.fileExists(atPath: originalsPath)
        let picturesExists = fileManager.fileExists(atPath: picturesPath)
        
        addLog("Directory exists check - Originals: \(originalsExists), Pictures: \(picturesExists)")
        
        // Ensure at least one directory exists
        if !originalsExists && !picturesExists {
            addLog("ERROR: No Photo Booth directories available")
            throw NSError(domain: "CloudBooth", code: 1, userInfo: [NSLocalizedDescriptionKey: "No Photo Booth directories available"])
        }
        
        // For destination, either use iCloud or custom location
        let destinationBase: String
        
        if settings.useCustomDestination, let customPath = settings.customDestinationPath {
            destinationBase = customPath
            addLog("Using custom destination: \(customPath)")
        } else {
            let iCloudDir = FileAccessManager.shared.getICloudDirectory()
            addLog("Using iCloud destination: \(iCloudDir)")
            destinationBase = iCloudDir
        }
        
        let cloudBoothFolder = "\(destinationBase)/CloudBooth"
        addLog("Creating destination folder: \(cloudBoothFolder)")
        
        // Create the main CloudBooth folder if it doesn't exist
        if !fileManager.fileExists(atPath: cloudBoothFolder) {
            try fileManager.createDirectory(atPath: cloudBoothFolder, withIntermediateDirectories: true)
            addLog("Created CloudBooth directory in destination")
        }
        
        // Create tasks to sync available folders
        var originalsTask: Task<Int, Error>?
        var picturesTask: Task<Int, Error>?
        
        if originalsExists {
            addLog("Starting sync for Originals folder: \(originalsPath)")
            originalsTask = Task {
                return try await syncFolder(
                    sourceFolder: originalsPath,
                    destFolder: "\(cloudBoothFolder)/Originals",
                    updateStats: { stats in
                        await MainActor.run {
                            originals = stats
                            
                            // Send progress update to menu bar
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SyncProgress"),
                                object: nil,
                                userInfo: [
                                    "originalsCount": stats.filesCopied,
                                    "picturesCount": pictures.filesCopied,
                                    "originalsTotal": stats.totalFiles,
                                    "picturesTotal": pictures.totalFiles
                                ]
                            )
                        }
                    }
                )
            }
        }
        
        if picturesExists {
            addLog("Starting sync for Pictures folder: \(picturesPath)")
            picturesTask = Task {
                return try await syncFolder(
                    sourceFolder: picturesPath,
                    destFolder: "\(cloudBoothFolder)/Pictures",
                    updateStats: { stats in
                        await MainActor.run {
                            pictures = stats
                            
                            // Send progress update to menu bar
                            NotificationCenter.default.post(
                                name: NSNotification.Name("SyncProgress"),
                                object: nil,
                                userInfo: [
                                    "originalsCount": originals.filesCopied,
                                    "picturesCount": stats.filesCopied,
                                    "originalsTotal": originals.totalFiles,
                                    "picturesTotal": stats.totalFiles
                                ]
                            )
                        }
                    }
                )
            }
        }
        
        // Wait for tasks to complete and get the total number of files copied
        var originalsCount = 0
        var picturesCount = 0
        
        if let task = originalsTask {
            do {
                originalsCount = try await task.value
                addLog("Originals sync complete: \(originalsCount) files copied")
            } catch {
                // Don't throw an error if it's just because there were no files to copy
                if error.localizedDescription.contains("No new files") {
                    addLog("No new files to copy in Originals folder")
                } else {
                    addLog("Error syncing originals: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        if let task = picturesTask {
            do {
                picturesCount = try await task.value
                addLog("Pictures sync complete: \(picturesCount) files copied")
            } catch {
                // Don't throw an error if it's just because there were no files to copy
                if error.localizedDescription.contains("No new files") {
                    addLog("No new files to copy in Pictures folder")
                } else {
                    addLog("Error syncing pictures: \(error.localizedDescription)")
                    throw error
                }
            }
        }
        
        // Only throw if there was a real error and no files were copied
        if originalsCount == 0 && picturesCount == 0 && 
           (originalsTask != nil || picturesTask != nil) {
            // Check if both folders had no new files (not an error)
            let noNewFilesMessage = "No new files to copy"
            if syncLogs.filter({ $0.contains(noNewFilesMessage) }).count >= (originalsTask != nil && picturesTask != nil ? 2 : 1) {
                return 0 // Return 0 files copied, but don't throw an error
            }
            
            throw NSError(domain: "CloudBooth", code: 3, userInfo: [NSLocalizedDescriptionKey: "No files were synced"])
        }
        
        return originalsCount + picturesCount
    }
    
    // Sync a single folder
    private func syncFolder(
        sourceFolder: String,
        destFolder: String,
        updateStats: @escaping (SyncStats) async -> Void
    ) async throws -> Int {
        let fileManager = FileManager.default
        var stats = SyncStats()
        var filesCopied = 0
        var newFilesExist = false
        
        addLog("Started syncing from \(sourceFolder) to \(destFolder)")
        
        // Create destination directory if it doesn't exist
        if !fileManager.fileExists(atPath: destFolder) {
            try fileManager.createDirectory(atPath: destFolder, withIntermediateDirectories: true)
            addLog("Created destination directory: \(destFolder)")
        }
        
        // Get all files directly in the source directory
        do {
            let fileURLs = try fileManager.contentsOfDirectory(
                at: URL(fileURLWithPath: sourceFolder),
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )
            
            // Filter to only include files, not directories
            let files = fileURLs.filter { fileURL in
                do {
                    let resourceValues = try fileURL.resourceValues(forKeys: [.isDirectoryKey])
                    return resourceValues.isDirectory == false
                } catch {
                    addLog("Error checking if item is directory: \(error.localizedDescription)")
                    return false
                }
            }
            
            addLog("Found \(files.count) files in \(sourceFolder)")
            
            // Update the total count
            stats.totalFiles = files.count
            await updateStats(stats)
            
            // Count how many files need to be copied
            var filesToCopy = 0
            for fileURL in files {
                let fileName = fileURL.lastPathComponent
                let destinationFile = "\(destFolder)/\(fileName)"
                if !fileManager.fileExists(atPath: destinationFile) {
                    filesToCopy += 1
                    newFilesExist = true
                }
            }
            
            // If no new files to copy, return early
            if filesToCopy == 0 {
                addLog("No new files to copy in \(sourceFolder)")
                // Update stats to show we've "processed" all files
                stats.filesCopied = stats.totalFiles
                await updateStats(stats)
                return 0
            }
            
            addLog("\(filesToCopy) new files will be copied from \(sourceFolder)")
            
            // Copy each file
            for fileURL in files {
                let fileName = fileURL.lastPathComponent
                let destinationFile = "\(destFolder)/\(fileName)"
                
                // Skip if file already exists at destination
                if fileManager.fileExists(atPath: destinationFile) {
                    stats.filesCopied += 1
                    await updateStats(stats)
                    continue
                }
                
                do {
                    // Copy file
                    try fileManager.copyItem(at: fileURL, to: URL(fileURLWithPath: destinationFile))
                    addLog("Copied file: \(fileName)")
                    
                    // Update progress
                    stats.filesCopied += 1
                    filesCopied += 1
                    
                    await updateStats(stats)
                } catch {
                    addLog("Failed to copy \(fileName): \(error.localizedDescription)")
                    throw error
                }
                
                // Small delay to avoid overwhelming the system
                try await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
            }
            
            addLog("Completed syncing \(filesCopied) files from \(sourceFolder)")
            return filesCopied
            
        } catch {
            addLog("Error reading source directory: \(error.localizedDescription)")
            throw error
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Settings.shared)
}

// Log Viewer View
struct LogViewer: View {
    var logs: [String]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Sync Issue Diagnosis")
                    .font(.headline)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
            
            Divider()
            
            // Tab view for diagnostics and raw logs
            VStack {
                Picker("View", selection: $selectedTab) {
                    Text("Diagnostics").tag(0)
                    Text("Raw Logs").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.top, 8)
                
                if selectedTab == 0 {
                    diagnosticsView
                } else {
                    rawLogsView
                }
            }
            
            // Footer with clipboard button
            HStack {
                Spacer()
                
                Button("Copy to Clipboard") {
                    let logText = logs.joined(separator: "\n")
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(logText, forType: .string)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(logs.isEmpty)
            }
            .padding()
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 600, height: 400)
    }
    
    // Diagnostics tab
    private var diagnosticsView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                diagnosticSummary
                
                Divider()
                
                if let issue = detectIssue() {
                    issueView(issue)
                } else {
                    Text("No specific issue detected in logs.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 20)
                }
                
                Divider()
                
                Text("Troubleshooting Steps")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                troubleshootingSteps
            }
            .padding()
        }
    }
    
    // Raw logs tab
    private var rawLogsView: some View {
        ScrollView {
            if logs.isEmpty {
                VStack {
                    Spacer()
                    Text("No logs available")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(logs, id: \.self) { log in
                        Text(log)
                            .font(.system(.caption, design: .monospaced))
                            .padding(.vertical, 2)
                            .padding(.horizontal, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                log.contains("Error:") || log.contains("Failed") ?
                                Color.red.opacity(0.1) :
                                Color.clear
                            )
                    }
                }
                .padding()
            }
        }
    }
    
    // Summary of the sync attempt
    private var diagnosticSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Sync Attempt Summary")
                .font(.headline)
            
            Group {
                HStack {
                    Image(systemName: "calendar")
                        .frame(width: 24)
                    Text("Time: \(syncTime)")
                }
                
                HStack {
                    Image(systemName: "folder")
                        .frame(width: 24)
                    Text("Folders: \(foldersAttempted)")
                }
                
                HStack {
                    Image(systemName: "doc")
                        .frame(width: 24)
                    Text("Files processed: \(filesProcessed)")
                }
                
                HStack {
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                        .frame(width: 24)
                    Text("Result: Sync Failed")
                        .foregroundStyle(.red)
                }
            }
            .font(.callout)
        }
    }
    
    // Display detected issue with potential solution
    private func issueView(_ issue: SyncIssue) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Issue")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: issue.icon)
                        .foregroundStyle(issue.color)
                        .font(.title2)
                    
                    VStack(alignment: .leading) {
                        Text(issue.title)
                            .font(.title3)
                            .fontWeight(.semibold)
                        
                        Text(issue.description)
                            .font(.callout)
                            .foregroundStyle(.secondary)
                    }
                }
                
                if !issue.solution.isEmpty {
                    Text("Recommended Solution")
                        .font(.headline)
                        .padding(.top, 4)
                    
                    Text(issue.solution)
                        .font(.callout)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(issue.color.opacity(0.1))
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(issue.color.opacity(0.2), lineWidth: 1)
                }
            )
        }
    }
    
    // General troubleshooting steps
    private var troubleshootingSteps: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                bulletPoint("Check that Photo Booth is closed while syncing")
                bulletPoint("Make sure there are no locked/open files in Photo Booth")
                bulletPoint("Verify permissions for both folders in System Settings")
                bulletPoint("Make sure you have sufficient space on iCloud Drive")
                bulletPoint("Try restarting your Mac and try again")
            }
            .font(.callout)
        }
    }
    
    private func bulletPoint(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.body)
            Text(text)
            Spacer()
        }
    }
    
    // Helper to extract sync time from logs
    private var syncTime: String {
        guard let firstLog = logs.first else { return "Unknown" }
        if let timeString = firstLog.split(separator: "]").first?.dropFirst() {
            return String(timeString)
        }
        return "Unknown"
    }
    
    // Helper to extract folders attempted
    private var foldersAttempted: String {
        var folders = [String]()
        
        for log in logs {
            if log.contains("Started syncing from") {
                if let folderPath = log.split(separator: "from ").last?.split(separator: " to").first {
                    if let lastComponent = folderPath.split(separator: "/").last {
                        folders.append(String(lastComponent))
                    }
                }
            }
        }
        
        if folders.isEmpty {
            return "None"
        } else {
            return folders.joined(separator: ", ")
        }
    }
    
    // Helper to extract files processed
    private var filesProcessed: String {
        var fileCount = 0
        
        for log in logs {
            if log.contains("Copied file:") {
                fileCount += 1
            }
        }
        
        return "\(fileCount)"
    }
    
    // Automated issue detection logic
    private func detectIssue() -> SyncIssue? {
        // Join logs for easier searching
        let logText = logs.joined(separator: " ")
        
        // Check for permission issues
        if logText.contains("Permission denied") || logText.contains("Error: Operation not permitted") {
            return SyncIssue(
                icon: "lock.shield",
                color: .red,
                title: "Permission Error",
                description: "CloudBooth doesn't have permission to access one or more required folders.",
                solution: "Click the 'Refresh Permissions' option in the app menu or manually grant access to both Photo Booth and iCloud folders in System Settings > Privacy & Security > Files and Folders."
            )
        }
        
        // Check for space issues
        if logText.contains("No space left on device") || logText.contains("There isn't enough space") {
            return SyncIssue(
                icon: "disk.full",
                color: .orange,
                title: "Storage Space Issue",
                description: "Not enough space available on iCloud Drive to complete the sync operation.",
                solution: "Free up space in your iCloud Drive by deleting unneeded files, or upgrade your iCloud storage plan."
            )
        }
        
        // Check for file locked/in-use issues
        if logText.contains("Resource busy") || logText.contains("file is in use") || logText.contains("locked") {
            return SyncIssue(
                icon: "lock.doc",
                color: .orange,
                title: "Files In Use",
                description: "Some files in Photo Booth are currently in use or locked by another application.",
                solution: "Close Photo Booth and any other applications that might be using these files, then try again."
            )
        }
        
        // Check for network issues with iCloud
        if logText.contains("Error:") && (logText.contains("iCloud") || logText.contains("network")) {
            return SyncIssue(
                icon: "wifi.exclamationmark",
                color: .red,
                title: "iCloud Connectivity Issue",
                description: "There was a problem connecting to iCloud or your network connection was interrupted.",
                solution: "Check your internet connection and make sure iCloud Drive is enabled and working properly in System Settings."
            )
        }
        
        // Check if no files found
        if logText.contains("Found 0 files") {
            return SyncIssue(
                icon: "questionmark.folder",
                color: .blue,
                title: "No Photos Found",
                description: "No photos were found in your Photo Booth folders.",
                solution: "Verify that you have taken photos with Photo Booth and they are saved in the expected location."
            )
        }
        
        // Check if folders don't exist
        if logText.contains("No Photo Booth directories available") {
            return SyncIssue(
                icon: "folder.badge.questionmark",
                color: .red,
                title: "Photo Booth Folders Not Found",
                description: "The standard Photo Booth folders could not be found on your Mac.",
                solution: "Make sure Photo Booth has been used at least once on this Mac, or manually locate your Photo Booth Library folder."
            )
        }
        
        // Generic error fallback
        if logText.contains("Error:") || logText.contains("Failed") {
            return SyncIssue(
                icon: "exclamationmark.triangle",
                color: .orange,
                title: "Sync Operation Failed",
                description: "The sync operation encountered an error that could not be specifically identified.",
                solution: "Check the raw logs for more details about the error and try the general troubleshooting steps below."
            )
        }
        
        return nil
    }
}

// Model for representing a sync issue with recommended solutions
struct SyncIssue {
    var icon: String
    var color: Color
    var title: String
    var description: String
    var solution: String
} 