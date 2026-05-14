//
//  OrderRowView.swift
//  FoodSaver
//

import SwiftUI

struct OrderRowView: View {
    let order: Order
    var showsCustomerEmail: Bool = false
    var showsPickupCode: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.listingTitle)
                        .font(.headline)

                    if showsCustomerEmail {
                        Text(order.customerEmail)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Text("Статус: \(order.status.title)")
                        .font(.subheadline)
                        .foregroundStyle(statusColor)

                    if showsPickupCode,
                       order.status == .reserved,
                       let pickupCode = order.pickupCode,
                       !pickupCode.isEmpty {
                        Label("Код: \(pickupCode)", systemImage: "number")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                Text(order.totalPrice, format: .currency(code: "EUR"))
                    .fontWeight(.semibold)
            }

            HStack(spacing: 16) {
                Label("Кол.: \(order.reservedQuantity)", systemImage: "bag")
                Label(pickupText, systemImage: "clock")
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }

    private var pickupText: String {
        let start = order.pickupStart.formatted(date: .abbreviated, time: .shortened)
        let end = order.pickupEnd.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private var statusColor: Color {
        switch order.status {
        case .reserved:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
}
