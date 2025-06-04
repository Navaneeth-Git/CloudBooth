import SwiftUI
import AppKit
import Combine

@MainActor
class MenuBarController: ObservableObject {
    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var popoverMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var eventMonitor: Any?
    
    // Track if we're active to prevent deallocation
    static let shared = MenuBarController()
    
    @Published var isPopoverShown = false
    
    init() {
        setupStatusItem()
        
        // Keep a reference to prevent garbage collection
        DispatchQueue.main.async {
            _ = Self.shared
        }
        
        // Set up a periodic check to ensure the status item persists
        Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.ensureStatusItemExists()
        }
        
        // Monitor workspace notifications to handle screen changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(screenParametersChanged),
            name: NSApplication.didChangeScreenParametersNotification,
            object: nil
        )
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        
        // Clean up monitors
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        
        if let monitor = popoverMonitor {
            NSEvent.removeMonitor(monitor)
        }
    }
    
    // Handle screen configuration changes
    @objc private func screenParametersChanged() {
        // If popover is shown when screens change, close it to prevent display issues
        if let popover = popover, popover.isShown {
            popover.close()
            isPopoverShown = false
        }
        
        // Recreate status item to ensure it's on the right screen
        ensureStatusItemExists()
    }
    
    // Make sure our status item exists and is visible
    private func ensureStatusItemExists() {
        DispatchQueue.main.async {
            if self.statusItem == nil {
                self.setupStatusItem()
            } else if self.statusItem?.button?.superview == nil {
                // Status item exists but button isn't in view hierarchy - recreate
                self.setupStatusItem()
            }
        }
    }
    
    private func setupStatusItem() {
        // Remove existing item to prevent duplicates
        if let existingItem = statusItem {
            NSStatusBar.system.removeStatusItem(existingItem)
        }
        
        // Create a new status item with fixed width for stability
        // Use a slightly larger width for better visibility
        statusItem = NSStatusBar.system.statusItem(withLength: 30.0)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "icloud", accessibilityDescription: "CloudBooth")
            button.image?.size = NSSize(width: 18, height: 18)
            button.action = #selector(togglePopover)
            button.target = self
            
            // Ensure the button has proper appearance
            button.imagePosition = .imageOnly
            button.imageScaling = .scaleProportionallyDown
            
            // Add a more visible border for better identification
            button.wantsLayer = true
            button.layer?.cornerRadius = 4
            button.layer?.masksToBounds = true
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
        ensureStatusItemExists()
    }
    
    @objc private func togglePopover() {
        // First check if popover is already showing
        if let currentPopover = popover, currentPopover.isShown {
            currentPopover.close()
            isPopoverShown = false
            
            // Reset button appearance
            if let button = statusItem?.button, button.wantsLayer {
                button.layer?.backgroundColor = nil
            }
            
            // Clean up monitor
            if let monitor = popoverMonitor {
                NSEvent.removeMonitor(monitor)
                popoverMonitor = nil
            }
            
            return
        }
        
        // Clean up any existing monitors
        if let monitor = popoverMonitor {
            NSEvent.removeMonitor(monitor)
            popoverMonitor = nil
        }
        
        // Create a fresh popover each time to avoid stale references
        popover = NSPopover()
        popover?.contentSize = NSSize(width: 320, height: 320)
        // Use applicationDefined behavior for better control
        popover?.behavior = .applicationDefined
        popover?.contentViewController = NSHostingController(rootView: MenuBarView().environmentObject(Settings.shared))
        
        if let popover = popover, let button = statusItem?.button {
            // Get the screen that contains the menubar icon
            let buttonWindow = button.window
            let buttonFrame = button.convert(button.bounds, to: nil)
            let buttonScreenPoint = buttonWindow?.convertPoint(toScreen: buttonFrame.origin) ?? .zero
            let menuBarScreen = NSScreen.screens.first { screen in
                NSMouseInRect(buttonScreenPoint, screen.frame, false)
            } ?? NSScreen.main
            
            // Mark the status item visually active
            if button.wantsLayer {
                button.layer?.backgroundColor = NSColor.selectedMenuItemColor.withAlphaComponent(0.2).cgColor
            }
            
            // Calculate appropriate position
            NSApp.activate(ignoringOtherApps: true)
            
            // Force the popover to position correctly
            DispatchQueue.main.async {
                // Create our own event monitor for better click detection
                self.popoverMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] event in
                    guard let self = self, let popover = self.popover, popover.isShown else { return }
                    
                    // Get the click location in screen coordinates
                    let clickLocation = event.locationInWindow
                    let clickScreenPoint = event.window?.convertPoint(toScreen: clickLocation) ?? clickLocation
                    
                    // Check if click is outside popover
                    if let popoverWindow = popover.contentViewController?.view.window {
                        let popoverFrame = popoverWindow.frame
                        if !NSMouseInRect(clickScreenPoint, popoverFrame, false) {
                            // Click outside popover - close it
                            popover.close()
                            self.isPopoverShown = false
                            
                            // Reset button appearance
                            if let button = self.statusItem?.button, button.wantsLayer {
                                button.layer?.backgroundColor = nil
                            }
                        }
                    }
                }
                
                // Show the popover at the correct position
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                
                // Ensure our popover is positioned on the correct screen
                if let popoverWindow = popover.contentViewController?.view.window {
                    popoverWindow.level = .statusBar
                    
                    // Position correction for multi-monitor setups
                    if let menuBarScreen = menuBarScreen {
                        // Ensure popover is on the same screen as the menu bar icon
                        let currentFrame = popoverWindow.frame
                        let screenFrame = menuBarScreen.frame
                        
                        // Check if popover is partially outside the current screen
                        if !NSContainsRect(screenFrame, currentFrame) {
                            // Adjust position to keep within screen bounds
                            var adjustedFrame = currentFrame
                            
                            // Adjust X coordinate to stay within screen
                            if NSMaxX(currentFrame) > NSMaxX(screenFrame) {
                                adjustedFrame.origin.x = NSMaxX(screenFrame) - currentFrame.size.width
                            }
                            if currentFrame.origin.x < screenFrame.origin.x {
                                adjustedFrame.origin.x = screenFrame.origin.x
                            }
                            
                            // Adjust Y coordinate to stay within screen
                            if NSMaxY(currentFrame) > NSMaxY(screenFrame) {
                                adjustedFrame.origin.y = NSMaxY(screenFrame) - currentFrame.size.height
                            }
                            if currentFrame.origin.y < screenFrame.origin.y {
                                adjustedFrame.origin.y = screenFrame.origin.y
                            }
                            
                            // Apply adjusted frame
                            popoverWindow.setFrame(adjustedFrame, display: true)
                        }
                    }
                }
                
                self.isPopoverShown = true
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
            
            // Ensure proper size for consistency
            button.image?.size = NSSize(width: 18, height: 18)
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
                .onChange(of: isLoading) { newValue in
                    animateUpload = newValue
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