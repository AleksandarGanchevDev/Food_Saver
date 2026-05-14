//
//  OrderService.swift
//  FoodSaver
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum OrderError: LocalizedError {
    case missingAuthUser
    case missingEmail
    case listingNotFound
    case listingUnavailable
    case soldOut
    case orderNotFound
    case notStoreOwner
    case notCustomerOwner
    case invalidOrderStatus
    case invalidPickupCode
    case transactionFailed

    var errorDescription: String? {
        switch self {
        case .missingAuthUser:
            return "Няма намерен вписан потребител."
        case .missingEmail:
            return "Вписаният потребител няма имейл адрес."
        case .listingNotFound:
            return "Тази обява не беше намерена."
        case .listingUnavailable:
            return "Тази обява вече не е налична."
        case .soldOut:
            return "Съжаляваме, обявата е изчерпана."
        case .orderNotFound:
            return "Тази резервация не беше намерена."
        case .notStoreOwner:
            return "Нямате право да променяте тази резервация."
        case .notCustomerOwner:
            return "Можете да отмените само своя собствена резервация."
        case .invalidOrderStatus:
            return "Тази резервация вече не може да бъде променяна."
        case .invalidPickupCode:
            return "Кодът за получаване е невалиден."
        case .transactionFailed:
            return "Операцията не можа да бъде завършена."
        }
    }
}

final class OrderService {
    static let shared = OrderService()
    private init() {}

    private let db = Firestore.firestore()

    private var ordersCollection: CollectionReference {
        db.collection("orders")
    }

    private var listingsCollection: CollectionReference {
        db.collection("listings")
    }

    func reserveListing(_ listing: Listing) async throws -> Order {
        guard let user = Auth.auth().currentUser else {
            throw OrderError.missingAuthUser
        }

        guard let email = user.email else {
            throw OrderError.missingEmail
        }

        let listingRef = listingsCollection.document(listing.id)
        let orderRef = ordersCollection.document()

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot

            do {
                snapshot = try transaction.getDocument(listingRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard snapshot.exists else {
                errorPointer?.pointee = self.makeNSError(.listingNotFound)
                return nil
            }

            let latestListing: Listing
            do {
                latestListing = try snapshot.data(as: Listing.self)
            } catch let decodeError as NSError {
                errorPointer?.pointee = decodeError
                return nil
            }

            guard latestListing.isAvailableForReservation else {
                errorPointer?.pointee = self.makeNSError(.listingUnavailable)
                return nil
            }

            guard latestListing.quantity > 0 else {
                errorPointer?.pointee = self.makeNSError(.soldOut)
                return nil
            }

            let newQuantity = latestListing.quantity - 1
            let pickupCode = Self.generatePickupCode()

            let order = Order(
                id: orderRef.documentID,
                listingId: latestListing.id,
                listingTitle: latestListing.title,
                customerId: user.uid,
                customerEmail: email,
                storeId: latestListing.storeId,
                reservedQuantity: 1,
                totalPrice: latestListing.price,
                status: .reserved,
                pickupCode: pickupCode,
                pickupStart: latestListing.pickupStart,
                pickupEnd: latestListing.pickupEnd,
                createdAt: Date()
            )

            transaction.setData([
                "id": order.id,
                "listingId": order.listingId,
                "listingTitle": order.listingTitle,
                "customerId": order.customerId,
                "customerEmail": order.customerEmail,
                "storeId": order.storeId,
                "reservedQuantity": order.reservedQuantity,
                "totalPrice": order.totalPrice,
                "status": order.status.rawValue,
                "pickupCode": order.pickupCode ?? "",
                "pickupStart": order.pickupStart,
                "pickupEnd": order.pickupEnd,
                "createdAt": order.createdAt
            ], forDocument: orderRef)

            transaction.updateData([
                "quantity": newQuantity,
                "isActive": newQuantity > 0
            ], forDocument: listingRef)

            return order
        }

        guard let order = result as? Order else {
            throw OrderError.transactionFailed
        }

        return order
    }

    func completeOrder(_ order: Order, enteredPickupCode: String) async throws -> Order {
        guard let user = Auth.auth().currentUser else {
            throw OrderError.missingAuthUser
        }

        let normalizedEnteredCode = Self.normalizePickupCode(enteredPickupCode)
        guard !normalizedEnteredCode.isEmpty else {
            throw OrderError.invalidPickupCode
        }

        let orderRef = ordersCollection.document(order.id)

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            let snapshot: DocumentSnapshot

            do {
                snapshot = try transaction.getDocument(orderRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard snapshot.exists else {
                errorPointer?.pointee = self.makeNSError(.orderNotFound)
                return nil
            }

            let latestOrder: Order
            do {
                latestOrder = try snapshot.data(as: Order.self)
            } catch let decodeError as NSError {
                errorPointer?.pointee = decodeError
                return nil
            }

            guard latestOrder.storeId == user.uid else {
                errorPointer?.pointee = self.makeNSError(.notStoreOwner)
                return nil
            }

            guard latestOrder.status == .reserved else {
                errorPointer?.pointee = self.makeNSError(.invalidOrderStatus)
                return nil
            }

            let expectedCode = Self.normalizePickupCode(latestOrder.pickupCode ?? "")
            guard !expectedCode.isEmpty, expectedCode == normalizedEnteredCode else {
                errorPointer?.pointee = self.makeNSError(.invalidPickupCode)
                return nil
            }

            transaction.updateData([
                "status": OrderStatus.completed.rawValue
            ], forDocument: orderRef)

            return Order(
                id: latestOrder.id,
                listingId: latestOrder.listingId,
                listingTitle: latestOrder.listingTitle,
                customerId: latestOrder.customerId,
                customerEmail: latestOrder.customerEmail,
                storeId: latestOrder.storeId,
                reservedQuantity: latestOrder.reservedQuantity,
                totalPrice: latestOrder.totalPrice,
                status: .completed,
                pickupCode: latestOrder.pickupCode,
                pickupStart: latestOrder.pickupStart,
                pickupEnd: latestOrder.pickupEnd,
                createdAt: latestOrder.createdAt
            )
        }

        guard let updatedOrder = result as? Order else {
            throw OrderError.transactionFailed
        }

        return updatedOrder
    }

    func cancelOrder(_ order: Order) async throws -> Order {
        guard let user = Auth.auth().currentUser else {
            throw OrderError.missingAuthUser
        }

        let orderRef = ordersCollection.document(order.id)
        let listingRef = listingsCollection.document(order.listingId)

        let result = try await db.runTransaction { transaction, errorPointer -> Any? in
            let orderSnapshot: DocumentSnapshot
            let listingSnapshot: DocumentSnapshot

            do {
                orderSnapshot = try transaction.getDocument(orderRef)
                listingSnapshot = try transaction.getDocument(listingRef)
            } catch let fetchError as NSError {
                errorPointer?.pointee = fetchError
                return nil
            }

            guard orderSnapshot.exists else {
                errorPointer?.pointee = self.makeNSError(.orderNotFound)
                return nil
            }

            let latestOrder: Order
            do {
                latestOrder = try orderSnapshot.data(as: Order.self)
            } catch let decodeError as NSError {
                errorPointer?.pointee = decodeError
                return nil
            }

            guard latestOrder.customerId == user.uid else {
                errorPointer?.pointee = self.makeNSError(.notCustomerOwner)
                return nil
            }

            guard latestOrder.status == .reserved else {
                errorPointer?.pointee = self.makeNSError(.invalidOrderStatus)
                return nil
            }

            var updatedListingData: [AnyHashable: Any]? = nil

            if listingSnapshot.exists {
                do {
                    let latestListing = try listingSnapshot.data(as: Listing.self)
                    let restoredQuantity = latestListing.quantity + latestOrder.reservedQuantity
                    let restoredIsActive = latestListing.isExpired ? false : true

                    updatedListingData = [
                        "quantity": restoredQuantity,
                        "isActive": restoredIsActive
                    ]
                } catch let listingDecodeError as NSError {
                    errorPointer?.pointee = listingDecodeError
                    return nil
                }
            }

            transaction.updateData([
                "status": OrderStatus.cancelled.rawValue
            ], forDocument: orderRef)

            if let updatedListingData {
                transaction.updateData(updatedListingData, forDocument: listingRef)
            }

            return Order(
                id: latestOrder.id,
                listingId: latestOrder.listingId,
                listingTitle: latestOrder.listingTitle,
                customerId: latestOrder.customerId,
                customerEmail: latestOrder.customerEmail,
                storeId: latestOrder.storeId,
                reservedQuantity: latestOrder.reservedQuantity,
                totalPrice: latestOrder.totalPrice,
                status: .cancelled,
                pickupCode: latestOrder.pickupCode,
                pickupStart: latestOrder.pickupStart,
                pickupEnd: latestOrder.pickupEnd,
                createdAt: latestOrder.createdAt
            )
        }

        guard let updatedOrder = result as? Order else {
            throw OrderError.transactionFailed
        }

        return updatedOrder
    }
    
    func fetchCustomerOrders() async throws -> [Order] {
        guard let user = Auth.auth().currentUser else {
            throw OrderError.missingAuthUser
        }

        let snapshot = try await ordersCollection
            .whereField("customerId", isEqualTo: user.uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Order.self) }
    }

    func fetchStoreOrders() async throws -> [Order] {
        guard let user = Auth.auth().currentUser else {
            throw OrderError.missingAuthUser
        }

        let snapshot = try await ordersCollection
            .whereField("storeId", isEqualTo: user.uid)
            .order(by: "createdAt", descending: true)
            .getDocuments()

        return try snapshot.documents.map { try $0.data(as: Order.self) }
    }

    private func makeNSError(_ error: OrderError) -> NSError {
        NSError(
            domain: "OrderService",
            code: 1,
            userInfo: [NSLocalizedDescriptionKey: error.errorDescription ?? "Непозната грешка"]
        )
    }

    private static func generatePickupCode() -> String {
        String(format: "%06d", Int.random(in: 0...999_999))
    }

    private static func normalizePickupCode(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: " ", with: "")
            .uppercased()
    }
}
