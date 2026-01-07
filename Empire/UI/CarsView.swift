import SwiftUI

struct CarsView: View {
    // MARK: - User's cars
    @State private var cars: [Car] = [
        Car(name: "Honda Accord", description: "Stage 1 - Luh RS7", imageName: "car0", horsepower: 240, stage: 1)
    ]
    
    // MARK: - Community Cars
    @State private var communityCars: [Car] = [
        Car(name: "Nissan GT-R", description: "Stage 2 - Track Edition", imageName: "car3", horsepower: 550, stage: 2),
        Car(name: "BMW M3", description: "Stage 3 - Turbo", imageName: "car1", horsepower: 420, stage: 3),
        Car(name: "Audi RS7", description: "Stage 1 - Full Tune", imageName: "car2", horsepower: 620, stage: 1)
    ]
    
    @State private var selectedCarIndex: Int? = nil
    @Namespace private var animation
    @State private var ripple: Bool = false
    
    var body: some View {
        ZStack {
            // Background Gradient
            LinearGradient(colors: [Color.black, Color.black.opacity(0.95)],
                           startPoint: .top,
                           endPoint: .bottom)
                .ignoresSafeArea()
            
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 40) {
                    
                    // MARK: - User Car Carousel
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 24) {
                            ForEach(cars.indices, id: \.self) { idx in
                                CarCardView(
                                    car: cars[idx],
                                    isExpanded: selectedCarIndex == idx
                                )
                                .frame(width: selectedCarIndex == idx ? 300 : 200,
                                       height: selectedCarIndex == idx ? 380 : 250)
                                .scaleEffect(selectedCarIndex == idx ? 1.05 : 1)
                                .rotation3DEffect(
                                    .degrees(Double(idx - (selectedCarIndex ?? idx)) * 10),
                                    axis: (x: 0, y: 1, z: 0)
                                )
                                .onTapGesture {
                                    withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                                        selectedCarIndex = selectedCarIndex == idx ? nil : idx
                                        ripple = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                                        ripple = false
                                    }
                                }
                                .matchedGeometryEffect(id: idx, in: animation)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                    .frame(height: 400)
                    
                    // MARK: - Community Cars Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Community Cars")
                            .font(.title3.bold())
                            .foregroundColor(.white)
                            .padding(.horizontal, 20)
                        
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 16) {
                                ForEach(communityCars.indices, id: \.self) { idx in
                                    CarCardView(
                                        car: communityCars[idx],
                                        isExpanded: false
                                    )
                                    .frame(width: 180, height: 220)
                                    .onTapGesture {
                                        // Implement select community car to show ExpandedCarView later
                                        selectedCarIndex = nil
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        }
                        .frame(height: 240)
                    }
                    
                    Spacer(minLength: 60)
                }
                .padding(.vertical, 20)
            }
            
            // MARK: - Expanded Car Detail
            if let selected = selectedCarIndex, cars.indices.contains(selected) {
                ExpandedCarView(car: cars[selected])
                    .zIndex(1) // ensure above carousel
                    .transition(.asymmetric(
                        insertion: .move(edge: .bottom).combined(with: .opacity),
                        removal: .opacity
                    ))
                    .animation(.spring(response: 0.5, dampingFraction: 0.7), value: selectedCarIndex)
                    .padding(.horizontal, 20)
            }
            
            CoolRipple(active: $ripple)
                .edgesIgnoringSafeArea(.all)
        }
    }
}

struct CarsView_Previews: PreviewProvider {
    static var previews: some View {
        CarsView()
            .preferredColorScheme(.dark)
    }
}
