//
//  ListingViewModel.swift
//  FoodSaver
//

import Foundation
import Combine
import CoreLocation

enum ListingSortOption: String, CaseIterable, Identifiable {
    case soonestPickup
    case cheapest
    case nearest

    var id: String { rawValue }

    var title: String {
        switch self {
        case .soonestPickup:
            return "Най-скоро взимане"
        case .cheapest:
            return "Най-ниска цена"
        case .nearest:
            return "Най-близо"
        }
    }
}

@MainActor
final class ListingViewModel: ObservableObject {
    @Published var activeListings: [Listing] = []
    @Published var storeListings: [Listing] = []

    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var successMessage: String?

    @Published var title = ""
    @Published var details = ""
    @Published var priceText = ""
    @Published var quantityText = "1"
    @Published var latitudeText = ""
    @Published var longitudeText = ""
    @Published var pickupStart = Date()
    @Published var pickupEnd = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

    @Published var searchText = ""
    @Published var maxPriceText = ""
    @Published var minimumQuantityText = ""
    @Published var sortOption: ListingSortOption = .soonestPickup
    @Published var showsFilters = false

    @Published private(set) var editingListingId: String?
    @Published private(set) var editingHasReservedOrders = false

    var isEditing: Bool {
        editingListingId != nil
    }

    var canSubmit: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !priceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !quantityText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !latitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !longitudeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        pickupEnd > pickupStart
    }

    var activeStoreListings: [Listing] {
        storeListings
            .filter { !$0.isExpired && $0.isActive && $0.quantity > 0 }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var inactiveStoreListings: [Listing] {
        storeListings
            .filter { !$0.isExpired && (!$0.isActive || $0.quantity <= 0) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    var expiredStoreListings: [Listing] {
        storeListings
            .filter { $0.isExpired }
            .sorted { $0.pickupEnd > $1.pickupEnd }
    }

    func clearMessages() {
        errorMessage = nil
        successMessage = nil
    }

    func clearFilters() {
        searchText = ""
        maxPriceText = ""
        minimumQuantityText = ""
        sortOption = .soonestPickup
    }

    func beginCreating() {
        editingListingId = nil
        editingHasReservedOrders = false
        resetForm()
        clearMessages()
    }

    func beginEditing(_ listing: Listing) {
        editingListingId = listing.id
        editingHasReservedOrders = false
        title = listing.title
        details = listing.details
        priceText = formatDecimal(listing.price)
        quantityText = String(listing.quantity)
        latitudeText = listing.latitude.map(formatDecimal) ?? ""
        longitudeText = listing.longitude.map(formatDecimal) ?? ""
        pickupStart = listing.pickupStart
        pickupEnd = listing.pickupEnd
        clearMessages()
    }

    func loadEditingRestrictions() async {
        guard let listingId = editingListingId else { return }

        do {
            editingHasReservedOrders = try await ListingService.shared.hasActiveReservations(for: listingId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func finishFormSession() {
        editingListingId = nil
        editingHasReservedOrders = false
    }

    func resetForm() {
        title = ""
        details = ""
        priceText = ""
        quantityText = "1"
        latitudeText = ""
        longitudeText = ""
        pickupStart = Date()
        pickupEnd = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()
    }

    func loadActiveListings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            activeListings = try await ListingService.shared.fetchActiveListings()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadStoreListings() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            storeListings = try await ListingService.shared.fetchListingsForCurrentStore()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func filteredActiveListings(userLocation: CLLocation? = nil) -> [Listing] {
        var listings = activeListings.filter { $0.isAvailableForReservation }

        let normalizedSearch = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !normalizedSearch.isEmpty {
            listings = listings.filter {
                $0.title.localizedCaseInsensitiveContains(normalizedSearch) ||
                $0.details.localizedCaseInsensitiveContains(normalizedSearch)
            }
        }

        if let maxPrice = normalizedDouble(from: maxPriceText) {
            listings = listings.filter { $0.price <= maxPrice }
        }

        if let minimumQuantity = Int(minimumQuantityText.trimmingCharacters(in: .whitespacesAndNewlines)), minimumQuantity > 0 {
            listings = listings.filter { $0.quantity >= minimumQuantity }
        }

        switch sortOption {
        case .soonestPickup:
            return listings.sorted { $0.pickupStart < $1.pickupStart }
        case .cheapest:
            return listings.sorted { $0.price < $1.price }
        case .nearest:
            guard let userLocation else {
                return listings.sorted { $0.pickupStart < $1.pickupStart }
            }

            return listings.sorted {
                distance(from: userLocation, to: $0) < distance(from: userLocation, to: $1)
            }
        }
    }

    func submitListing() async -> Bool {
        isEditing ? await updateListing() : await createListing()
    }

    func createListing() async -> Bool {
        clearMessages()

        guard let input = validatedInput() else {
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await ListingService.shared.createListing(
                title: input.title,
                details: input.details,
                price: input.price,
                quantity: input.quantity,
                pickupStart: input.pickupStart,
                pickupEnd: input.pickupEnd,
                latitude: input.latitude,
                longitude: input.longitude
            )

            storeListings = try await ListingService.shared.fetchListingsForCurrentStore()
            successMessage = "Обявата е създадена успешно."
            editingListingId = nil
            editingHasReservedOrders = false
            resetForm()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func updateListing() async -> Bool {
        clearMessages()

        guard let listingId = editingListingId else {
            errorMessage = "Не е избрана обява за редактиране."
            return false
        }

        guard let input = validatedInput() else {
            return false
        }

        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await ListingService.shared.updateListing(
                listingId: listingId,
                title: input.title,
                details: input.details,
                price: input.price,
                quantity: input.quantity,
                pickupStart: input.pickupStart,
                pickupEnd: input.pickupEnd,
                latitude: input.latitude,
                longitude: input.longitude
            )

            storeListings = try await ListingService.shared.fetchListingsForCurrentStore()
            successMessage = "Обявата е редактирана успешно."
            editingListingId = nil
            editingHasReservedOrders = false
            resetForm()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    func deleteListing(_ listing: Listing) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            try await ListingService.shared.deleteListing(listingId: listing.id)
            storeListings.removeAll { $0.id == listing.id }
            successMessage = "Обявата е изтрита успешно."

            if editingListingId == listing.id {
                editingListingId = nil
                editingHasReservedOrders = false
                resetForm()
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleActivation(for listing: Listing) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            let updatedListing = try await ListingService.shared.setListingActivation(
                listingId: listing.id,
                isActive: !listing.isActive
            )
            replaceStoreListing(updatedListing)
            successMessage = updatedListing.isActive ? "Обявата е активирана." : "Обявата е деактивирана."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func replaceStoreListing(_ updatedListing: Listing) {
        if let index = storeListings.firstIndex(where: { $0.id == updatedListing.id }) {
            storeListings[index] = updatedListing
        }
    }

    private func validatedInput() -> ListingFormInput? {
        let normalizedPrice = priceText.replacingOccurrences(of: ",", with: ".")
        let normalizedLatitude = latitudeText.replacingOccurrences(of: ",", with: ".")
        let normalizedLongitude = longitudeText.replacingOccurrences(of: ",", with: ".")

        guard let price = Double(normalizedPrice), price > 0 else {
            errorMessage = "Моля, въведете валидна цена."
            return nil
        }

        guard let quantity = Int(quantityText), quantity > 0 else {
            errorMessage = "Моля, въведете валидно количество."
            return nil
        }

        guard let latitude = Double(normalizedLatitude), (-90...90).contains(latitude) else {
            errorMessage = "Моля, въведете валидна географска ширина."
            return nil
        }

        guard let longitude = Double(normalizedLongitude), (-180...180).contains(longitude) else {
            errorMessage = "Моля, въведете валидна географска дължина."
            return nil
        }

        guard pickupEnd > pickupStart else {
            errorMessage = "Крайният час за получаване трябва да е след началния."
            return nil
        }

        return ListingFormInput(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            details: details.trimmingCharacters(in: .whitespacesAndNewlines),
            price: price,
            quantity: quantity,
            latitude: latitude,
            longitude: longitude,
            pickupStart: pickupStart,
            pickupEnd: pickupEnd
        )
    }

    private func normalizedDouble(from value: String) -> Double? {
        Double(value.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: ",", with: "."))
    }

    private func formatDecimal(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }

        return String(value).replacingOccurrences(of: ".", with: ",")
    }

    private func distance(from userLocation: CLLocation, to listing: Listing) -> CLLocationDistance {
        guard let latitude = listing.latitude,
              let longitude = listing.longitude else {
            return .greatestFiniteMagnitude
        }

        let listingLocation = CLLocation(latitude: latitude, longitude: longitude)
        return userLocation.distance(from: listingLocation)
    }
}

private struct ListingFormInput {
    let title: String
    let details: String
    let price: Double
    let quantity: Int
    let latitude: Double
    let longitude: Double
    let pickupStart: Date
    let pickupEnd: Date
}
