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
    @State private var showAttributionSheet = false
    
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
            Button("Retry") {
                resetAndCheckPermissions()
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("CloudBooth needs access to your Photo Booth and iCloud Drive folders. Please grant access when prompted. If you've already granted permission, click Retry.")
        }
        .sheet(isPresented: $showSettingsSheet) {
            SettingsView()
        }
        .sheet(isPresented: $showHistorySheet) {
            HistoryView()
        }
        .sheet(isPresented: $showAttributionSheet) {
            AttributionView()
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
            
            // Visible attribution
            HStack(spacing: 4) {
                Text("By")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Link(destination: URL(string: "https://github.com/Navaneeth-Git")!) {
                    Text("Navaneeth")
                        .font(.caption)
                        .foregroundColor(.blue)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(nsColor: .controlBackgroundColor))
            .cornerRadius(12)
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
                .onChange(of: isLoading) { _, newValue in
                    animateUpload = newValue
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
            
            // Debug button (TEMPORARY)
            Button(action: {
                Task {
                    await debugICloudAccess()
                }
            }) {
                Image(systemName: "ladybug")
                    .font(.title3)
            }
            .buttonStyle(.borderless)
            .help("Debug iCloud Access")
            
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
            let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
            
            if !hasAccess {
                await MainActor.run {
                    showPermissionAlert = true
                }
            } else {
                print("✅ All permissions granted successfully")
                // If permissions are granted, reset the alert state
                await MainActor.run {
                    showPermissionAlert = false
                }
            }
        }
    }
    
    // Reset permissions and check again
    private func resetAndCheckPermissions() {
        Task {
            FileAccessManager.shared.resetAllBookmarks()
            await Task.yield()
            checkPermissions()
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
        Task {
            // First check for permissions
            let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
            if !hasAccess {
                await MainActor.run {
                    showPermissionAlert = true
                    
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
                    
                    let record = SyncRecord(
                        date: Date(),
                        filesTransferred: originals.filesCopied + pictures.filesCopied,
                        success: false,
                        errorMessage: error.localizedDescription
                    )
                    settings.addSyncRecord(record)
                    
                    isLoading = false
                    
                    // Notify menu bar app that sync failed
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
        // Create FileManager
        let fileManager = FileManager.default
        
        // Get base destination directory (either iCloud or custom location)
        let destinationBase: String
        if settings.useCustomDestination, let customPath = settings.customDestinationPath {
            destinationBase = customPath
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
                        print("🔍 Using security-scoped bookmarked iCloud path for sync: \(url.path)")
                        destinationBase = url.path
                        defer { url.stopAccessingSecurityScopedResource() }
                    } else {
                        // Fall back to direct path
                        let directiCloudURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
                        destinationBase = directiCloudURL.path
                    }
                } catch {
                    print("❌ Failed to use iCloud bookmark for sync: \(error.localizedDescription)")
                    // Fall back to direct path
                    let directiCloudURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
                    destinationBase = directiCloudURL.path
                }
            } else {
                // Direct path to iCloud Drive
                let directiCloudURL = fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
                destinationBase = directiCloudURL.path
            }
        }
        
        print("📂 Destination base path: \(destinationBase)")
        
        // Verify the destination base path exists and is accessible
        var isDirectory: ObjCBool = false
        if !fileManager.fileExists(atPath: destinationBase, isDirectory: &isDirectory) || !isDirectory.boolValue {
            print("❌ Destination base path doesn't exist or isn't a directory")
            throw NSError(domain: "CloudBoothError", code: 1002, userInfo: [
                NSLocalizedDescriptionKey: "iCloud Drive location is invalid: \(destinationBase)"
            ])
        }
        
        let cloudBoothFolder = "\(destinationBase)/CloudBooth"
        
        print("📂 Syncing to: \(cloudBoothFolder)")
        
        // Create the main CloudBooth folder if it doesn't exist
        if !fileManager.fileExists(atPath: cloudBoothFolder) {
            do {
                print("📁 Creating CloudBooth folder at \(cloudBoothFolder)")
                try fileManager.createDirectory(atPath: cloudBoothFolder, withIntermediateDirectories: true, attributes: nil)
                print("✅ Created successfully")
                
                // Verify folder was created
                if !fileManager.fileExists(atPath: cloudBoothFolder) {
                    print("⚠️ Folder appears not to exist after creation")
                    throw NSError(domain: "CloudBoothError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Failed to create CloudBooth folder: Folder doesn't exist after creation"])
                }
            } catch {
                print("❌ Error creating CloudBooth folder: \(error.localizedDescription)")
                throw error
            }
        } else {
            print("✅ CloudBooth folder already exists")
            
            // Verify we have access to it
            do {
                let _ = try fileManager.contentsOfDirectory(atPath: cloudBoothFolder)
                print("✅ Successfully accessed CloudBooth folder")
            } catch {
                print("❌ Cannot access CloudBooth folder: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Verify/create Originals and Pictures folders
        let originalsFolder = "\(cloudBoothFolder)/Originals"
        let picturesFolder = "\(cloudBoothFolder)/Pictures"
        
        // Create Originals folder if needed
        if !fileManager.fileExists(atPath: originalsFolder) {
            do {
                print("📁 Creating Originals folder")
                try fileManager.createDirectory(atPath: originalsFolder, withIntermediateDirectories: true)
            } catch {
                print("❌ Error creating Originals folder: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Create Pictures folder if needed
        if !fileManager.fileExists(atPath: picturesFolder) {
            do {
                print("📁 Creating Pictures folder")
                try fileManager.createDirectory(atPath: picturesFolder, withIntermediateDirectories: true)
            } catch {
                print("❌ Error creating Pictures folder: \(error.localizedDescription)")
                throw error
            }
        }
        
        // Create tasks to sync both folders in parallel
        async let originalsTask = syncFolder(
            sourceFolder: FileAccessManager.shared.photoBooth(subFolder: "Originals").path,
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
        
        async let picturesTask = syncFolder(
            sourceFolder: FileAccessManager.shared.photoBooth(subFolder: "Pictures").path,
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
        
        // Wait for both tasks to complete and get the total number of files copied
        let originalsCount = try await originalsTask
        let picturesCount = try await picturesTask
        
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
        
        // Create destination directory if it doesn't exist
        if !fileManager.fileExists(atPath: destFolder) {
            try fileManager.createDirectory(atPath: destFolder, withIntermediateDirectories: true)
        }
        
        // Get all files in source directory
        let files = try fileManager.contentsOfDirectory(atPath: sourceFolder)
        
        // Update the total count
        stats.totalFiles = files.count
        await updateStats(stats)
        
        // Copy each file
        for file in files {
            // Skip .DS_Store and other hidden files
            if file.starts(with: ".") {
                stats.filesCopied += 1
                await updateStats(stats)
                continue
            }
            
            let sourceFile = "\(sourceFolder)/\(file)"
            let destinationFile = "\(destFolder)/\(file)"
            
            // Skip if file already exists at destination
            if fileManager.fileExists(atPath: destinationFile) {
                stats.filesCopied += 1
                await updateStats(stats)
                continue
            }
            
            // Copy file
            try fileManager.copyItem(atPath: sourceFile, toPath: destinationFile)
            
            // Update progress
            stats.filesCopied += 1
            filesCopied += 1
            
            await updateStats(stats)
            
            // Small delay to avoid overwhelming the system
            try await Task.sleep(nanoseconds: 50_000_000) // 0.05 second
        }
        
        return filesCopied
    }
    
    // Debug function to test iCloud access
    private func debugICloudAccess() async {
        // Update status to indicate we're debugging
        await MainActor.run {
            statusMessage = "Testing iCloud access..."
        }
        
        // Check for security-scoped bookmark
        let hasBookmark = UserDefaults.standard.data(forKey: "iCloudBookmarkData") != nil
        var bookmarkPath = "None"
        
        if hasBookmark {
            if let bookmarkData = UserDefaults.standard.data(forKey: "iCloudBookmarkData") {
                do {
                    var isStale = false
                    let url = try URL(resolvingBookmarkData: bookmarkData, 
                                      options: [.withSecurityScope], 
                                      relativeTo: nil, 
                                      bookmarkDataIsStale: &isStale)
                    
                    bookmarkPath = url.path
                } catch {
                    bookmarkPath = "Error: \(error.localizedDescription)"
                }
            }
        }
        
        // Get the direct iCloud path
        let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        
        // Also get the sandbox container path for comparison
        let containerPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        let containerICloudPath: String
        if let containerURL = containerPath?.deletingLastPathComponent().appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs") {
            containerICloudPath = containerURL.path
        } else {
            containerICloudPath = "Not available"
        }
        
        // Compose a user-friendly message
        let debugMessage = """
        Direct iCloud Path:
        \(directiCloudURL.path)
        
        Security-scoped bookmark available: \(hasBookmark)
        Bookmark path: \(bookmarkPath)
        
        Container iCloud path (for reference):
        \(containerICloudPath)
        
        The app will now use the direct iCloud path.
        """
        
        await MainActor.run {
            statusMessage = debugMessage
            print(debugMessage)
        }
        
        // Check if iCloud Drive is available using direct path
        var directPathAccessible = false
        do {
            let _ = try FileManager.default.contentsOfDirectory(at: directiCloudURL, includingPropertiesForKeys: nil)
            directPathAccessible = true
        } catch {
            print("❌ Cannot access direct iCloud path: \(error.localizedDescription)")
        }
        
        await MainActor.run {
            statusMessage += "\n\nDirect iCloud path accessible: \(directPathAccessible)"
        }
        
        // Get the destination path for saving files
        let destinationPath = settings.getDestinationBasePath()
        
        await MainActor.run {
            statusMessage += "\n\nSaving files to: \(destinationPath)"
        }
        
        // Check CloudBooth folder
        let cloudBoothFolder = "\(destinationPath)/CloudBooth"
        let cloudBoothExists = FileManager.default.fileExists(atPath: cloudBoothFolder)
        
        await MainActor.run {
            statusMessage += "\nCloudBooth folder exists: \(cloudBoothExists)"
            
            // Test the photo booth path as well
            let photoBoothOriginals = FileAccessManager.shared.photoBooth(subFolder: "Originals").path
            statusMessage += "\nPhoto Booth Originals: \(photoBoothOriginals)"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(Settings.shared)
} 