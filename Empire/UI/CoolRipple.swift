// MARK: - Cool Ripple Effect

import SwiftUI
struct CoolRipple: View {
    @Binding var active: Bool
    
    var body: some View {
        ZStack {
            // Glow
            Circle()
                .fill(Color("EmpireMint").opacity(active ? 0.15 : 0))
                .frame(width: 200, height: 200)
                .scaleEffect(active ? 1.8 : 0.3)
                .blur(radius: 20)
                .opacity(active ? 0 : 1)
                .animation(.easeOut(duration: 0.6), value: active)
            
            // Stroke
            Circle()
                .stroke(Color("EmpireMint").opacity(active ? 0.25 : 0), lineWidth: 2)
                .frame(width: 140, height: 140)
                .scaleEffect(active ? 1.5 : 0.2)
                .blur(radius: 5)
                .opacity(active ? 0 : 1)
                .animation(.easeOut(duration: 0.6), value: active)
            
            // Pulse
            Circle()
                .fill(Color("EmpireMint").opacity(active ? 0.1 : 0))
                .frame(width: 80, height: 80)
                .scaleEffect(active ? 1.3 : 0.5)
                .blur(radius: 10)
                .animation(.easeOut(duration: 0.6), value: active)
        }
    }
}
