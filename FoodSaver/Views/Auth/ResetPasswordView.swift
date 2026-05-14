//
//  ResetPasswordView.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import SwiftUI

struct ResetPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var authVM: AuthViewModel

    @State private var email = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Нулиране на парола") {
                    TextField("Имейл", text: $email)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                }

                Section {
                    Button("Изпрати имейл за нулиране") {
                        Task {
                            await authVM.sendReset(
                                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
                            )
                        }
                    }
                    .disabled(email.isEmpty || authVM.isLoading)
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
            .navigationTitle("Забравена парола")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Готово") { dismiss() }
                }
            }
        }
    }
}
