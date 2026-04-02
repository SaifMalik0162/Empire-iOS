import SwiftUI

struct ProductDetailView: View {
    @EnvironmentObject private var cart: Cart
    let item: MerchItem
    let related: [MerchItem]

    @State private var quantity: Int = 1
    @State private var showToast: Bool = false
    @State private var toastText: String = ""
    @State private var selectedSize: String? = nil
    private let sizes = ["S", "M", "L", "XL", "XXL"]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Image(item.imageName)
                    .resizable()
                    .scaledToFit()
                    .cornerRadius(16)
                    .shadow(color: Color("EmpireMint").opacity(0.3), radius: 12, x: 0, y: 6)

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.name)
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(item.price)
                            .font(.headline)
                            .foregroundStyle(Color("EmpireMint"))
                    }
                    Spacer()
                }

                HStack(spacing: 12) {
                    Text("Quantity")
                        .foregroundStyle(.white.opacity(0.9))
                    Stepper(value: $quantity, in: 1...10) {
                        Text("\(quantity)")
                            .foregroundStyle(.white)
                    }
                    .tint(Color("EmpireMint"))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(item.productDescription)
                        .foregroundStyle(.white.opacity(0.8))
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Availability")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text("In Stock")
                        .foregroundStyle(.white.opacity(0.8))
                }

                if item.category == .apparel {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Size")
                            .font(.headline)
                            .foregroundStyle(.white)
                        HStack(spacing: 8) {
                            ForEach(sizes, id: \.self) { size in
                                Button {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        selectedSize = size
                                    }
                                } label: {
                                    Text(size)
                                        .font(.subheadline.weight(.semibold))
                                        .frame(minWidth: 44)
                                        .padding(.vertical, 8)
                                        .padding(.horizontal, 12)
                                        .background(
                                            Capsule(style: .continuous)
                                                .fill(selectedSize == size ? Color("EmpireMint").opacity(0.25) : Color.white.opacity(0.08))
                                        )
                                        .overlay(
                                            Capsule(style: .continuous)
                                                .stroke(selectedSize == size ? Color("EmpireMint").opacity(0.9) : Color.white.opacity(0.25), lineWidth: 1)
                                        )
                                        .foregroundStyle(.white)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Button {
                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                    guard item.category != .apparel || selectedSize != nil else { return }
                    cart.add(item, quantity: quantity, selectedSize: selectedSize)
                    toastText = "Added \"\(item.name)\" to cart"
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showToast = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                        withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
                    }
                } label: {
                    HStack {
                        Image(systemName: "cart.badge.plus")
                        Text(item.category == .apparel && selectedSize == nil ? "Select Size" : "Add to Cart")
                            .font(.headline)
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        LinearGradient(
                            colors: [Color("EmpireMint").opacity((item.category == .apparel && selectedSize == nil) ? 0.45 : 0.85), Color("EmpireMint").opacity((item.category == .apparel && selectedSize == nil) ? 0.30 : 0.55)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .cornerRadius(14)
                    .shadow(color: Color("EmpireMint").opacity((item.category == .apparel && selectedSize == nil) ? 0.2 : 0.4), radius: 6, x: 0, y: 4)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .disabled(item.category == .apparel && selectedSize == nil)

                if !related.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Related Items")
                            .font(.headline)
                            .foregroundStyle(.white)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 12) {
                                ForEach(related) { r in
                                    NavigationLink {
                                        ProductDetailView(item: r, related: related.filter { $0.id != r.id })
                                    } label: {
                                        VStack(spacing: 6) {
                                            Image(r.imageName)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: 120, height: 90)
                                                .clipped()
                                                .cornerRadius(10)
                                            Text(r.name)
                                                .font(.caption.bold())
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                                .foregroundStyle(.white)
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 4)
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(LinearGradient(colors: [Color.black, Color.black.opacity(0.95)], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
        .overlay(alignment: .top) {
            if showToast {
                TopToast(text: toastText)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .padding(.top, 8)
            }
        }
    }
}

private extension MerchItem {
    var productDescription: String {
        switch name {
        case "Street Royalty Hoodie":
            return "A heavyweight Empire hoodie with the Street Royalty graphic front and center. Made for colder nights, early meets, and everyday wear."
        case "Empire Single Logo Tee":
            return "A clean Empire tee with a minimal single-logo hit. Easy to wear with anything and built for a simple everyday look."
        case "Air Freshener Kit":
            return "A freshener set made to add a subtle Empire touch to your interior. An easy accessory for keeping the cabin looking and smelling dialed in."
        case "Classic Banner":
            return "A clean Empire banner-style decal made for rear glass, quarter windows, or other smooth surfaces. Simple, readable, and easy to work into a clean setup."
        case "Death Metal Banner":
            return "A death-metal inspired banner-style decal for rear glass or side windows. Built for louder styling and a more aggressive visual hit on the car."
        case "Metal Banner":
            return "A heavy metal-inspired banner-style decal designed for glass and other clean surfaces. A strong option if you want a sharper, harder-edged look on the car."
        case "Urban Banner":
            return "A street-driven banner-style decal made for rear windows and other visible placements. Clean enough for daily use but still distinct from a basic logo decal."
        case "Astro Banner":
            return "A banner-style decal with a more atmospheric graphic direction, made for rear glass or other smooth mounting spots. Good if you want something different without going overly loud."
        case "Empire™ Banner":
            return "A signature Empire banner-style decal featuring the wordmark front and center. Ideal for rear glass when you want the cleanest and most direct Empire look."
        case "Mini Banner":
            return "A smaller banner-style decal for tighter rear windows, quarter glass, or compact placements. Easy to fit into cleaner builds without taking over the whole view."
        case "Tribal Flames Banner":
            return "A tribal flame banner-style decal with an older-school custom vibe. Best suited for rear glass or side window placement when you want a louder statement."
        case "Empire Tsurikawa":
            return "An Empire tsurikawa-style accessory that adds character to the interior or rear setup. A style-driven piece inspired by classic street culture details."
        case "Civic Decal":
            return "A Civic-themed Empire decal made for windows, toolboxes, or any clean surface that could use a subtle platform-specific touch."
        case "i-VTEC Decal":
            return "An i-VTEC inspired decal for Honda fans who want a lightweight detail piece. Easy to place and made to complement a clean setup."
        default:
            return "A premium Empire merch item designed to look clean, feel intentional, and fit naturally into your garage, car, or daily setup."
        }
    }
}
