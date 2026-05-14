//
//  UserProfile.swift
//  FoodSaver
//

import Foundation

enum UserRole: String, Codable, CaseIterable, Identifiable {
    case customer
    case store

    var id: String { rawValue }

    var title: String {
        switch self {
        case .customer:
            return "Клиент"
        case .store:
            return "Магазин"
        }
    }

    var subtitle: String {
        switch self {
        case .customer:
            return "Разглеждайте обяви за храна и резервирайте наблизо."
        case .store:
            return "Създавайте обяви и управлявайте резервациите."
        }
    }

    var iconName: String {
        switch self {
        case .customer:
            return "person"
        case .store:
            return "storefront"
        }
    }
}

struct UserProfile: Codable {
    let uid: String
    let email: String
    let role: UserRole
    let createdAt: Date
}
