//
//  CharacteristicsList.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic Home  on 02.02.26.
//

import CoreBluetooth
import SwiftUI
import RxSwift

struct CharacteristicsList: View {
    // The view model that drives the services and characteristics UI.
    @State var viewModel: PeripheralListViewModel
    // Dismiss environment value used to pop this screen.
    @Environment(\.dismiss) private var dismiss

    /// Screen that shows device info, services and their characteristics.
    var body: some View {
        VStack {
            if let connectedDevice = viewModel.connectedDevice {
                List {
                    Section(header: Text("Device Info")) {
                        HStack {
                            Text("Name")
                            Spacer()
                            Text(connectedDevice.name ?? "Unknown")
                                .foregroundColor(.secondary)
                        }
                        HStack {
                            Text("Identifier")
                            Spacer()
                            Text(connectedDevice.identifier.uuidString)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    ForEach(viewModel.discoveredServices, id: \.uuid) { service in
                        ServiceSection(service: service, viewModel: viewModel)
                    }
                }
                .navigationTitle("Services & Characteristics")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Disconnect") {
                            viewModel.disconnect(from: connectedDevice)
                            dismiss()
                        }
                        .foregroundColor(.red)
                    }
                }
            } else {
                VStack(spacing: 16) {
                    ProgressView()
                    Text("Connecting...")
                        .font(.headline)
                    Text("Please wait while we establish connection")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            if let errorMessage = viewModel.errorMessage {
                Text(errorMessage)
                    .foregroundColor(.red)
                    .padding()
            }
        }
    }
}

struct ServiceSection: View {
    // The service whose characteristics are displayed.
    let service: BluetoothServiceProtocol
    // The view model that performs characteristic interactions.
    @State var viewModel: PeripheralListViewModel
    // The characteristics currently loaded for this service.
    @State private var characteristics: [BluetoothCharacteristicProtocol] = []
    // Whether the service section is expanded.
    @State private var isExpanded = false
    // RxSwift dispose bag for subscriptions created in this view.
    private let disposeBag = DisposeBag()

    /// A section that renders a service and its characteristics.
    var body: some View {
        Section(header: HStack {
            Text("Service: \(service.service.description)")
                .font(.caption)
            if service.isPrimary {
                Text("PRIMARY")
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .cornerRadius(4)
            }
        }) {
            ForEach(characteristics, id: \.uuid) { characteristic in
                CharacteristicRow(characteristic: characteristic, viewModel: viewModel)
            }
        }
        .onAppear {
            // Subscribe to the service characteristic stream and cache the discovered characteristics.
            service.characteristics
                .subscribe(onNext: { chars in
                    characteristics = chars
                })
                .disposed(by: disposeBag)
        }
    }
}

struct CharacteristicRow: View {
    // The characteristic being displayed and interacted with.
    let characteristic: BluetoothCharacteristicProtocol
    // The view model that performs read/write/notify actions.
    @State var viewModel: PeripheralListViewModel
    // The last observed value of the characteristic.
    @State private var value: Data?
    // Whether notifications are currently enabled for this characteristic.
    @State private var isNotifying = false
    // The currently selected value from the picker.
    @State private var selectedValue: String = ""
    // The free-form text entered for writes.
    @State private var textInputValue: String = ""

    // Explicit init to properly set up the @State viewModel backing storage
    init(characteristic: BluetoothCharacteristicProtocol, viewModel: PeripheralListViewModel) {
        self.characteristic = characteristic
        self._viewModel = State(initialValue: viewModel)
    }
    
    // Maps known characteristic UUIDs to human-friendly names; falls back to the raw UUID string.
    private var characteristicUUIDTranslation: [CBUUID: String] = [
        CBUUID(string: "9202d270-84ba-4561-a59d-7919212768a1"): "Busy Status",
        CBUUID(string: "32fd714a-0510-4025-8c2a-58fff4d5e99d"): "Device Name",
        CBUUID(string: "7db5cec5-3d74-4ff9-bd1a-57664f50e87b"): "Display Mode",
        CBUUID(string: "bafad844-484d-4e41-a31d-e3b14eb50db6"): "Boot Text",
        CBUUID(string: "3e856d44-0b59-48cc-a961-251f074c3884"): "Brightness",
        CBUUID(string: "a2a5ff5b-1465-4d0f-b8b5-9d2ca30ab9f0"): "Device Rotation",
        CBUUID(string: "887953b0-e363-4d57-9711-06e845cb4da4"): "Scroll Delay",
        CBUUID(string: "fcfca47e-f305-4841-b2d7-3ec79aa43b33"): "Torch Light"
    ]
    
    // Maps known characteristic UUIDs to the list of allowed/selectable values.
    private var characteristicsAvailableValues: [CBUUID: [String]] = [
        CBUUID(string: "9202d270-84ba-4561-a59d-7919212768a1"): ["free", "busy", "dnd", "unknown"],
        CBUUID(string: "3e856d44-0b59-48cc-a961-251f074c3884"): ["min", "low", "medium", "high", "max"],
        CBUUID(string: "a2a5ff5b-1465-4d0f-b8b5-9d2ca30ab9f0"): ["usb-up", "usb-down"],
        CBUUID(string: "7db5cec5-3d74-4ff9-bd1a-57664f50e87b"): ["symbol", "circle", "traffic", "color"],
        CBUUID(string: "fcfca47e-f305-4841-b2d7-3ec79aa43b33"): ["torch-on", "torch-off"]
    ]

    // The selectable values for this characteristic, if any are known.
    private var availableValues: [String]? {
        characteristicsAvailableValues[characteristic.uuid]
    }


    // RxSwift dispose bag for subscriptions created in this view.
    private let disposeBag = DisposeBag()

    // The row UI: value display, selection/write input, and read/write/notify actions.
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                // Lookup by CBUUID and fall back to the raw UUID string when unknown
                Text(self.characteristicUUIDTranslation[characteristic.uuid] ?? characteristic.uuid.uuidString)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                PropertiesBadges(properties: characteristic.properties)
            }

            if let value = value {
                Text("Value: \(String(decoding: value, as: UTF8.self))")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if let availableValues = availableValues, !availableValues.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Select Value:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Picker("", selection: $selectedValue) {
                        ForEach(availableValues, id: \.self) { value in
                            Text(value).tag(value)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                }
            } else if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Enter Value:")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    TextField("Type value to write", text: $textInputValue)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
            }

            HStack {
                if characteristic.properties.contains(.read) {
                    Button("Read") {
                        viewModel.readCharacteristic(characteristic)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                if characteristic.properties.contains(.write) || characteristic.properties.contains(.writeWithoutResponse) {
                    Button("Write") {
                        let dataToWrite: Data
                        if let availableValues = availableValues, !availableValues.isEmpty {
                            dataToWrite = selectedValue.data(using: .utf8) ?? Data()
                        } else {
                            dataToWrite = textInputValue.data(using: .utf8) ?? Data()
                        }
                        viewModel.writeCharacteristic(characteristic, data: dataToWrite)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled((availableValues == nil || availableValues?.isEmpty == true) && textInputValue.isEmpty)
                }

                if characteristic.properties.contains(.notify) || characteristic.properties.contains(.indicate) {
                    Button(isNotifying ? "Stop Notify" : "Start Notify") {
                        isNotifying.toggle()
                        viewModel.setNotify(isNotifying, for: characteristic)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(isNotifying ? .red : .blue)
                }
            }
        }
        .padding(.vertical, 4)
        .onAppear {
            // Subscribe to the characteristic value stream and default the picker selection.
            characteristic.value
                .subscribe(onNext: { newValue in
                    value = newValue
                })
                .disposed(by: disposeBag)

            if let availableValues = availableValues, !availableValues.isEmpty {
                selectedValue = availableValues[0]
            }
        }
    }
}

struct PropertiesBadges: View {
    // The properties supported by the characteristic.
    let properties: CBCharacteristicProperties

    /// Badges summarizing the characteristic properties (R, W, WR, N, I).
    var body: some View {
        HStack(spacing: 4) {
            if properties.contains(.read) {
                PropertyBadge(text: "R", color: .blue)
            }
            if properties.contains(.write) {
                PropertyBadge(text: "W", color: .green)
            }
            if properties.contains(.writeWithoutResponse) {
                PropertyBadge(text: "WR", color: .green)
            }
            if properties.contains(.notify) {
                PropertyBadge(text: "N", color: .orange)
            }
            if properties.contains(.indicate) {
                PropertyBadge(text: "I", color: .purple)
            }
        }
    }
}

struct PropertyBadge: View {
    // The badge text (e.g. "R").
    let text: String
    // The color associated with the badge.
    let color: Color

    /// A small colored badge displaying a property code.
    var body: some View {
        Text(text)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(color)
            .cornerRadius(3)
    }
}
