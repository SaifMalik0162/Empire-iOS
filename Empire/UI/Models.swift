import SwiftUI

// MARK: - Tabs
enum EmpireTab: CaseIterable, Hashable {
    case home, meets, cars, merch, profile

    var icon: String {
        switch self {
        case .home: return "house.fill"
        case .meets: return "map.fill"
        case .cars: return "car.fill"
        case .merch: return "bag.fill"
        case .profile: return "person.fill"
        }
    }
}

// MARK: - Meet
struct Meet: Identifiable {
    let id = UUID()
    let title: String
    let city: String
    let date: Date

    var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }
}

// MARK: - Car
struct Car: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let imageName: String
    let horsepower: Int
    let stage: Int
}

// MARK: - Merch Item
struct MerchItem: Identifiable {
    let id = UUID()
    let name: String
    let price: String
    let imageName: String
}
