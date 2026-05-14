//
//  CustomerOrdersView.swift
//  FoodSaver
//

import SwiftUI

struct CustomerOrdersView: View {
    @StateObject private var orderVM = OrderViewModel()

    var body: some View {
        Group {
            if orderVM.isLoading && orderVM.customerOrders.isEmpty {
                ProgressView("Зареждане на резервациите...")
            } else if orderVM.customerOrders.isEmpty {
                VStack(spacing: 16) {
                    Text("Все още няма резервации")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Когато резервирате обява, тя ще се появи тук.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            } else {
                List {
                    if let error = orderVM.errorMessage {
                        Text(error)
                            .foregroundStyle(.red)
                    }

                    if let success = orderVM.successMessage {
                        Text(success)
                            .foregroundStyle(.green)
                    }

                    if !orderVM.activeCustomerOrders.isEmpty {
                        Section("Активни резервации") {
                            ForEach(orderVM.activeCustomerOrders) { order in
                                NavigationLink {
                                    OrderDetailView(
                                        order: order,
                                        orderVM: orderVM,
                                        allowsCompletion: false,
                                        allowsCancellation: true
                                    )
                                } label: {
                                    OrderRowView(order: order, showsPickupCode: true)
                                }
                            }
                        }
                    }

                    if !orderVM.completedCustomerOrders.isEmpty {
                        Section("Изпълнени") {
                            ForEach(orderVM.completedCustomerOrders) { order in
                                NavigationLink {
                                    OrderDetailView(
                                        order: order,
                                        orderVM: orderVM,
                                        allowsCompletion: false,
                                        allowsCancellation: false
                                    )
                                } label: {
                                    OrderRowView(order: order)
                                }
                            }
                        }
                    }

                    if !orderVM.cancelledCustomerOrders.isEmpty {
                        Section("Отказани") {
                            ForEach(orderVM.cancelledCustomerOrders) { order in
                                NavigationLink {
                                    OrderDetailView(
                                        order: order,
                                        orderVM: orderVM,
                                        allowsCompletion: false,
                                        allowsCancellation: false
                                    )
                                } label: {
                                    OrderRowView(order: order)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Моите резервации")
        .task {
            await orderVM.loadCustomerOrders()
        }
        .refreshable {
            await orderVM.loadCustomerOrders()
        }
    }
}
