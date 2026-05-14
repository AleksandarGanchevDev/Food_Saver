//
//  NearbyListingsMapView.swift
//  FoodSaver
//

import SwiftUI
import MapKit
import CoreLocation

struct NearbyListingsMapView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @ObservedObject var listingVM: ListingViewModel
    @StateObject private var locationManager = LocationManager()

    @State private var cameraPosition: MapCameraPosition = .automatic

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Map(position: $cameraPosition) {
                    ForEach(mappableListings) { listing in
                        if let latitude = listing.latitude,
                           let longitude = listing.longitude {
                            Marker(
                                listing.title,
                                coordinate: CLLocationCoordinate2D(
                                    latitude: latitude,
                                    longitude: longitude
                                )
                            )
                        }
                    }
                }
                .frame(height: 320)

                if isPermissionDenied {
                    VStack(spacing: 12) {
                        Text("Достъпът до местоположението е изключен")
                            .font(.headline)

                        Text("Активирайте достъпа до местоположението, за да центрирате картата около вас и да подредите обявите по разстояние.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Отвори настройките") {
                            openAppSettings()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                }

                if mappableListings.isEmpty {
                    VStack(spacing: 12) {
                        Text("Няма обяви за картата")
                            .font(.headline)

                        Text("Проверете дали има активни резултати според текущото търсене и филтрите.")
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)

                        Button("Изчисти филтрите") {
                            listingVM.clearFilters()
                        }
                    }
                    .padding()
                } else {
                    List {
                        Section("Обяви наблизо") {
                            ForEach(nearbyListings) { listing in
                                NavigationLink {
                                    ListingDetailView(listing: listing)
                                } label: {
                                    VStack(alignment: .leading, spacing: 8) {
                                        ListingRowView(listing: listing)

                                        if let distanceText = distanceText(for: listing) {
                                            Label(distanceText, systemImage: "location")
                                                .font(.footnote)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Карта")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink("Моите резервации") {
                        CustomerOrdersView()
                    }
                }

                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        centerOnUser()
                    } label: {
                        Image(systemName: "location")
                    }

                    Button("Изход") {
                        authVM.signOut()
                    }
                }
            }
            .onAppear {
                if listingVM.activeListings.isEmpty {
                    Task {
                        await listingVM.loadActiveListings()
                    }
                }

                locationManager.requestPermissionIfNeeded()

                if locationManager.authorizationStatus == .authorizedWhenInUse ||
                    locationManager.authorizationStatus == .authorizedAlways {
                    locationManager.startUpdatingLocation()
                }

                centerOnFirstMapListingIfNeeded()
            }
            .onChange(of: locationManager.userLocation) {
                centerOnUser()
            }
            .onReceive(listingVM.$activeListings) { _ in
                centerOnFirstMapListingIfNeeded()
            }
            .refreshable {
                await listingVM.loadActiveListings()
            }
        }
    }

    private var isPermissionDenied: Bool {
        locationManager.authorizationStatus == .denied ||
        locationManager.authorizationStatus == .restricted
    }

    private var filteredListings: [Listing] {
        listingVM.filteredActiveListings(userLocation: locationManager.userLocation)
    }

    private var mappableListings: [Listing] {
        filteredListings.filter { $0.latitude != nil && $0.longitude != nil }
    }

    private var nearbyListings: [Listing] {
        guard let userLocation = locationManager.userLocation else {
            return mappableListings.sorted { $0.pickupStart < $1.pickupStart }
        }

        return mappableListings.sorted {
            distance(from: userLocation, to: $0) < distance(from: userLocation, to: $1)
        }
    }

    private func distance(from userLocation: CLLocation, to listing: Listing) -> CLLocationDistance {
        guard let latitude = listing.latitude,
              let longitude = listing.longitude else {
            return .greatestFiniteMagnitude
        }

        let listingLocation = CLLocation(latitude: latitude, longitude: longitude)
        return userLocation.distance(from: listingLocation)
    }

    private func distanceText(for listing: Listing) -> String? {
        guard let userLocation = locationManager.userLocation else { return nil }

        let meters = distance(from: userLocation, to: listing)

        if meters < 1000 {
            return "\(Int(meters)) м от вас"
        } else {
            return String(format: "%.1f км от вас", locale: Locale(identifier: "bg_BG"), meters / 1000)
        }
    }

    private func centerOnUser() {
        guard let userLocation = locationManager.userLocation else { return }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: userLocation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.08, longitudeDelta: 0.08)
            )
        )
    }

    private func centerOnFirstMapListingIfNeeded() {
        guard locationManager.userLocation == nil,
              let first = mappableListings.first,
              let latitude = first.latitude,
              let longitude = first.longitude else { return }

        cameraPosition = .region(
            MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
                span: MKCoordinateSpan(latitudeDelta: 0.12, longitudeDelta: 0.12)
            )
        )
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
