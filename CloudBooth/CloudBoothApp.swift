import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var didShowInitialPermission = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBarController = MenuBarController.shared
        
        // Check if we've already requested permissions before
        let hasRequestedPermissions = UserDefaults.standard.bool(forKey: "hasRequestedPermissions")
        
        // Only request permissions if we haven't done so before
        if !hasRequestedPermissions {
            // Request permissions on startup
            Task {
                // Allow app UI to appear first
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                
                // Show a more user-friendly permission request dialog first
                if !didShowInitialPermission {
                    didShowInitialPermission = true
                    await showPermissionInstructions()
                    
                    // Directly force permission requests after instructions
                    let hasAccess = await FileAccessManager.shared.forceRequestPermissions()
                    
                    if hasAccess {
                        // Mark that we've requested permissions
                        UserDefaults.standard.set(true, forKey: "hasRequestedPermissions")
                    } else {
                        // Try fallback method
                        let fallbackAccess = await FileAccessManager.shared.ensureDirectoryAccess()
                        if fallbackAccess {
                            UserDefaults.standard.set(true, forKey: "hasRequestedPermissions")
                        }
                    }
                }
            }
        } else {
            // Just verify access silently in the background
            Task {
                let _ = await FileAccessManager.shared.ensureDirectoryAccess()
            }
        }
    }
    
    func showPermissionInstructions() async {
        // First show an instructions dialog
        await MainActor.run {
            let alert = NSAlert()
            alert.messageText = "CloudBooth Needs Access"
            alert.informativeText = """
            CloudBooth needs permission to:
            1. Your Pictures folder - containing Photo Booth files
            2. Your iCloud Drive - to save the files
            
            In the next dialogs, you'll need to:
            • Navigate to each folder when prompted
            • Click "Grant Access" button
            
            You'll see multiple folder selection dialogs.
            """
            alert.alertStyle = .informational
            alert.addButton(withTitle: "Continue")
            alert.runModal()
        }
    }
}

@main
struct CloudBoothApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = Settings.shared
    @State private var showSettingsWindow = false
    @State private var showHistoryWindow = false
    @State private var permissionRetryCount = 0
    @State private var hasShownPermissionDialogs = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 480, height: 600)
                .fixedSize()
                .environmentObject(settings)
                .alwaysOnTop()
                .onAppear {
                    setupNotificationObservers()
                    // Ensure the main window stays in front
                    if let window = NSApplication.shared.windows.first {
                        window.level = .floating
                    }
                    
                    // Only show manual permission dialog if needed (no stored bookmarks)
                    let hasRequestedPermissions = UserDefaults.standard.bool(forKey: "hasRequestedPermissions")
                    if !hasRequestedPermissions && !hasShownPermissionDialogs {
                        hasShownPermissionDialogs = true
                        
                        // Try to verify/request permissions only if needed
                        Task {
                            let hasAccess = await FileAccessManager.shared.ensureDirectoryAccess()
                            if !hasAccess {
                                // Only try forced permission once
                                let forceAccess = await FileAccessManager.shared.forceRequestPermissions()
                                if forceAccess {
                                    UserDefaults.standard.set(true, forKey: "hasRequestedPermissions")
                                }
                            } else {
                                UserDefaults.standard.set(true, forKey: "hasRequestedPermissions")
                            }
                        }
                    }
                }
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentSize) // Prevent resizing
        .commands {
            CommandGroup(replacing: .newItem) { }
            
            CommandMenu("File") {
                Button("Sync Now") {
                    NotificationCenter.default.post(name: Notification.Name("SyncNowRequested"), object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command])
                
                Divider()
                
                Button("Settings...") {
                    showSettingsWindow = true
                }
                .keyboardShortcut(",", modifiers: [.command])
                
                Button("Sync History...") {
                    showHistoryWindow = true
                }
                .keyboardShortcut("h", modifiers: [.command])
                
                Divider()
                
                Button("Request Permissions...") {
                    Task {
                        _ = await FileAccessManager.shared.forceRequestPermissions()
                    }
                }
            }
            
            CommandMenu("View") {
                Button("Refresh") {
                    NotificationCenter.default.post(name: Notification.Name("RefreshRequested"), object: nil)
                }
                .keyboardShortcut("r", modifiers: [.command])
                
                Divider()
                
                Menu("Auto-Sync") {
                    ForEach(SyncInterval.allCases) { interval in
                        Button(interval.rawValue) {
                            settings.autoSyncInterval = interval
                        }
                        .checkmark(settings.autoSyncInterval == interval)
                    }
                }
            }
        }
        .onChange(of: showSettingsWindow) { newValue in
            if newValue {
                Task { @MainActor in
                    openWindow(
                        title: "CloudBooth Settings",
                        width: 500, 
                        height: 460,
                        content: { SettingsView().environmentObject(settings).alwaysOnTop() }
                    ) {
                        Task { @MainActor in
                            showSettingsWindow = false
                        }
                    }
                }
            }
        }
        .onChange(of: showHistoryWindow) { newValue in
            if newValue {
                Task { @MainActor in
                    openWindow(
                        title: "Sync History",
                        width: 520, 
                        height: 500,
                        content: { HistoryView().environmentObject(settings).alwaysOnTop() }
                    ) {
                        Task { @MainActor in
                            showHistoryWindow = false
                        }
                    }
                }
            }
        }
    }
    
    func openWindow<Content: View>(
        title: String,
        width: CGFloat, 
        height: CGFloat,
        content: @escaping () -> Content,
        onClose: @escaping @Sendable () -> Void
    ) {
        let contentWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        
        contentWindow.title = title
        contentWindow.center()
        contentWindow.isRestorable = false
        contentWindow.contentView = NSHostingView(rootView: content())
        contentWindow.level = .floating // Keep window on top
        
        let windowController = NSWindowController(window: contentWindow)
        windowController.showWindow(nil)
        
        // Reset state when window closes
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: contentWindow,
            queue: .main
        ) { _ in
            Task { @MainActor in
                onClose()
            }
        }
    }
    
    @MainActor
    private func setupNotificationObservers() {
        // Observe sync status for the menu bar icon
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncStarted"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarController.shared.updateStatusIcon(isLoading: true)
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncCompleted"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarController.shared.showSuccessIndicator()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("SyncFailed"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                MenuBarController.shared.showErrorIndicator()
            }
        }
        
        // Handle showing history window from menu bar
        NotificationCenter.default.addObserver(
            forName: NSNotification.Name("ShowHistoryRequested"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                showHistoryWindow = true
            }
        }
    }
}

// Helper for creating checkmark menu items
extension View {
    func checkmark(_ checked: Bool) -> some View {
        if checked {
            return AnyView(HStack {
                self
                Spacer()
                Image(systemName: "checkmark")
            })
        } else {
            return AnyView(self)
        }
    }
} 