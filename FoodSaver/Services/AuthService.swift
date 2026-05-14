//
//  AuthService.swift
//  FoodSaver
//
//  Created by Aleksandar on 20.03.26.
//

import Foundation
import FirebaseAuth

enum AuthError: LocalizedError {
    case missingUser
    case custom(String)

    var errorDescription: String? {
        switch self {
        case .missingUser:
            return "Няма намерен вписан потребител."
        case .custom(let message):
            return message
        }
    }
}

final class AuthService {
    static let shared = AuthService()
    private init() {}

    var currentUser: User? {
        Auth.auth().currentUser
    }

    func signUp(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().createUser(withEmail: email, password: password)
        return result.user
    }

    func signIn(email: String, password: String) async throws -> User {
        let result = try await Auth.auth().signIn(withEmail: email, password: password)
        return result.user
    }

    func localizedMessage(for error: Error) -> String {
        if let authError = error as? AuthError, let description = authError.errorDescription {
            return description
        }

        let nsError = error as NSError

        guard nsError.domain == AuthErrorDomain,
              let code = AuthErrorCode(rawValue: nsError.code) else {
            return error.localizedDescription
        }

        switch code {
        case .invalidEmail:
            return "Моля, въведете валиден имейл адрес."
        case .wrongPassword:
            return "Въведената парола е грешна."
        case .userNotFound:
            return "Не съществува потребител с този имейл адрес."
        case .emailAlreadyInUse:
            return "Вече има създаден акаунт с този имейл адрес."
        case .weakPassword:
            return "Паролата е твърде слаба. Използвайте поне 6 символа."
        case .networkError:
            return "Възникна проблем с мрежата. Опитайте отново."
        case .tooManyRequests:
            return "Направени са твърде много опити. Опитайте отново по-късно."
        case .userDisabled:
            return "Този акаунт е деактивиран."
        default:
            return error.localizedDescription
        }
    }

    func signOut() throws {
        try Auth.auth().signOut()
    }

    func sendPasswordReset(email: String) async throws {
        try await Auth.auth().sendPasswordReset(withEmail: email)
    }

    func sendEmailVerification() async throws {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.missingUser
        }
        try await user.sendEmailVerification()
    }

    func reloadCurrentUser() async throws -> User {
        guard let user = Auth.auth().currentUser else {
            throw AuthError.missingUser
        }
        try await user.reload()
        guard let refreshed = Auth.auth().currentUser else {
            throw AuthError.missingUser
        }
        return refreshed
    }
}
