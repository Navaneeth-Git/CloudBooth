import SwiftUI
import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    var menuBarController: MenuBarController?
    var statusItem: NSStatusItem!
    override init() {
        super.init()
        _ = MenuBarController.shared // Keep for popover logic
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the status item ONCE
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "icloud", accessibilityDescription: "CloudBooth")
            button.action = #selector(statusItemClicked)
            button.target = self
        }
        menuBarController = MenuBarController.shared
    }

    @objc func statusItemClicked() {
        menuBarController?.togglePopover()
    }
}

@main
struct CloudBoothApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var settings = Settings.shared
    @State private var showSettingsWindow = false
    @State private var showHistoryWindow = false
    
    // Window controllers
    private let settingsWindowController = NSWindowController()
    private let historyWindowController = NSWindowController()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(width: 480, height: 600)
                .fixedSize()
                .environmentObject(settings)
                .alwaysOnTop()
                .onAppear {
                    setupNotificationObservers()
                    // Initialize window controllers
                    setupWindowControllers()
                    // Ensure the main window stays in front
                    if let window = NSApplication.shared.windows.first {
                        window.level = .floating
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
        .onChange(of: showSettingsWindow) { _, newValue in
            if newValue {
                openSettingsWindow()
                showSettingsWindow = false
            }
        }
        .onChange(of: showHistoryWindow) { _, newValue in
            if newValue {
                openHistoryWindow()
                showHistoryWindow = false
            }
        }
    }
    
    // Setup window controllers
    private func setupWindowControllers() {
        // Settings window
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: 460),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        settingsWindow.title = "CloudBooth Settings"
        settingsWindow.center()
        settingsWindow.isRestorable = false
        settingsWindow.contentView = NSHostingView(rootView: 
            SettingsView().environmentObject(settings).alwaysOnTop()
        )
        settingsWindow.level = .floating
        
        // History window
        let historyWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 500),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        historyWindow.title = "Sync History"
        historyWindow.center()
        historyWindow.isRestorable = false
        historyWindow.contentView = NSHostingView(rootView: 
            HistoryView().environmentObject(settings).alwaysOnTop()
        )
        historyWindow.level = .floating
        
        // Set window controllers
        if let settingsController = NSWindowController(window: settingsWindow) as? NSWindowController {
            settingsWindowController.window = settingsWindow
        }
        
        if let historyController = NSWindowController(window: historyWindow) as? NSWindowController {
            historyWindowController.window = historyWindow
        }
    }
    
    // Open settings window
    private func openSettingsWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if settingsWindowController.window == nil {
            setupWindowControllers()
        }
        settingsWindowController.showWindow(nil)
    }
    
    // Open history window
    private func openHistoryWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if historyWindowController.window == nil {
            setupWindowControllers()
        }
        historyWindowController.showWindow(nil)
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