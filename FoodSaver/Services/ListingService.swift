//
//  ListingService.swift
//  FoodSaver
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum ListingError: LocalizedError {
    case missingAuthUser
    case invalidPrice
    case invalidQuantity
    case invalidPickupWindow
    case invalidLatitude
    case invalidLongitude
    case unauthorized
    case listingNotFound
    case activeReservationsRestrictEditing
    case activeReservationsPreventDeletion
    case cannotActivateSoldOut
    case cannotActivateExpired

    var errorDescription: String? {
        switch self {
        case .missingAuthUser:
            return "Няма намерен вписан потребител."
        case .invalidPrice:
            return "Моля, въведете валидна цена."
        case .invalidQuantity:
            return "Моля, въведете валидно количество."
        case .invalidPickupWindow:
            return "Крайният час за получаване трябва да е след началния."
        case .invalidLatitude:
            return "Моля, въведете валидна географска ширина."
        case .invalidLongitude:
            return "Моля, въведете валидна географска дължина."
        case .unauthorized:
            return "Нямате право да променяте тази обява."
        case .listingNotFound:
            return "Обявата не беше намерена."
        case .activeReservationsRestrictEditing:
            return "Има активни резервации за тази обява. Можете да редактирате само описанието."
        case .activeReservationsPreventDeletion:
            return "Не можете да изтриете обява, докато има активни резервации към нея."
        case .cannotActivateSoldOut:
            return "Не можете да активирате изчерпана обява."
        case .cannotActivateExpired:
            return "Не можете да активирате изтекла обява."
        }
    }
}

final class ListingService {
    static let shared = ListingService()
    private init() {}

    private let db = Firestore.firestore()

    private var listingsCollection: CollectionReference {
        db.collection("listings")
    }

    private var ordersCollection: CollectionReference {
        db.collection("orders")
    }

    func createListing(
        title: String,
        details: String,
        price: Double,
        quantity: Int,
        pickupStart: Date,
        pickupEnd: Date,
        latitude: Double,
        longitude: Double
    ) async throws -> Listing {
        guard let user = Auth.auth().currentUser else {
            throw ListingError.missingAuthUser
        }

        try validateListingInput(
            price: price,
            quantity: quantity,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            latitude: latitude,
            longitude: longitude
        )

        let document = listingsCollection.document()

        let listing = Listing(
            id: document.documentID,
            storeId: user.uid,
            title: title,
            details: details,
            price: price,
            quantity: quantity,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            isActive: true,
            createdAt: Date(),
            latitude: latitude,
            longitude: longitude
        )

        try document.setData(from: listing)
        return listing
    }

    func updateListing(
        listingId: String,
        title: String,
        details: String,
        price: Double,
        quantity: Int,
        pickupStart: Date,
        pickupEnd: Date,
        latitude: Double,
        longitude: Double
    ) async throws -> Listing {
        guard let user = Auth.auth().currentUser else {
            throw ListingError.missingAuthUser
        }

        try validateListingInput(
            price: price,
            quantity: quantity,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            latitude: latitude,
            longitude: longitude
        )

        let document = listingsCollection.document(listingId)
        let snapshot = try await document.getDocument()

        guard snapshot.exists else {
            throw ListingError.listingNotFound
        }

        let currentListing = try snapshot.data(as: Listing.self)

        guard currentListing.storeId == user.uid else {
            throw ListingError.unauthorized
        }

        let hasActiveReservations = try await self.hasActiveReservations(for: listingId)
        let restrictedFieldsChanged =
            currentListing.title != title ||
            currentListing.price != price ||
            currentListing.quantity != quantity ||
            currentListing.pickupStart != pickupStart ||
            currentListing.pickupEnd != pickupEnd ||
            currentListing.latitude != latitude ||
            currentListing.longitude != longitude

        if hasActiveReservations && restrictedFieldsChanged {
            throw ListingError.activeReservationsRestrictEditing
        }

        let newIsActive: Bool
        if pickupEnd < Date() {
            newIsActive = false
        } else if currentListing.isActive {
            newIsActive = quantity > 0
        } else if currentListing.quantity == 0 && quantity > 0 {
            newIsActive = true
        } else {
            newIsActive = false
        }

        let updatedListing = Listing(
            id: currentListing.id,
            storeId: currentListing.storeId,
            title: title,
            details: details,
            price: price,
            quantity: quantity,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd,
            isActive: newIsActive,
            createdAt: currentListing.createdAt,
            latitude: latitude,
            longitude: longitude
        )

        try document.setData(from: updatedListing)
        return updatedListing
    }

    func deleteListing(listingId: String) async throws {
        guard let user = Auth.auth().currentUser else {
            throw ListingError.missingAuthUser
        }

        let document = listingsCollection.document(listingId)
        let snapshot = try await document.getDocument()

        guard snapshot.exists else {
            throw ListingError.listingNotFound
        }

        let currentListing = try snapshot.data(as: Listing.self)

        guard currentListing.storeId == user.uid else {
            throw ListingError.unauthorized
        }

        if try await hasActiveReservations(for: listingId) {
            throw ListingError.activeReservationsPreventDeletion
        }

        try await document.delete()
    }

    func setListingActivation(listingId: String, isActive: Bool) async throws -> Listing {
        guard let user = Auth.auth().currentUser else {
            throw ListingError.missingAuthUser
        }

        let document = listingsCollection.document(listingId)
        let snapshot = try await document.getDocument()

        guard snapshot.exists else {
            throw ListingError.listingNotFound
        }

        let currentListing = try snapshot.data(as: Listing.self)

        guard currentListing.storeId == user.uid else {
            throw ListingError.unauthorized
        }

        if isActive {
            guard currentListing.quantity > 0 else {
                throw ListingError.cannotActivateSoldOut
            }

            guard !currentListing.isExpired else {
                throw ListingError.cannotActivateExpired
            }
        }

        let updatedListing = Listing(
            id: currentListing.id,
            storeId: currentListing.storeId,
            title: currentListing.title,
            details: currentListing.details,
            price: currentListing.price,
            quantity: currentListing.quantity,
            pickupStart: currentListing.pickupStart,
            pickupEnd: currentListing.pickupEnd,
            isActive: isActive,
            createdAt: currentListing.createdAt,
            latitude: currentListing.latitude,
            longitude: currentListing.longitude
        )

        try document.setData(from: updatedListing)
        return updatedListing
    }

    func hasActiveReservations(for listingId: String) async throws -> Bool {
        guard let user = Auth.auth().currentUser else {
            throw ListingError.missingAuthUser
        }

        let snapshot = try await ordersCollection
            .whereField("storeId", isEqualTo: user.uid)
            .whereField("listingId", isEqualTo: listingId)
            .whereField("status", isEqualTo: OrderStatus.reserved.rawValue)
            .limit(to: 1)
            .getDocuments()

        return !snapshot.documents.isEmpty
    }

    func fetchActiveListings() async throws -> [Listing] {
        let snapshot = try await listingsCollection
            .whereField("isActive", isEqualTo: true)
            .order(by: "pickupStart")
            .getDocuments()

        return try snapshot.documents
            .map { try $0.data(as: Listing.self) }
            .filter { $0.isAvailableForReservation }
            .sorted { $0.pickupStart < $1.pickupStart }
    }

    func fetchListingsForCurrentStore() async throws -> [Listing] {
        guard let user = Auth.auth().currentUser else {
            throw ListingError.missingAuthUser
        }

        let snapshot = try await listingsCollection
            .whereField("storeId", isEqualTo: user.uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Listing.self) }
    }

    private func validateListingInput(
        price: Double,
        quantity: Int,
        pickupStart: Date,
        pickupEnd: Date,
        latitude: Double,
        longitude: Double
    ) throws {
        guard price > 0 else {
            throw ListingError.invalidPrice
        }

        guard quantity > 0 else {
            throw ListingError.invalidQuantity
        }

        guard pickupEnd > pickupStart else {
            throw ListingError.invalidPickupWindow
        }

        guard (-90...90).contains(latitude) else {
            throw ListingError.invalidLatitude
        }

        guard (-180...180).contains(longitude) else {
            throw ListingError.invalidLongitude
        }
    }
}
