//
//  BluetoothList.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.01.26.
//

import CoreBluetooth
import SwiftUI

struct BluetoothList: View {
    // The view model driving the list of discovered devices.
    @State var viewModel: PeripheralListViewModel

    /// The main screen listing discovered BLE devices.
    var body: some View {
        switch viewModel.state {
        case .poweredOn:
            NavigationStack {
                List {
                    ForEach(viewModel.displayedDevices, id: \.identifier) { device in
                        NavigationLink(destination: CharacteristicsList(viewModel: viewModel)) {
                            DeviceRow(device: device)
                        }
                        .simultaneousGesture(TapGesture().onEnded {
                            viewModel.connect(to: device)
                        })
                    }
                }
                .navigationTitle("Bluetooth Devices")
                .task {
                    viewModel.scan()
                }
                .onDisappear {
                    viewModel.stopScan()
                }

                if let errorMessage = viewModel.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .padding()
                }
            }
        default:
            VStack {
                Text("BLE not available")
                    .font(.headline)
                Text("State: \(stateDescription)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // Human-readable description of the current Bluetooth state.
    private var stateDescription: String {
        switch viewModel.state {
        case .unknown:
            return "Unknown"
        case .resetting:
            return "Resetting"
        case .unsupported:
            return "Unsupported"
        case .unauthorized:
            return "Unauthorized"
        case .poweredOff:
            return "Powered Off"
        case .poweredOn:
            return "Powered On"
        @unknown default:
            return "Unknown State"
        }
    }
}

struct DeviceRow: View {
    // The device displayed by this row.
    let device: BluetoothDeviceProtocol

    /// A single row in the discovered devices list.
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(device.name ?? "Unknown Device")
                    .font(.headline)
                Spacer()
                if device.name == "IngeLight" {
                    Image(systemName: "lightbulb.fill")
                        .foregroundColor(.yellow)
                }
            }
            Text(device.identifier.uuidString)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 4)
    }
}
