import SwiftUI
import Combine

struct MerchListView: View {
    let title: String
    let items: [MerchItem]
    var categoryFilter: MerchCategory? = nil

    @EnvironmentObject private var cart: Cart
    @State private var showToast: Bool = false
    @State private var toastText: String = ""

    let gridItems = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        ZStack(alignment: .top) {
            VStack(alignment: .leading) {
                Text(title)
                    .font(.title)
                    .bold()
                    .padding(.horizontal)

                let filtered = categoryFilter == nil ? items : items.filter { $0.category == categoryFilter }

                LazyVGrid(columns: gridItems, spacing: 16) {
                    ForEach(filtered) { item in
                        VStack {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                                    .overlay(
                                        Image(item.imageName)
                                            .resizable()
                                            .scaledToFill()
                                            .clipped()
                                    )
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .aspectRatio(4.0/3.0, contentMode: .fit)
                            }

                            Text(item.name)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.9)

                            Text(item.price)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        .padding()
                        .frame(minHeight: 220)
                        .background(Color(.systemBackground))
                        .cornerRadius(12)
                        .shadow(radius: 4)
                    }
                }
                .padding(.horizontal)
            }
            if showToast {
                TopToast(text: toastText)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(1)
                    .padding(.top, 8)
            }
        }
        .onReceive(cart.$lastAddedItemName.compactMap { $0 }.removeDuplicates()) { name in
            toastText = "Added \"\(name)\" to cart"
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9)) { showToast = true }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) {
                withAnimation(.easeInOut(duration: 0.25)) { showToast = false }
            }
        }
    }
}
