//
//  AuthContainerView.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import SwiftUI

struct AuthContainerView: View {
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            SignInView()
                .tabItem { Label("Вход", systemImage: "person") }
                .tag(0)

            SignUpView()
                .tabItem { Label("Създай акаунт", systemImage: "person.badge.plus") }
                .tag(1)
        }
    }
}
