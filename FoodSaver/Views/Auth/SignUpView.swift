//
//  SignUpView.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import SwiftUI

struct SignUpView: View {
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""

    private var passwordsMatch: Bool {
        !password.isEmpty && password == confirmPassword
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Създайте своя акаунт") {
                    TextField("Имейл", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    SecureField("Парола", text: $password)
                    SecureField("Потвърди паролата", text: $confirmPassword)
                }

                if !confirmPassword.isEmpty && !passwordsMatch {
                    Section {
                        Text("Паролите не съвпадат.")
                            .foregroundStyle(.red)
                    }
                }

                Section {
                    Button {
                        Task {
                            await authVM.signUp(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                                password: password
                            )
                        }
                    } label: {
                        if authVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Създай акаунт")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(
                        email.isEmpty ||
                        password.isEmpty ||
                        confirmPassword.isEmpty ||
                        !passwordsMatch ||
                        authVM.isLoading
                    )
                }

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
            .navigationTitle("Регистрация")
        }
    }
}
