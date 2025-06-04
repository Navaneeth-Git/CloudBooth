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
    
    var body: some View {
        VStack(spacing: 0) {
            // Elegant macOS-styled attribution
            HStack {
                Spacer()
                HStack(spacing: 3) {
                    Text("Crafted by")
                        .foregroundColor(.secondary)
                    Link("Navaneeth", destination: URL(string: "https://github.com/Navaneeth-Git")!)
                        .foregroundColor(.blue)
                }
                .font(.system(size: 12))
                .padding(.vertical, 4)
                .padding(.horizontal, 12)
                .background(
                    Capsule()
                        .fill(Color(NSColor.controlBackgroundColor))
                        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
                )
                .padding(.top, 6)
                .padding(.trailing, 12)
            }
            
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
        .onAppear {
            Task {
                let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
                if !hasAccess {
                    // Reset bookmarks to force a fresh permission request on first launch
                    FileAccessManager.shared.resetAllBookmarks()
                    
                    // Try again immediately with a fresh request
                    _ = await FileAccessManager.shared.ensureDirectoryAccess()
                    
                    // Even if it fails the second time, don't show alert on launch
                    // The alert will show when they try to sync
                }
            }
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
                .onChange(of: isLoading) { _, _ in
                    animateUpload = isLoading
                }
        }
        .padding()
    }
    
    private var statusCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status header
            HStack {
                Image(systemName: isLoading ? "icloud" : "checkmark.circle.fill")
                    .font(.title2)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(isLoading ? .blue : .green)
                    .opacity(isLoading ? (animateUpload ? 0.4 : 1.0) : 1.0)
                    .animation(isLoading ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: animateUpload)
                
                Text(statusMessage)
                    .font(.headline)
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
                        VStack(alignment: .leading, spacing: 4) {
                            Text(error)
                                .font(.caption)
                                .foregroundStyle(.red)
                            
                            if error.localizedCaseInsensitiveContains("permission") || error.localizedCaseInsensitiveContains("denied") || error.localizedCaseInsensitiveContains("access") {
                                Text("Click 'Sync Now' again to grant permissions")
                                    .font(.caption)
                                    .foregroundStyle(.orange)
                            }
                        }
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
                .fill(Color.green.opacity(0.15))
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
                    
                    Text("Originals & Pictures")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Image(systemName: "arrow.forward")
                    .font(.body)
                    .foregroundStyle(.secondary)
                
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Image(systemName: "folder.badge.gearshape")
                            .foregroundStyle(.blue)
                        Text("Destination")
                            .font(.subheadline)
                            .fontWeight(.medium)
                    }
                    
                    Text("iCloud Drive")
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
            print("[AutoSync] Received AutoSyncRequested notification. Triggering syncPhotos(isAutoSync: true)")
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
        Task {
            // First check for permissions
            let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
            if !hasAccess {
                // Reset bookmarks to force a fresh permission request
                FileAccessManager.shared.resetAllBookmarks()
                
                // Try again immediately to get permissions with a fresh request
                let retryAccess = await FileAccessManager.shared.ensureDirectoryAccess()
                
                if !retryAccess {
                    // Only if the second attempt fails, show alert and record failure
                    await MainActor.run {
                        showPermissionAlert = true
                        
                        if isAutoSync {
                            let record = SyncRecord(
                                date: Date(),
                                filesTransferred: 0,
                                success: false,
                                errorMessage: "Permission denied. Click 'Sync Now' to grant access."
                            )
                            settings.addSyncRecord(record)
                        }
                        
                        // Notify menu bar app of sync failure
                        NotificationCenter.default.post(
                            name: NSNotification.Name("SyncFailed"),
                            object: nil,
                            userInfo: ["errorMessage": "Permission denied. Click 'Sync Now' to grant access."]
                        )
                    }
                    return
                }
                // If we got here, permission was granted on second attempt, continue with sync
            }
            
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
                    statusMessage = "Sync completed successfully"
                    
                    let record = SyncRecord(
                        date: Date(),
                        filesTransferred: totalFilesCopied,
                        success: true
                    )
                    settings.addSyncRecord(record)
                    
                    isLoading = false
                    
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
                    statusMessage = "Sync failed"
                    if error.localizedDescription.localizedCaseInsensitiveContains("permission") || error.localizedDescription.localizedCaseInsensitiveContains("denied") {
                        FileAccessManager.shared.resetAllBookmarks()
                        statusMessage = "Permissions needed. Click 'Sync Now' again to grant access."
                    }
                    let record = SyncRecord(
                        date: Date(),
                        filesTransferred: originals.filesCopied + pictures.filesCopied,
                        success: false,
                        errorMessage: error.localizedDescription.localizedCaseInsensitiveContains("permission") || error.localizedDescription.localizedCaseInsensitiveContains("denied") ? 
                                     "Permissions needed. Click 'Sync Now' to grant access." : error.localizedDescription
                    )
                    settings.addSyncRecord(record)
                    isLoading = false
                    NotificationCenter.default.post(
                        name: NSNotification.Name("SyncFailed"),
                        object: nil,
                        userInfo: [
                            "errorMessage": error.localizedDescription
                        ]
                    )
                }
            }
        }
    }
    
    // Sync both folders
    private func performSync() async throws -> Int {
        let fileManager = FileManager.default
        guard let destinationURL = FileAccessManager.shared.resolvedDestinationURL() else {
            throw NSError(domain: "CloudBooth", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud Drive access"]) 
        }
        let accessGranted = destinationURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { destinationURL.stopAccessingSecurityScopedResource() }
        }
        let cloudBoothFolderURL = destinationURL.appendingPathComponent("CloudBooth")
        if !fileManager.fileExists(atPath: cloudBoothFolderURL.path) {
            try fileManager.createDirectory(at: cloudBoothFolderURL, withIntermediateDirectories: true)
        }
        async let originalsTask = syncFolder(
            sourceFolder: "/Users/navaneeth/Pictures/Photo Booth Library/Originals",
            destFolderURL: cloudBoothFolderURL.appendingPathComponent("Originals"),
            updateStats: { stats in
                await MainActor.run {
                    originals = stats
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
        async let picturesTask = syncFolder(
            sourceFolder: "/Users/navaneeth/Pictures/Photo Booth Library/Pictures",
            destFolderURL: cloudBoothFolderURL.appendingPathComponent("Pictures"),
            updateStats: { stats in
                await MainActor.run {
                    pictures = stats
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
        let originalsCount = try await originalsTask
        let picturesCount = try await picturesTask
        return originalsCount + picturesCount
    }
    
    // Sync a single folder
    private func syncFolder(
        sourceFolder: String,
        destFolderURL: URL,
        updateStats: @escaping (SyncStats) async -> Void
    ) async throws -> Int {
        let fileManager = FileManager.default
        guard let destinationURL = FileAccessManager.shared.resolvedDestinationURL() else {
            throw NSError(domain: "CloudBooth", code: 1, userInfo: [NSLocalizedDescriptionKey: "No iCloud Drive access"]) 
        }
        let accessGranted = destinationURL.startAccessingSecurityScopedResource()
        defer {
            if accessGranted { destinationURL.stopAccessingSecurityScopedResource() }
        }
        var stats = SyncStats()
        var filesCopied = 0
        if !fileManager.fileExists(atPath: destFolderURL.path) {
            try fileManager.createDirectory(at: destFolderURL, withIntermediateDirectories: true)
        }
        let files = try fileManager.contentsOfDirectory(atPath: sourceFolder)
        stats.totalFiles = files.count
        await updateStats(stats)
        for file in files {
            if file.starts(with: ".") {
                stats.filesCopied += 1
                await updateStats(stats)
                continue
            }
            let sourceFileURL = URL(fileURLWithPath: sourceFolder).appendingPathComponent(file)
            let destinationFileURL = destFolderURL.appendingPathComponent(file)
            if fileManager.fileExists(atPath: destinationFileURL.path) {
                stats.filesCopied += 1
                await updateStats(stats)
                continue
            }
            try fileManager.copyItem(at: sourceFileURL, to: destinationFileURL)
            stats.filesCopied += 1
            filesCopied += 1
            await updateStats(stats)
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return filesCopied
    }
}

#Preview {
    ContentView()
        .environmentObject(Settings.shared)
} 
