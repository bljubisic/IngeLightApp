//
//  IngeLightAppApp.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.01.26.
//
import CoreBluetooth
import SwiftUI

@main
struct IngeLightAppApp: App {
    var body: some Scene {
        WindowGroup {
            BluetoothList(viewModel: PeripheralListViewModel(bluetoothManager: CBCentralManager()))
        }
    }
}
