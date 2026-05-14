//
//  UserProfileService.swift
//  FoodSaver
//

import Foundation
import FirebaseAuth
import FirebaseFirestore

enum UserProfileError: LocalizedError {
    case missingAuthUser
    case missingEmail

    var errorDescription: String? {
        switch self {
        case .missingAuthUser:
            return "Няма намерен вписан потребител."
        case .missingEmail:
            return "Вписаният потребител няма имейл адрес."
        }
    }
}

final class UserProfileService {
    static let shared = UserProfileService()
    private init() {}

    private let db = Firestore.firestore()

    private var usersCollection: CollectionReference {
        db.collection("users")
    }

    func fetchCurrentUserProfile() async throws -> UserProfile? {
        guard let user = Auth.auth().currentUser else {
            throw UserProfileError.missingAuthUser
        }

        return try await fetchProfile(uid: user.uid)
    }

    func fetchProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await usersCollection.document(uid).getDocument()

        guard snapshot.exists else {
            return nil
        }

        return try snapshot.data(as: UserProfile.self)
    }

    func createProfile(role: UserRole) async throws -> UserProfile {
        guard let user = Auth.auth().currentUser else {
            throw UserProfileError.missingAuthUser
        }

        guard let email = user.email else {
            throw UserProfileError.missingEmail
        }

        let profile = UserProfile(
            uid: user.uid,
            email: email,
            role: role,
            createdAt: Date()
        )

        try usersCollection.document(user.uid).setData(from: profile)
        return profile
    }
}
