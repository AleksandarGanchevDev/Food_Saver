//
//  ListingDetailView.swift
//  FoodSaver
//

import SwiftUI

struct ListingDetailView: View {
    @StateObject private var orderVM = OrderViewModel()
    @State private var currentListing: Listing

    init(listing: Listing) {
        _currentListing = State(initialValue: listing)
    }

    var body: some View {
        List {
            Section("Обява") {
                VStack(alignment: .leading, spacing: 8) {
                    Text(currentListing.title)
                        .font(.title3)
                        .fontWeight(.bold)

                    Text(currentListing.details)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            }

            Section("Получаване") {
                LabeledContent("Начало") {
                    Text(currentListing.pickupStart.formatted(date: .abbreviated, time: .shortened))
                }

                LabeledContent("Край") {
                    Text(currentListing.pickupEnd.formatted(date: .abbreviated, time: .shortened))
                }
            }

            Section("Цена") {
                LabeledContent("Сума") {
                    Text(currentListing.price, format: .currency(code: "EUR"))
                        .fontWeight(.semibold)
                }

                LabeledContent("Налични") {
                    Text("\(currentListing.quantity)")
                }

                LabeledContent("Състояние") {
                    Text(currentListing.statusTitle)
                        .foregroundStyle(statusColor)
                }
            }

            Section {
                Button {
                    Task {
                        let result = await orderVM.reserve(listing: currentListing)
                        if result != nil {
                            let newQuantity = max(currentListing.quantity - 1, 0)

                            currentListing = Listing(
                                id: currentListing.id,
                                storeId: currentListing.storeId,
                                title: currentListing.title,
                                details: currentListing.details,
                                price: currentListing.price,
                                quantity: newQuantity,
                                pickupStart: currentListing.pickupStart,
                                pickupEnd: currentListing.pickupEnd,
                                isActive: newQuantity > 0,
                                createdAt: currentListing.createdAt,
                                latitude: currentListing.latitude,
                                longitude: currentListing.longitude
                            )
                        }
                    }
                } label: {
                    if orderVM.reservingListingId == currentListing.id {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(primaryButtonTitle)
                            .frame(maxWidth: .infinity)
                    }
                }
                .disabled(!currentListing.isAvailableForReservation || orderVM.reservingListingId == currentListing.id)
            }

            if let success = orderVM.successMessage {
                Section {
                    Text(success)
                        .foregroundStyle(.green)
                }
            }

            if let error = orderVM.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Детайли за обявата")
    }

    private var primaryButtonTitle: String {
        if currentListing.isExpired {
            return "Обявата е изтекла"
        }

        if !currentListing.isActive {
            return currentListing.quantity > 0 ? "Обявата е неактивна" : "Изчерпано"
        }

        if currentListing.quantity <= 0 {
            return "Изчерпано"
        }

        return "Резервирай 1 пакет"
    }

    private var statusColor: Color {
        if currentListing.isExpired {
            return .orange
        }

        if currentListing.quantity <= 0 {
            return .secondary
        }

        return currentListing.isActive ? .green : .orange
    }
}
