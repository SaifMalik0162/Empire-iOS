import SwiftUI

struct StageChip: View {
    let title: String
    let color: Color
    
    var body: some View {
        Text(title)
            .font(.caption2.bold())
            .foregroundColor(.white)
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(color.opacity(0.3))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(color.opacity(0.6), lineWidth: 1.5)
            )
    }
}
