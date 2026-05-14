//
//  SignInView.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import SwiftUI

struct SignInView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var showReset = false
    @State private var isForgotHovered = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Добре дошли отново") {
                    TextField("Имейл", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Парола", text: $password)
                }

                VStack(spacing: 16) {
                    Button {
                        Task {
                            await authVM.signIn(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password
                            )
                        }
                    } label: {
                        Group {
                            if authVM.isLoading {
                                ProgressView()
                                    .tint(.white)
                            } else {
                                Text("Вход")
                                    .fontWeight(.semibold)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authVM.isLoading)

                    Button("Забравена парола?") {
                        showReset = true
                    }
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .buttonStyle(.plain)
                }
                .padding(.top, 8)

                if let info = authVM.infoMessage {
                    Section {
                        Text(info).foregroundStyle(.green)
                    }
                }

                if let error = authVM.errorMessage {
                    Section {
                        Text(error).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Вход")
            .sheet(isPresented: $showReset) {
                ResetPasswordView()
                    .environmentObject(authVM)
            }
        }
    }
}
