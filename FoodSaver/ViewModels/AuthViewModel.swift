//
//  AuthViewModel.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import Foundation
import Combine
import FirebaseAuth

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var user: User?
    @Published var userProfile: UserProfile?
    @Published var isLoading = false
    @Published var isProfileLoading = false
    @Published var errorMessage: String?
    @Published var infoMessage: String?

    private var authStateHandle: AuthStateDidChangeListenerHandle?

    init() {
        startListening()
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    var isAuthenticated: Bool {
        user != nil
    }

    var isEmailVerified: Bool {
        user?.isEmailVerified ?? false
    }

    func startListening() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }

            Task { @MainActor in
                self.user = user

                guard let user else {
                    self.userProfile = nil
                    self.isProfileLoading = false
                    return
                }

                guard user.isEmailVerified else {
                    self.userProfile = nil
                    self.isProfileLoading = false
                    return
                }

                self.isProfileLoading = true
                await self.loadUserProfile()
            }
        }
    }

    func clearMessages() {
        errorMessage = nil
        infoMessage = nil
    }

    func signUp(email: String, password: String) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            _ = try await AuthService.shared.signUp(email: email, password: password)
            try await AuthService.shared.sendEmailVerification()
            infoMessage = "Акаунтът е създаден. Моля, потвърдете имейла си."
            user = AuthService.shared.currentUser
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }

    func signIn(email: String, password: String) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await AuthService.shared.signIn(email: email, password: password)
            self.user = user

            if user.isEmailVerified {
                isProfileLoading = true
            }
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }

    func signOut() {
        clearMessages()

        do {
            try AuthService.shared.signOut()
            user = nil
            userProfile = nil
            isProfileLoading = false
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }

    func sendReset(email: String) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthService.shared.sendPasswordReset(email: email)
            infoMessage = "Имейлът за нулиране на паролата беше изпратен."
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }

    func resendVerificationEmail() async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            try await AuthService.shared.sendEmailVerification()
            infoMessage = "Имейлът за потвърждение беше изпратен."
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }

    func refreshUser() async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            let user = try await AuthService.shared.reloadCurrentUser()
            self.user = user

            if user.isEmailVerified {
                isProfileLoading = true
                await loadUserProfile()
            }
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }

    func loadUserProfile() async {
        do {
            userProfile = try await UserProfileService.shared.fetchCurrentUserProfile()
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }

        isProfileLoading = false
    }

    func createUserProfile(role: UserRole) async {
        clearMessages()
        isLoading = true
        defer { isLoading = false }

        do {
            let profile = try await UserProfileService.shared.createProfile(role: role)
            userProfile = profile
        } catch {
            errorMessage = AuthService.shared.localizedMessage(for: error)
        }
    }
}
