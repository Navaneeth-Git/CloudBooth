import SwiftUI

struct AttributionView: View {
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Attribution")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Spacer()
                
                Button("Close") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.bottom, 10)
            
            // Content
            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(.blue)
                
                Text("CloudBooth")
                    .font(.title)
                    .fontWeight(.bold)
                
                Text("Created by Navaneeth")
                    .font(.title3)
                
                Link("GitHub Profile", destination: URL(string: "https://github.com/Navaneeth-Git")!)
                    .font(.headline)
                    .padding(.top, 4)
                
                Text("© 2023 All Rights Reserved")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.top, 10)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(nsColor: .controlBackgroundColor))
            )
            
            Spacer()
        }
        .padding()
        .frame(width: 400, height: 400)
    }
}

#Preview {
    AttributionView()
} 