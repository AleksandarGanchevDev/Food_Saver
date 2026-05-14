//
//  OrderViewModel.swift
//  FoodSaver
//

import Foundation
import Combine

@MainActor
final class OrderViewModel: ObservableObject {
    @Published var customerOrders: [Order] = []
    @Published var storeOrders: [Order] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?
    @Published var reservingListingId: String?
    @Published var processingOrderId: String?

    var activeCustomerOrders: [Order] {
        customerOrders.filter { $0.status == .reserved }
    }

    var completedCustomerOrders: [Order] {
        customerOrders.filter { $0.status == .completed }
    }

    var cancelledCustomerOrders: [Order] {
        customerOrders.filter { $0.status == .cancelled }
    }

    var activeStoreOrders: [Order] {
        storeOrders.filter { $0.status == .reserved }
    }

    var completedStoreOrders: [Order] {
        storeOrders.filter { $0.status == .completed }
    }

    var cancelledStoreOrders: [Order] {
        storeOrders.filter { $0.status == .cancelled }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func reserve(listing: Listing) async -> Order? {
        clearMessages()
        reservingListingId = listing.id
        defer { reservingListingId = nil }

        do {
            let order = try await OrderService.shared.reserveListing(listing)
            successMessage = "Резервацията е създадена успешно."
            return order
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func complete(order: Order, pickupCode: String) async -> Order? {
        clearMessages()
        processingOrderId = order.id
        defer { processingOrderId = nil }

        do {
            let updatedOrder = try await OrderService.shared.completeOrder(order, enteredPickupCode: pickupCode)
            replaceOrder(updatedOrder)
            successMessage = "Резервацията е отбелязана като изпълнена."
            return updatedOrder
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func cancel(order: Order) async -> Order? {
        clearMessages()
        processingOrderId = order.id
        defer { processingOrderId = nil }

        do {
            let updatedOrder = try await OrderService.shared.cancelOrder(order)
            replaceOrder(updatedOrder)
            successMessage = "Резервацията е отказана успешно."
            return updatedOrder
        } catch {
            errorMessage = error.localizedDescription
            return nil
        }
    }

    func loadCustomerOrders() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            customerOrders = try await OrderService.shared.fetchCustomerOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadStoreOrders() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            storeOrders = try await OrderService.shared.fetchStoreOrders()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceOrder(_ updatedOrder: Order) {
        if let customerIndex = customerOrders.firstIndex(where: { $0.id == updatedOrder.id }) {
            customerOrders[customerIndex] = updatedOrder
        }

        if let storeIndex = storeOrders.firstIndex(where: { $0.id == updatedOrder.id }) {
            storeOrders[storeIndex] = updatedOrder
        }
    }
}
