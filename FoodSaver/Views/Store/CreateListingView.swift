//
//  CreateListingView.swift
//  FoodSaver
//

import SwiftUI

struct CreateListingView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var listingVM: ListingViewModel

    let listingToEdit: Listing?

    init(listingVM: ListingViewModel, listingToEdit: Listing? = nil) {
        self.listingVM = listingVM
        self.listingToEdit = listingToEdit
    }

    var body: some View {
        NavigationStack {
            Form {
                if listingVM.editingHasReservedOrders {
                    Section {
                        Text("Има активни резервации за тази обява. Можете да редактирате само описанието, за да не се нарушат вече направени резервации.")
                            .foregroundStyle(.orange)
                    }
                }

                Section("Детайли за обявата") {
                    TextField("Заглавие", text: $listingVM.title)
                        .disabled(coreFieldsDisabled)

                    TextField("Описание", text: $listingVM.details, axis: .vertical)
                        .lineLimit(3...6)

                    TextField("Цена в евро", text: $listingVM.priceText)
                        .keyboardType(.decimalPad)
                        .disabled(coreFieldsDisabled)

                    TextField("Количество", text: $listingVM.quantityText)
                        .keyboardType(.numberPad)
                        .disabled(coreFieldsDisabled)
                }

                Section("Местоположение на магазина") {
                    TextField("Географска ширина (напр. 42.6977)", text: $listingVM.latitudeText)
                        .keyboardType(.decimalPad)
                        .disabled(coreFieldsDisabled)

                    TextField("Географска дължина (напр. 23.3219)", text: $listingVM.longitudeText)
                        .keyboardType(.decimalPad)
                        .disabled(coreFieldsDisabled)
                }

                Section("Интервал за получаване") {
                    DatePicker(
                        "Начало",
                        selection: $listingVM.pickupStart,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .disabled(coreFieldsDisabled)

                    DatePicker(
                        "Край",
                        selection: $listingVM.pickupEnd,
                        displayedComponents: [.date, .hourAndMinute]
                    )
                    .disabled(coreFieldsDisabled)
                }

                Section {
                    Button {
                        Task {
                            let didSubmit = await listingVM.submitListing()
                            if didSubmit {
                                dismiss()
                            }
                        }
                    } label: {
                        if listingVM.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text(primaryButtonTitle)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .disabled(!listingVM.canSubmit || listingVM.isLoading)
                }

                if let error = listingVM.errorMessage {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(navigationTitle)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отказ") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                if let listingToEdit {
                    listingVM.beginEditing(listingToEdit)
                } else {
                    listingVM.beginCreating()
                }
            }
            .task(id: listingToEdit?.id) {
                if listingToEdit != nil {
                    await listingVM.loadEditingRestrictions()
                }
            }
            .onDisappear {
                listingVM.finishFormSession()
            }
        }
    }

    private var navigationTitle: String {
        listingToEdit == nil ? "Нова обява" : "Редактиране на обява"
    }

    private var primaryButtonTitle: String {
        listingToEdit == nil ? "Създай обява" : "Запази промените"
    }

    private var coreFieldsDisabled: Bool {
        listingVM.isEditing && listingVM.editingHasReservedOrders
    }
}
