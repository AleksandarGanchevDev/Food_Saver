//
//  OrderDetailView.swift
//  FoodSaver
//

import SwiftUI

struct OrderDetailView: View {
    @ObservedObject var orderVM: OrderViewModel
    @State private var currentOrder: Order
    @State private var pickupCodeInput = ""
    @State private var showCancelAlert = false

    let allowsCompletion: Bool
    let allowsCancellation: Bool

    init(
        order: Order,
        orderVM: OrderViewModel,
        allowsCompletion: Bool = false,
        allowsCancellation: Bool = false
    ) {
        self.orderVM = orderVM
        self.allowsCompletion = allowsCompletion
        self.allowsCancellation = allowsCancellation
        _currentOrder = State(initialValue: order)
    }

    var body: some View {
        List {
            Section("Резервация") {
                LabeledContent("Обява") {
                    Text(currentOrder.listingTitle)
                }

                LabeledContent("Статус") {
                    Text(currentOrder.status.title)
                        .foregroundStyle(statusColor)
                        .fontWeight(.semibold)
                }

                LabeledContent("Количество") {
                    Text("\(currentOrder.reservedQuantity)")
                }

                LabeledContent("Общо") {
                    Text(currentOrder.totalPrice, format: .currency(code: "EUR"))
                        .fontWeight(.semibold)
                }
            }

            Section("Получаване") {
                LabeledContent("Начало") {
                    Text(currentOrder.pickupStart.formatted(date: .abbreviated, time: .shortened))
                }

                LabeledContent("Край") {
                    Text(currentOrder.pickupEnd.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if !allowsCompletion,
               let pickupCode = currentOrder.pickupCode,
               !pickupCode.isEmpty {
                Section("Код за получаване") {
                    Text(pickupCode)
                        .font(.system(size: 28, weight: .bold, design: .monospaced))
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 4)

                    Text("Покажете този код в магазина при получаване на поръчката.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section(allowsCompletion ? "Клиент" : "Резервирано от") {
                LabeledContent("Имейл") {
                    Text(currentOrder.customerEmail)
                }
            }

            if allowsCompletion && currentOrder.status == .reserved {
                Section("Потвърждение на получаването") {
                    TextField("Въведете кода от клиента", text: $pickupCodeInput)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()
                        .keyboardType(.numberPad)

                    Button {
                        Task {
                            if let updatedOrder = await orderVM.complete(order: currentOrder, pickupCode: pickupCodeInput) {
                                currentOrder = updatedOrder
                                pickupCodeInput = ""
                            }
                        }
                    } label: {
                        if orderVM.processingOrderId == currentOrder.id {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Потвърди получаването")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(orderVM.processingOrderId == currentOrder.id || pickupCodeInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }

            if allowsCancellation && currentOrder.status == .reserved {
                Section {
                    Button(role: .destructive) {
                        showCancelAlert = true
                    } label: {
                        if orderVM.processingOrderId == currentOrder.id {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("Откажи резервацията")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(orderVM.processingOrderId == currentOrder.id)
                }
            }

            if let success = orderVM.successMessage {
                Section {
                    Text(success)
                        .foregroundStyle(.green)
                }
            }

            if let error = orderVM.errorMessage {
                Section {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }
        }
        .navigationTitle("Детайли за резервацията")
        .alert("Отказ на резервация", isPresented: $showCancelAlert) {
            Button("Назад", role: .cancel) { }
            Button("Откажи", role: .destructive) {
                Task {
                    if let updatedOrder = await orderVM.cancel(order: currentOrder) {
                        currentOrder = updatedOrder
                    }
                }
            }
        } message: {
            Text("Сигурни ли сте, че искате да откажете тази резервация?")
        }
    }

    private var statusColor: Color {
        switch currentOrder.status {
        case .reserved:
            return .blue
        case .completed:
            return .green
        case .cancelled:
            return .red
        }
    }
}
