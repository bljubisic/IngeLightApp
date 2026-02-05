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
    @State var viewModel: PeripheralListViewModel

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
    let service: BluetoothServiceProtocol
    @State var viewModel: PeripheralListViewModel
    @State private var characteristics: [BluetoothCharacteristicProtocol] = []
    @State private var isExpanded = false
    private let disposeBag = DisposeBag()

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
            service.characteristics
                .subscribe(onNext: { chars in
                    characteristics = chars
                })
                .disposed(by: disposeBag)
        }
    }
}

struct CharacteristicRow: View {
    let characteristic: BluetoothCharacteristicProtocol
    @State var viewModel: PeripheralListViewModel
    @State private var value: Data?
    @State private var isNotifying = false

    // Explicit init to properly set up the @State viewModel backing storage
    init(characteristic: BluetoothCharacteristicProtocol, viewModel: PeripheralListViewModel) {
        self.characteristic = characteristic
        self._viewModel = State(initialValue: viewModel)
    }
    
    // Use CBUUID keys to match `characteristic.uuid: CBUUID` and fix malformed entries
    private var characteristicUUIDTranslation: [CBUUID: String] = [
        CBUUID(string: "9202d270-84ba-4561-a59d-7919212768a1"): "Busy Status",
        CBUUID(string: "2A37"): "Heart Rate Measurement",
        CBUUID(string: "32fd714a-0510-4025-8c2a-58fff4d5e99d"): "Device Name",
        CBUUID(string: "7db5cec5-3d74-4ff9-bd1a-57664f50e87b"): "Display Mode",
        CBUUID(string: "bafad844-484d-4e41-a31d-e3b14eb50db6"): "Boot Text",
        CBUUID(string: "3e856d44-0b59-48cc-a961-251f074c3884"): "Brightness",
        CBUUID(string: "a2a5ff5b-1465-4d0f-b8b5-9d2ca30ab9f0"): "Device Rotation",
        CBUUID(string: "887953b0-e363-4d57-9711-06e845cb4da4"): "Scroll Delay",
        CBUUID(string: "fcfca47e-f305-4841-b2d7-3ec79aa43b33"): "Torch Light"
    ]
    
    private let disposeBag = DisposeBag()

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
                        let testData = "busy".data(using: .utf8) ?? Data()
                        viewModel.writeCharacteristic(characteristic, data: testData)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
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
            characteristic.value
                .subscribe(onNext: { newValue in
                    value = newValue
                })
                .disposed(by: disposeBag)
        }
    }
}

struct PropertiesBadges: View {
    let properties: CBCharacteristicProperties

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
    let text: String
    let color: Color

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
