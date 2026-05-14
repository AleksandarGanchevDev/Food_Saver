//
//  RootView.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import SwiftUI

struct RootView: View {
    @StateObject private var authVM = AuthViewModel()

    var body: some View {
        Group {
            if authVM.isAuthenticated {
                if authVM.isEmailVerified {
                    if authVM.isProfileLoading {
                        NavigationStack {
                            ProgressView("Зареждане на профила...")
                                .navigationTitle("Моля, изчакайте")
                        }
                        .environmentObject(authVM)
                    } else if authVM.userProfile == nil {
                        RoleSelectionView()
                            .environmentObject(authVM)
                    } else {
                        HomeView()
                            .environmentObject(authVM)
                    }
                } else {
                    VerifyEmailView()
                        .environmentObject(authVM)
                }
            } else {
                AuthContainerView()
                    .environmentObject(authVM)
            }
        }
    }
}
