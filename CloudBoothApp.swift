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
        .onChange(of: showSettingsWindow) { _, _ in
            if showSettingsWindow {
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
        .onChange(of: showHistoryWindow) { _, _ in
            if showHistoryWindow {
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