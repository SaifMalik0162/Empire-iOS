import SwiftUI

struct CarCardView: View {
    let car: Car
    let isExpanded: Bool
    
    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Car card image
            Image(car.imageName)
                .resizable()
                .scaledToFill()
                .frame(width: isExpanded ? 300 : 200,
                       height: isExpanded ? 380 : 250)
                .clipped()
                .cornerRadius(28)
            
            // Faded gradient overlay
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
            .cornerRadius(28)
            
            // description in carousel
            VStack(alignment: .leading, spacing: 4) {
                Text(car.name)
                    .font(.headline.bold())
                    .foregroundColor(.white)
                
                Text(car.description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.8))
            }
            .padding(16)
        }
        .shadow(color: Color.black.opacity(0.6), radius: 8, x: 0, y: 6)
    }
}
