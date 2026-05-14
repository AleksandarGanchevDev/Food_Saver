//
//  StoreDashboardView.swift
//  FoodSaver
//

import SwiftUI

struct StoreDashboardView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @StateObject private var listingVM = ListingViewModel()
    @State private var showCreateListing = false
    @State private var listingToEdit: Listing?
    @State private var listingToDelete: Listing?

    var body: some View {
        NavigationStack {
            Group {
                if listingVM.isLoading && listingVM.storeListings.isEmpty {
                    ProgressView("Зареждане на вашите обяви...")
                } else if listingVM.storeListings.isEmpty {
                    VStack(spacing: 16) {
                        Text("Все още няма обяви")
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text("Натиснете бутона +, за да създадете първата си обява за храна.")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Създай първа обява") {
                            showCreateListing = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                } else {
                    List {
                        if let success = listingVM.successMessage {
                            Text(success)
                                .foregroundStyle(.green)
                        }

                        if let error = listingVM.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                        }

                        if !listingVM.activeStoreListings.isEmpty {
                            Section("Активни обяви") {
                                ForEach(listingVM.activeStoreListings) { listing in
                                    storeListingRow(listing)
                                }
                            }
                        }

                        if !listingVM.inactiveStoreListings.isEmpty {
                            Section("Неактивни и изчерпани") {
                                ForEach(listingVM.inactiveStoreListings) { listing in
                                    storeListingRow(listing)
                                }
                            }
                        }

                        if !listingVM.expiredStoreListings.isEmpty {
                            Section("Изтекли") {
                                ForEach(listingVM.expiredStoreListings) { listing in
                                    storeListingRow(listing)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Табло на магазина")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Изход") {
                        authVM.signOut()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    NavigationLink {
                        StoreOrdersView()
                    } label: {
                        Image(systemName: "list.bullet.clipboard")
                    }

                    Button {
                        showCreateListing = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showCreateListing) {
                CreateListingView(listingVM: listingVM)
            }
            .sheet(item: $listingToEdit) { listing in
                CreateListingView(listingVM: listingVM, listingToEdit: listing)
            }
            .alert("Изтриване на обява", isPresented: deleteAlertBinding) {
                Button("Отказ", role: .cancel) {
                    listingToDelete = nil
                }

                Button("Изтрий", role: .destructive) {
                    guard let listing = listingToDelete else { return }

                    Task {
                        await listingVM.deleteListing(listing)
                        listingToDelete = nil
                    }
                }
            } message: {
                Text("Сигурни ли сте, че искате да изтриете тази обява?")
            }
            .task {
                await listingVM.loadStoreListings()
            }
            .refreshable {
                await listingVM.loadStoreListings()
            }
        }
    }

    @ViewBuilder
    private func storeListingRow(_ listing: Listing) -> some View {
        ListingRowView(listing: listing, showsStatus: true)
            .contentShape(Rectangle())
            .onTapGesture {
                if !listing.isExpired {
                    listingToEdit = listing
                }
            }
            .swipeActions(edge: .leading, allowsFullSwipe: false) {
                if !listing.isExpired {
                    Button {
                        listingToEdit = listing
                    } label: {
                        Label("Редакция", systemImage: "pencil")
                    }
                    .tint(.blue)
                }
            }
            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                if canToggleActivation(for: listing) {
                    Button {
                        Task {
                            await listingVM.toggleActivation(for: listing)
                        }
                    } label: {
                        Label(activationButtonTitle(for: listing), systemImage: activationButtonIcon(for: listing))
                    }
                    .tint(listing.isActive ? .orange : .green)
                }

                Button(role: .destructive) {
                    listingToDelete = listing
                } label: {
                    Label("Изтрий", systemImage: "trash")
                }
            }
    }

    private func canToggleActivation(for listing: Listing) -> Bool {
        !listing.isExpired && (listing.isActive || listing.quantity > 0)
    }

    private func activationButtonTitle(for listing: Listing) -> String {
        listing.isActive ? "Деактивирай" : "Активирай"
    }

    private func activationButtonIcon(for listing: Listing) -> String {
        listing.isActive ? "pause.circle" : "play.circle"
    }

    private var deleteAlertBinding: Binding<Bool> {
        Binding(
            get: { listingToDelete != nil },
            set: { isPresented in
                if !isPresented {
                    listingToDelete = nil
                }
            }
        )
    }
}
