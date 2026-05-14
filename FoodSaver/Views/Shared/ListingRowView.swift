//
//  ListingRowView.swift
//  FoodSaver
//

import SwiftUI

struct ListingRowView: View {
    let listing: Listing
    var showsStatus: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(listing.title)
                        .font(.headline)

                    Text(listing.details)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer()

                Text(listing.price, format: .currency(code: "EUR"))
                    .fontWeight(.semibold)
            }

            if showsStatus {
                Label(listing.statusTitle, systemImage: statusIcon)
                    .font(.footnote)
                    .foregroundStyle(statusColor)
            }

            HStack(spacing: 16) {
                Label("Остават \(listing.quantity)", systemImage: "bag")
                Label(pickupText, systemImage: "clock")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var pickupText: String {
        let start = listing.pickupStart.formatted(date: .abbreviated, time: .shortened)
        let end = listing.pickupEnd.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private var statusIcon: String {
        if listing.isExpired {
            return "clock.badge.xmark"
        }

        if listing.quantity <= 0 {
            return "tray"
        }

        return listing.isActive ? "checkmark.circle" : "pause.circle"
    }

    private var statusColor: Color {
        if listing.isExpired {
            return .orange
        }

        if listing.quantity <= 0 {
            return .secondary
        }

        return listing.isActive ? .green : .orange
    }
}
