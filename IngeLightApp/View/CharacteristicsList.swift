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
            Text("Service: \(service.uuid.uuidString)")
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
    private let disposeBag = DisposeBag()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(characteristic.uuid.uuidString)
                    .font(.caption)
                    .fontWeight(.medium)
                Spacer()
                PropertiesBadges(properties: characteristic.properties)
            }

            if let value = value {
                Text("Value: \(value.map { String(format: "%02x", $0) }.joined(separator: " "))")
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
                        let testData = Data([0x01, 0x02, 0x03])
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
