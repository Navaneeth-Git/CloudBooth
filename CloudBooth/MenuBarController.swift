import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var cancellables = Set<AnyCancellable>()
    
    // Track if we're active to prevent deallocation
    static let shared = MenuBarController()
    
    @Published var isPopoverShown = false
    
    init() {
        setupStatusItem()
        
        // Keep a reference to prevent garbage collection
        DispatchQueue.main.async {
            _ = Self.shared
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    private func setupStatusItem() {
        // Ensure we have a persistent status item that won't disappear
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "icloud", accessibilityDescription: "CloudBooth")
            button.action = #selector(togglePopover)
            button.target = self
        }
        
        // Set notification observer to ensure we respond to app activation
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidBecomeActive),
            name: NSApplication.didBecomeActiveNotification,
            object: nil
        )
    }
    
    @objc private func applicationDidBecomeActive() {
        // Ensure our status item is visible when app becomes active
        if statusItem == nil {
            setupStatusItem()
        }
    }
    
    @objc private func togglePopover() {
        if popover == nil {
            popover = NSPopover()
            popover?.contentSize = NSSize(width: 320, height: 280)
            popover?.behavior = .transient
            popover?.contentViewController = NSHostingController(rootView: MenuBarView().environmentObject(Settings.shared))
        }
        
        if let popover = popover, let button = statusItem?.button {
            if popover.isShown {
                popover.close()
                isPopoverShown = false
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                isPopoverShown = true
                
                // Close when clicking outside
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
    
    // Method to update the status item icon
    func updateStatusIcon(isLoading: Bool) {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: isLoading ? "arrow.triangle.2.circlepath" : "icloud",
                accessibilityDescription: "CloudBooth"
            )
        } else {
            // Recreate status item if it disappeared
            setupStatusItem()
            
            if let button = statusItem?.button {
                button.image = NSImage(
                    systemSymbolName: isLoading ? "arrow.triangle.2.circlepath" : "icloud",
                    accessibilityDescription: "CloudBooth"
                )
            }
        }
    }
    
    // Method to add a badge showing successful sync
    func showSuccessIndicator() {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "icloud.fill",
                accessibilityDescription: "CloudBooth - Sync Successful"
            )
            
            // Reset after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if let button = self?.statusItem?.button {
                    button.image = NSImage(
                        systemSymbolName: "icloud",
                        accessibilityDescription: "CloudBooth"
                    )
                } else {
                    // Recreate if needed
                    self?.setupStatusItem()
                }
            }
        } else {
            // Recreate status item if it disappeared
            setupStatusItem()
        }
    }
    
    // Method to show an error indicator
    func showErrorIndicator() {
        if let button = statusItem?.button {
            button.image = NSImage(
                systemSymbolName: "exclamationmark.circle",
                accessibilityDescription: "CloudBooth - Sync Failed"
            )
            
            // Reset after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { [weak self] in
                if let button = self?.statusItem?.button {
                    button.image = NSImage(
                        systemSymbolName: "icloud",
                        accessibilityDescription: "CloudBooth"
                    )
                } else {
                    // Recreate if needed
                    self?.setupStatusItem()
                }
            }
        } else {
            // Recreate status item if it disappeared
            setupStatusItem()
        }
    }
}

// The actual menu bar view content
struct MenuBarView: View {
    @EnvironmentObject var settings: Settings
    @State private var isLoading = false
    @State private var statusMessage = "Ready to sync"
    @State private var originals = SyncStats()
    @State private var pictures = SyncStats()
    @State private var animateUpload = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                ZStack {
                    Image(systemName: "icloud")
                        .font(.headline)
                        .opacity(isLoading ? (animateUpload ? 0.4 : 1.0) : 1.0)
                        .animation(isLoading ? Animation.easeInOut(duration: 0.7).repeatForever(autoreverses: true) : .default, value: animateUpload)
                }
                .onAppear {
                    if isLoading { animateUpload = true }
                }
                .onChange(of: isLoading) { _, newValue in
                    if newValue {
                        withAnimation(.easeInOut(duration: 0.7).repeatForever()) {
                            animateUpload.toggle()
                        }
                    } else {
                        animateUpload = false
                    }
                }
                Text("CloudBooth")
                    .font(.headline)
                
                Spacer()
                
                Button {
                    NSApp.activate(ignoringOtherApps: true)
                    let app = NSApplication.shared
                    app.activate(ignoringOtherApps: true)
                    if let mainWindow = app.windows.first(where: { $0.title == "CloudBooth" }) {
                        mainWindow.makeKeyAndOrderFront(nil)
                    } else {
                        // No main window found, create one
                        let contentWindow = NSWindow(
                            contentRect: NSRect(x: 0, y: 0, width: 480, height: 600),
                            styleMask: [.titled, .closable, .miniaturizable],
                            backing: .buffered,
                            defer: false
                        )
                        contentWindow.title = "CloudBooth"
                        contentWindow.center()
                        contentWindow.isRestorable = false
                        contentWindow.contentView = NSHostingView(rootView: ContentView().environmentObject(Settings.shared).alwaysOnTop())
                        contentWindow.level = .floating
                        let windowController = NSWindowController(window: contentWindow)
                        windowController.showWindow(nil)
                    }
                } label: {
                    Text("Open App")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding([.horizontal, .top])
            
            Divider()
            
            // Sync status and controls
            VStack(spacing: 14) {
                if isLoading {
                    // Show sync progress
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .foregroundStyle(.blue)
                        
                        Text(statusMessage)
                            .font(.subheadline)
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Progress indicators
                    VStack(spacing: 10) {
                        progressBar(label: "Original Photos", stats: originals, color: .orange)
                        progressBar(label: "Edited Photos", stats: pictures, color: .blue)
                    }
                    .padding(.horizontal)
                } else {
                    // Show last sync info
                    HStack {
                        Image(systemName: "clock.arrow.2.circlepath")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                        
                        if let lastSync = settings.lastSyncDate {
                            Text("Last sync: \(lastSync, formatter: dateFormatter)")
                                .font(.subheadline)
                        } else {
                            Text("No sync history")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.horizontal)
                    
                    // Next scheduled sync if available
                    if let nextSync = settings.nextScheduledSync, settings.autoSyncInterval != .never, settings.autoSyncInterval != .onNewPhotos {
                        HStack {
                            Image(systemName: "calendar.badge.clock")
                                .foregroundStyle(.blue)
                                .font(.subheadline)
                            
                            Text("Next sync: \(nextSync, formatter: dateFormatter)")
                                .font(.subheadline)
                            
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Sync button
                Button {
                    NotificationCenter.default.post(name: Notification.Name("SyncNowRequested"), object: nil)
                } label: {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(isLoading)
                .padding(.horizontal)
                
                // Show history button
                Button {
                    NotificationCenter.default.post(name: Notification.Name("ShowHistoryRequested"), object: nil)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("Show History")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .disabled(isLoading)
                .padding(.horizontal)
            }
            
            Divider()
            
            // Auto-sync info
            if settings.autoSyncInterval != .never {
                HStack {
                    Image(systemName: "clock.arrow.2.circlepath")
                        .foregroundStyle(.secondary)
                        .font(.caption)
                    
                    Text("Auto-sync: \(settings.autoSyncInterval.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }

            Divider()

            // Quit button
            Button(role: .destructive) {
                NSApp.terminate(nil)
            } label: {
                HStack {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                    Text("Quit CloudBooth")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .padding([.horizontal, .bottom])
        }
        .frame(width: 320)
        .onAppear {
            setupNotifications()
        }
        .onDisappear {
            removeNotifications()
        }
    }
    
    private func progressBar(label: String, stats: SyncStats, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            
            if stats.totalFiles > 0 {
                HStack {
                    ProgressView(value: Double(stats.filesCopied), total: Double(stats.totalFiles))
                        .progressViewStyle(.linear)
                        .tint(color)
                    
                    Text("\(stats.filesCopied)/\(stats.totalFiles)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            } else {
                HStack {
                    ProgressView()
                        .progressViewStyle(.linear)
                        .tint(color)
                    
                    Text("Preparing...")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    // Format dates consistently
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
    
    // Set up notification observers
    @MainActor
    private func setupNotifications() {
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncStarted"),
            object: nil,
            queue: .main
        ) { notification in
            // Extract the data immediately
            var originalsTotal = 0
            var picturesTotal = 0
            
            if let userInfo = notification.userInfo {
                if let count = userInfo["originalsCount"] as? Int {
                    originalsTotal = count
                }
                if let count = userInfo["picturesCount"] as? Int {
                    picturesTotal = count
                }
            }
            
            // Use the extracted data
            Task { @MainActor in
                isLoading = true
                statusMessage = "Syncing..."
                originals.totalFiles = originalsTotal
                pictures.totalFiles = picturesTotal
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncProgress"),
            object: nil,
            queue: .main
        ) { notification in
            // Extract the data immediately
            var originalsCount = 0
            var picturesCount = 0
            
            if let userInfo = notification.userInfo {
                if let count = userInfo["originalsCount"] as? Int {
                    originalsCount = count
                }
                if let count = userInfo["picturesCount"] as? Int {
                    picturesCount = count
                }
            }
            
            // Use the extracted data
            Task { @MainActor in
                originals.filesCopied = originalsCount
                pictures.filesCopied = picturesCount
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncCompleted"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                isLoading = false
                statusMessage = "Sync completed"
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncFailed"),
            object: nil,
            queue: .main
        ) { notification in
            // Extract the data immediately
            var errorMsg = "Sync failed"
            
            if let userInfo = notification.userInfo {
                if let message = userInfo["errorMessage"] as? String {
                    errorMsg = "Sync failed: \(message)"
                }
            }
            
            // Use the extracted data
            Task { @MainActor in
                isLoading = false
                statusMessage = errorMsg
            }
        }
    }
    
    // Remove notification observers
    private func removeNotifications() {
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SyncStarted"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SyncProgress"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SyncCompleted"),
            object: nil
        )
        
        NotificationCenter.default.removeObserver(
            self,
            name: NSNotification.Name("SyncFailed"),
            object: nil
        )
    }
}

extension View {
    func alwaysOnTop() -> some View {
        self.background(WindowAccessor())
    }
}

struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let nsView = NSView()
        DispatchQueue.main.async {
            if let window = nsView.window {
                window.level = .statusBar // or .mainMenu for even higher
                window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            }
        }
        return nsView
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
} 