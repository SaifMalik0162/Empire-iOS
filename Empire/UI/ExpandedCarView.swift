import SwiftUI

struct ExpandedCarView: View {
    let car: Car
    
    var body: some View {
        VStack(spacing: 16) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.ultraThinMaterial)
                .frame(height: 220)
                .overlay(
                    VStack(spacing: 12) {
                        HStack {
                            Text(car.name)
                                .font(.title2.bold())
                                .foregroundColor(.white)
                            Spacer()
                            AnimatedHPView(target: car.horsepower)
                        }
                        
                        Text(car.description)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.leading)
                        
                        // Stage chips visible only in expanded view
                        HStack(spacing: 12) {
                            StageChip(title: "Stage 1", color: car.stage >= 1 ? .green : .gray)
                            StageChip(title: "Stage 2", color: car.stage >= 2 ? .yellow : .gray)
                            StageChip(title: "Stage 3", color: car.stage >= 3 ? .red : .gray)
                        }
                    }
                    .padding(20)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(
                            LinearGradient(
                                colors: [Color("EmpireMint").opacity(0.6), Color.clear],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                )
                .shadow(color: Color("EmpireMint").opacity(0.25), radius: 15, x: 0, y: 6)
        }
    }
}

struct AnimatedHPView: View {
    let target: Int
    @State private var value: Int = 0
    
    var body: some View {
        Text("\(value) HP")
            .font(.subheadline.bold())
            .foregroundColor(.white.opacity(0.9))
            .onAppear {
                withAnimation(.easeOut(duration: 1.0)) {
                    value = target
                }
            }
    }
}
