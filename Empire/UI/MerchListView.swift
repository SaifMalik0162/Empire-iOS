import SwiftUI

struct MerchListView: View {
    let title: String
    let items: [MerchItem]
    var categoryFilter: MerchCategory? = nil
    
    let gridItems = [GridItem(.flexible()), GridItem(.flexible())]
    
    var body: some View {
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
    }
}
