//
//  Listing.swift
//  FoodSaver
//

import Foundation

struct Listing: Codable, Identifiable {
    let id: String
    let storeId: String
    let title: String
    let details: String
    let price: Double
    let quantity: Int
    let pickupStart: Date
    let pickupEnd: Date
    let isActive: Bool
    let createdAt: Date

    let latitude: Double?
    let longitude: Double?

    var isExpired: Bool {
        pickupEnd < Date()
    }

    var isAvailableForReservation: Bool {
        isActive && quantity > 0 && !isExpired
    }

    var statusTitle: String {
        if isExpired {
            return "Изтекла"
        }

        if quantity <= 0 {
            return "Изчерпана"
        }

        return isActive ? "Активна" : "Неактивна"
    }
}
