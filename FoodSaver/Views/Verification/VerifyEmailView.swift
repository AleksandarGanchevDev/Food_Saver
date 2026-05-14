//
//  VerifyEmailView.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import SwiftUI

struct VerifyEmailView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Потвърдете своя имейл")
                    .font(.title2)
                    .bold()

                Text("Изпратихме линк за потвърждение на вашия имейл адрес. Моля, потвърдете акаунта си, преди да продължите.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.secondary)

                Button("Потвърдих имейла си") {
                    Task {
                        await authVM.refreshUser()
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authVM.isLoading)

                Button("Изпрати отново имейл за потвърждение") {
                    Task {
                        await authVM.resendVerificationEmail()
                    }
                }
                .disabled(authVM.isLoading)

                Button("Изход") {
                    authVM.signOut()
                }
                .foregroundStyle(.red)

                if authVM.isLoading {
                    ProgressView()
                }

                if let info = authVM.infoMessage {
                    Text(info).foregroundStyle(.green)
                }

                if let error = authVM.errorMessage {
                    Text(error).foregroundStyle(.red)
                }
            }
            .padding()
            .navigationTitle("Потвърждение на имейл")
        }
    }
}
