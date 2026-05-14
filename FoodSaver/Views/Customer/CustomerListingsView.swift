//
//  CustomerListingsView.swift
//  FoodSaver
//

import SwiftUI

struct CustomerListingsView: View {
    @StateObject private var listingVM = ListingViewModel()

    var body: some View {
        TabView {
            CustomerListingsListTabView(listingVM: listingVM)
                .tabItem {
                    Label("Списък", systemImage: "list.bullet")
                }

            NearbyListingsMapView(listingVM: listingVM)
                .tabItem {
                    Label("Карта", systemImage: "map")
                }
        }
        .task {
            if listingVM.activeListings.isEmpty {
                await listingVM.loadActiveListings()
            }
        }
    }
}
