import SwiftUI

struct MerchCatalog {
    static let featured: [MerchItem] = [
        MerchItem(name: "Street Royalty Hoodie", price: "$80", imageName: "street_royalty_hoodie", category: .apparel),
        MerchItem(name: "Empire Single Logo Tee", price: "$35", imageName: "empire_single_logo_tee", category: .apparel),
        MerchItem(name: "Air Freshener Kit", price: "$15", imageName: "air_freshener_kit", category: .accessories)
    ]

    static let bestSellers: [MerchItem] = [
        MerchItem(name: "Classic Banner", price: "$25", imageName: "classic_banner", category: .banners),
        MerchItem(name: "Death Metal Banner", price: "$25", imageName: "death_metal_banner", category: .banners),
        MerchItem(name: "Metal Banner", price: "$25", imageName: "metal_banner", category: .banners),
        MerchItem(name: "Urban Banner", price: "$25", imageName: "urban_banner", category: .banners)
    ]

    static let newArrivals: [MerchItem] = [
        MerchItem(name: "Astro Banner", price: "$25", imageName: "astro_banner", category: .banners),
        MerchItem(name: "Empire™ Banner", price: "$25", imageName: "empiretm_banner", category: .banners),
        MerchItem(name: "Mini Banner", price: "$20", imageName: "mini_banner", category: .banners),
        MerchItem(name: "Tribal Flames Banner", price: "$25", imageName: "tribal_flames_banner", category: .banners),
        MerchItem(name: "Empire Tsurikawa", price: "$30", imageName: "empire_tsurikawa", category: .accessories),
        MerchItem(name: "Civic Decal", price: "$12", imageName: "civic_decal", category: .banners),
        MerchItem(name: "i-VTEC Decal", price: "$12", imageName: "i-vtec_decal", category: .banners)
    ]
}
