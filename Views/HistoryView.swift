import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var settings: Settings
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with standard macOS styling
            HStack {
                HStack {
                    Image(systemName: "clock.arrow.circlepath")
                        .font(.title3)
                        .foregroundStyle(.primary)
                    
                    Text("Sync History")
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
            
            // History content
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // Header with stats
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Recent Syncs")
                                .font(.headline)
                            
                            Text("\(settings.syncHistory.count) total records")
                                .font(.callout)
                                .foregroundStyle(.secondary)
                        }
                        
                        Spacer()
                        
                        // Summary stats if we have records
                        if !settings.syncHistory.isEmpty {
                            HStack(spacing: 14) {
                                VStack {
                                    Text("\(successfulSyncs)")
                                        .font(.headline)
                                        .foregroundColor(.green)
                                    
                                    Text("Successful")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack {
                                    Text("\(failedSyncs)")
                                        .font(.headline)
                                        .foregroundColor(.red)
                                    
                                    Text("Failed")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(Color(.controlBackgroundColor).opacity(0.5))
                            .cornerRadius(4)
                        }
                    }
                    .padding(.bottom, 6)
                    
                    if settings.syncHistory.isEmpty {
                        emptyHistoryView
                    } else {
                        historyListView
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .background(Color(.windowBackgroundColor))
        }
        .frame(width: 500, height: 480)
        .background(Color(.windowBackgroundColor))
    }
    
    // Empty state view
    private var emptyHistoryView: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(0.1))
                    .frame(width: 100, height: 100)
                
                Image(systemName: "clock.badge.questionmark")
                    .font(.system(size: 50))
                    .foregroundStyle(.secondary)
            }
            
            VStack(spacing: 8) {
                Text("No Sync History")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                    
                Text("Your sync history will appear here after your first sync")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }
            
            Button(action: {
                NotificationCenter.default.post(name: Notification.Name("SyncNowRequested"), object: nil)
                dismiss()
            }) {
                HStack {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync Now")
                }
                .frame(minWidth: 100)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
            .padding(.top, 8)
        }
        .padding(30)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // History list view
    private var historyListView: some View {
        LazyVStack(spacing: 10) {
            // Group by day
            ForEach(groupedByDate.keys.sorted(by: >), id: \.self) { date in
                if let records = groupedByDate[date] {
                    VStack(alignment: .leading, spacing: 6) {
                        // Date header
                        Text(formatDate(date))
                            .font(.callout)
                            .fontWeight(.semibold)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 4)
                            .padding(.bottom, 2)
                        
                        // Records for this date
                        ForEach(records) { record in
                            syncRecordCard(record)
                        }
                    }
                }
            }
        }
    }
    
    // Individual sync record card
    private func syncRecordCard(_ record: SyncRecord) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Status icon 
                Image(systemName: record.success ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.headline)
                    .symbolRenderingMode(.multicolor)
                    .foregroundStyle(record.success ? .green : .red)
                
                VStack(alignment: .leading, spacing: 1) {
                    // Time
                    Text(record.date, style: .time)
                        .font(.callout)
                        .fontWeight(.medium)
                    
                    // Files transferred
                    HStack(spacing: 4) {
                        Image(systemName: "doc")
                            .imageScale(.small)
                            .foregroundStyle(.secondary)
                        
                        Text("\(record.filesTransferred) files transferred")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                
                Spacer()
                
                // Time ago in pill
                Text(timeAgo(from: record.date))
                    .font(.caption)
                    .foregroundStyle(Color(.controlTextColor))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(record.success ? Color.green.opacity(0.1) : Color.red.opacity(0.1))
                    .cornerRadius(4)
            }
            
            // Error message if any
            if let error = record.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .cornerRadius(4)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.controlBackgroundColor))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color(.separatorColor).opacity(0.5), lineWidth: 0.5)
        )
    }
    
    // Group records by date
    private var groupedByDate: [Date: [SyncRecord]] {
        Dictionary(grouping: settings.syncHistory) { record in
            Calendar.current.startOfDay(for: record.date)
        }
    }
    
    // Format date headers
    private func formatDate(_ date: Date) -> String {
        if Calendar.current.isDateInToday(date) {
            return "Today"
        } else if Calendar.current.isDateInYesterday(date) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: date)
        }
    }
    
    // Success count
    private var successfulSyncs: Int {
        settings.syncHistory.filter { $0.success }.count
    }
    
    // Failure count
    private var failedSyncs: Int {
        settings.syncHistory.filter { !$0.success }.count
    }
    
    // Format dates consistently
    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }
    
    // Calculate time ago for history display
    private func timeAgo(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)
        
        if let day = components.day, day > 0 {
            return day == 1 ? "Yesterday" : "\(day) days ago"
        } else if let hour = components.hour, hour > 0 {
            return hour == 1 ? "1 hour ago" : "\(hour) hours ago"
        } else if let minute = components.minute, minute > 0 {
            return minute == 1 ? "1 minute ago" : "\(minute) minutes ago"
        } else {
            return "Just now"
        }
    }
}

#Preview {
    HistoryView()
        .environmentObject(Settings.shared)
} 