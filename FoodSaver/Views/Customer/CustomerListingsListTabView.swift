//
//  CustomerListingsListTabView.swift
//  FoodSaver
//

import SwiftUI

struct CustomerListingsListTabView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var listingVM: ListingViewModel
    @StateObject private var locationManager = LocationManager()

    var body: some View {
        NavigationStack {
            Group {
                if listingVM.isLoading && listingVM.activeListings.isEmpty {
                    ProgressView("Зареждане на обявите...")
                } else {
                    List {
                        if let error = listingVM.errorMessage {
                            Text(error)
                                .foregroundStyle(.red)
                        }

                        Section {
                            DisclosureGroup("Търсене, филтри и сортиране", isExpanded: $listingVM.showsFilters) {
                                TextField("Максимална цена (€)", text: $listingVM.maxPriceText)
                                    .keyboardType(.decimalPad)

                                TextField("Минимално количество", text: $listingVM.minimumQuantityText)
                                    .keyboardType(.numberPad)

                                Picker("Сортиране", selection: $listingVM.sortOption) {
                                    ForEach(ListingSortOption.allCases) { option in
                                        Text(option.title).tag(option)
                                    }
                                }

                                if listingVM.sortOption == .nearest && locationManager.userLocation == nil {
                                    Text("За подреждане по близост позволете достъп до местоположението.")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }

                                Button("Изчисти филтрите") {
                                    listingVM.clearFilters()
                                }
                            }
                        }

                        if filteredListings.isEmpty {
                            Section {
                                VStack(spacing: 12) {
                                    Text("Няма резултати")
                                        .font(.headline)

                                    Text("Променете търсенето или филтрите, за да видите налични предложения.")
                                        .multilineTextAlignment(.center)
                                        .foregroundStyle(.secondary)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                            }
                        } else {
                            Section("Налична храна") {
                                ForEach(filteredListings) { listing in
                                    NavigationLink {
                                        ListingDetailView(listing: listing)
                                    } label: {
                                        ListingRowView(listing: listing)
                                    }
                                }
                            }
                        }
                    }
                    .listStyle(.insetGrouped)
                }
            }
            .navigationTitle("Разгледай оферти")
            .searchable(text: $listingVM.searchText, prompt: "Търси по заглавие")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Моите резервации") {
                        CustomerOrdersView()
                    }
                }

                ToolbarItem(placement: .topBarTrailing) {
                    Button("Изход") {
                        authVM.signOut()
                    }
                }
            }
            .onAppear {
                locationManager.requestPermissionIfNeeded()
                locationManager.startUpdatingLocation()
            }
            .refreshable {
                await listingVM.loadActiveListings()
            }
        }
    }

    private var filteredListings: [Listing] {
        listingVM.filteredActiveListings(userLocation: locationManager.userLocation)
    }
}
