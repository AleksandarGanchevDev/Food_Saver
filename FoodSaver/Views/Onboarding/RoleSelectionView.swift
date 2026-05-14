//
//  RoleSelectionView.swift
//  FoodSaver
//

import SwiftUI
import FirebaseAuth

struct RoleSelectionView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("Изберете тип на акаунта")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Можете да промените това по-късно от настройките.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    if let email = authVM.user?.email {
                        Text(email)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(spacing: 16) {
                    ForEach(UserRole.allCases) { role in
                        Button {
                            Task {
                                await authVM.createUserProfile(role: role)
                            }
                        } label: {
                            HStack(spacing: 16) {
                                Image(systemName: role.iconName)
                                    .font(.title2)
                                    .frame(width: 36)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(role.title)
                                        .font(.headline)

                                    Text(role.subtitle)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.leading)
                                }

                                Spacer()
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                            .background(.thinMaterial)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .buttonStyle(.plain)
                        .disabled(authVM.isLoading)
                    }
                }

                if authVM.isLoading {
                    ProgressView()
                }

                if let error = authVM.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                Button("Изход") {
                    authVM.signOut()
                }
                .foregroundStyle(.red)
            }
            .padding()
            .navigationTitle("Завършване на профила")
        }
    }
}
