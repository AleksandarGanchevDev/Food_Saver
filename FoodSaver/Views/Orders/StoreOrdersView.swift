//

//  StoreOrdersView.swift
//  FoodSaver
//

import SwiftUI

struct StoreOrdersView: View {
    @StateObject private var orderVM = OrderViewModel()

    var body: some View {
        Group {
            if orderVM.isLoading && orderVM.storeOrders.isEmpty {
                ProgressView("Зареждане на резервациите...")
            } else if orderVM.storeOrders.isEmpty {
                VStack(spacing: 16) {
                    Text("Все още няма резервации")
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("Резервациите от клиенти за вашите обяви ще се появят тук.")
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

                    if !orderVM.activeStoreOrders.isEmpty {
                        Section("Активни резервации") {
                            ForEach(orderVM.activeStoreOrders) { order in
                                NavigationLink {
                                    OrderDetailView(
                                        order: order,
                                        orderVM: orderVM,
                                        allowsCompletion: true,
                                        allowsCancellation: false
                                    )
                                } label: {
                                    OrderRowView(order: order, showsCustomerEmail: true)
                                }
                            }
                        }
                    }

                    if !orderVM.completedStoreOrders.isEmpty {
                        Section("Изпълнени") {
                            ForEach(orderVM.completedStoreOrders) { order in
                                NavigationLink {
                                    OrderDetailView(
                                        order: order,
                                        orderVM: orderVM,
                                        allowsCompletion: false,
                                        allowsCancellation: false
                                    )
                                } label: {
                                    OrderRowView(order: order, showsCustomerEmail: true)
                                }
                            }
                        }
                    }

                    if !orderVM.cancelledStoreOrders.isEmpty {
                        Section("Отказани") {
                            ForEach(orderVM.cancelledStoreOrders) { order in
                                NavigationLink {
                                    OrderDetailView(
                                        order: order,
                                        orderVM: orderVM,
                                        allowsCompletion: false,
                                        allowsCancellation: false
                                    )
                                } label: {
                                    OrderRowView(order: order, showsCustomerEmail: true)
                                }
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Резервации")
        .task {
            await orderVM.loadStoreOrders()
        }
        .refreshable {
            await orderVM.loadStoreOrders()
        }
    }
}
