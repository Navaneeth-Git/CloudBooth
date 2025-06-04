import SwiftUI
import AppKit

struct SettingsView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with standard macOS styling
            HStack {
                HStack {
                    Image(systemName: "gearshape.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    
                    Text("Settings")
                        .font(.title3)
                        .fontWeight(.semibold)
                }
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Text("Close")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            
            // Settings content
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Auto-sync options
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            // Section title
                            Label("Auto-Sync Settings", systemImage: "clock.arrow.circlepath")
                                .font(.headline)
                                .padding(.bottom, 2)
                            
                            Text("Choose when CloudBooth should sync your Photo Booth pictures to iCloud")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                                .padding(.bottom, 4)
                            
                            // Radio button group
                            VStack(spacing: 2) {
                                ForEach(SyncInterval.allCases) { interval in
                                    syncIntervalButton(interval)
                                }
                            }
                            .padding(.vertical, 4)
                            
                            // Next sync info
                            if let nextSync = settings.nextScheduledSync, 
                               settings.autoSyncInterval != .never, 
                               settings.autoSyncInterval != .onNewPhotos {
                                HStack(alignment: .center, spacing: 6) {
                                    Image(systemName: "calendar.badge.clock")
                                        .foregroundStyle(.blue)
                                        .imageScale(.small)
                                    
                                    Text("Next sync: \(nextSync, formatter: dateFormatter)")
                                        .font(.callout)
                                }
                                .padding(.vertical, 8)
                                .padding(.horizontal, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.blue.opacity(0.06))
                                .cornerRadius(4)
                            }
                        }
                        .padding(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                    }
                    
                    // Destination section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 10) {
                            // Section title
                            Label("Destination Folder", systemImage: "folder.badge.gearshape")
                                .font(.headline)
                                .padding(.bottom, 2)
                            
                            Text("Choose where to save your Photo Booth files")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                            
                            // Destination options
                            VStack(alignment: .leading, spacing: 12) {
                                // iCloud option
                                Toggle(isOn: Binding(
                                    get: { !settings.useCustomDestination },
                                    set: { settings.useCustomDestination = !$0 }
                                )) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "icloud")
                                            .foregroundStyle(.blue)
                                            .imageScale(.small)
                                        
                                        Text("iCloud Drive")
                                            .font(.callout)
                                            .fontWeight(.medium)
                                    }
                                }
                                
                                if !settings.useCustomDestination {
                                    iCloudPathView()
                                }
                                
                                // Custom location option
                                Toggle(isOn: $settings.useCustomDestination) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "folder")
                                            .foregroundStyle(.orange)
                                            .imageScale(.small)
                                        
                                        Text("Custom Location")
                                            .font(.callout)
                                            .fontWeight(.medium)
                                    }
                                }
                                
                                if settings.useCustomDestination {
                                    HStack {
                                        Text(settings.customDestinationPath ?? "No folder selected")
                                            .font(.system(.callout, design: .monospaced))
                                            .lineLimit(1)
                                            .truncationMode(.middle)
                                            .padding(8)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.textBackgroundColor))
                                            .cornerRadius(4)
                                        
                                        Button("Choose...") {
                                            selectCustomFolder()
                                        }
                                        .buttonStyle(.borderedProminent)
                                        .controlSize(.small)
                                    }
                                }
                            }
                            
                            // Path information
                            GroupBox {
                                VStack(alignment: .leading, spacing: 6) {
                                    Label("Structure", systemImage: "info.circle")
                                        .font(.callout)
                                        .padding(.bottom, 2)
                                    
                                    Text("• /CloudBooth/Originals - Contains unedited photos")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    
                                    Text("• /CloudBooth/Pictures - Contains edited photos")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                .padding(EdgeInsets(top: 4, leading: 4, bottom: 6, trailing: 4))
                            }
                        }
                        .padding(EdgeInsets(top: 6, leading: 4, bottom: 6, trailing: 4))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 480, height: 520)
        .background(Color(.windowBackgroundColor))
    }
    
    private func selectCustomFolder() {
        let openPanel = NSOpenPanel()
        openPanel.title = "Select Custom Destination Folder"
        openPanel.message = "Choose a folder where your CloudBooth files will be synced"
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = false
        openPanel.allowsMultipleSelection = false
        
        if openPanel.runModal() == .OK, let url = openPanel.url {
            settings.customDestinationPath = url.path
        }
    }
    
    private func syncIntervalButton(_ interval: SyncInterval) -> some View {
        Button(action: {
            settings.autoSyncInterval = interval
        }) {
            HStack(alignment: .center, spacing: 6) {
                // macOS-style radio button
                Circle()
                    .strokeBorder(Color.gray.opacity(0.5), lineWidth: 0.5)
                    .background(
                        Circle()
                            .fill(settings.autoSyncInterval == interval ? Color.blue : Color.clear)
                            .padding(3)
                    )
                    .frame(width: 16, height: 16)
                
                Text(interval.rawValue)
                    .font(.system(.body, design: .default))
                    .foregroundStyle(settings.autoSyncInterval == interval ? .primary : .secondary)
                
                Spacer()
                
                // Icon for each type
                switch interval {
                case .never:
                    Image(systemName: "xmark.circle")
                        .foregroundStyle(.red)
                case .onNewPhotos:
                    Image(systemName: "photo.on.rectangle")
                        .foregroundStyle(.blue)
                case .sixHours:
                    Image(systemName: "clock.arrow.2.circlepath")
                        .foregroundStyle(.blue)
                case .daily:
                    Image(systemName: "calendar.day.timeline.left")
                        .foregroundStyle(.blue)
                case .weekly:
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                case .monthly:
                    Image(systemName: "calendar")
                        .foregroundStyle(.blue)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(settings.autoSyncInterval == interval ? Color.blue.opacity(0.07) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }
    
    private func iCloudPathView() -> some View {
        // First check if we have a security-scoped bookmark
        let bookmarkData = UserDefaults.standard.data(forKey: "iCloudBookmarkData")
        
        // Get the display path
        let displayPath: String
        
        if let bookmarkData = bookmarkData {
            do {
                var isStale = false
                let url = try URL(resolvingBookmarkData: bookmarkData, 
                                 options: [.withSecurityScope], 
                                 relativeTo: nil, 
                                 bookmarkDataIsStale: &isStale)
                
                if url.startAccessingSecurityScopedResource() {
                    displayPath = "\(url.path)/CloudBooth"
                    url.stopAccessingSecurityScopedResource()
                } else {
                    // Fall back to direct path
                    let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser
                    displayPath = "\(directiCloudURL.path)/Library/Mobile Documents/com~apple~CloudDocs/CloudBooth"
                }
            } catch {
                // Fall back to direct path
                let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser
                displayPath = "\(directiCloudURL.path)/Library/Mobile Documents/com~apple~CloudDocs/CloudBooth"
            }
        } else {
            // No bookmark, use direct path
            let directiCloudURL = FileManager.default.homeDirectoryForCurrentUser
            displayPath = "\(directiCloudURL.path)/Library/Mobile Documents/com~apple~CloudDocs/CloudBooth"
        }
        
        return Text(displayPath)
            .font(.system(.callout, design: .monospaced))
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.textBackgroundColor))
            .cornerRadius(4)
    }
    
    // Format dates consistently
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    SettingsView()
        .environmentObject(Settings.shared)
} 