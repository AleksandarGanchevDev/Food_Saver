//
//  Order.swift
//  FoodSaver
//

import Foundation

enum OrderStatus: String, Codable, CaseIterable {
    case reserved
    case completed
    case cancelled

    var title: String {
        switch self {
        case .reserved:
            return "Резервирана"
        case .completed:
            return "Изпълнена"
        case .cancelled:
            return "Отказана"
        }
    }
}

struct Order: Codable, Identifiable {
    let id: String
    let listingId: String
    let listingTitle: String

    let customerId: String
    let customerEmail: String

    let storeId: String

    let reservedQuantity: Int
    let totalPrice: Double
    let status: OrderStatus
    let pickupCode: String?

    let pickupStart: Date
    let pickupEnd: Date

    let createdAt: Date

    var isActiveReservation: Bool {
        status == .reserved
    }
}
