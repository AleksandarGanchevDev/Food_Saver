//
//  HomeView.swift
//  FoodSaver
//

import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        Group {
            switch authVM.userProfile?.role {
            case .customer:
                CustomerListingsView()
                    .environmentObject(authVM)

            case .store:
                StoreDashboardView()
                    .environmentObject(authVM)

            case .none:
                NavigationStack {
                    ProgressView("Зареждане на акаунта...")
                        .navigationTitle("Моля, изчакайте")
                }
            }
        }
    }
}
