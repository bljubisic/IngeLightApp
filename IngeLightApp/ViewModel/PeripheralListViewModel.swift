//
//  PeripheralListViewModel.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.01.26.
//

import CoreBluetooth
import Foundation
import SwiftUI

@Observable
final class PeripheralListViewModel: NSObject {
    private let bluetoothManager: CBCentralManager
    private(set) var state: CBManagerState = .unknown
    
    private var discoveredPeripherials: Set<CBPeripheral> = []
    private(set) var displayedPeripherials: [CBPeripheral] = []
    
    init(bluetoothManager: CBCentralManager) {
        self.bluetoothManager = bluetoothManager
        super.init()
        bluetoothManager.delegate = self
    }
    
    func scan() {
        bluetoothManager.scanForPeripherals(withServices: nil, options: nil)
    }
}

extension PeripheralListViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.state = central.state
    }
    
    func centralManager(
    _ central: CBCentralManager,
    didDiscover peripheral: CBPeripheral,
    advertisementData: [String: Any],
    rssi RSSI: NSNumber) {
        if !discoveredPeripherials.contains(peripheral) {
            discoveredPeripherials.insert(peripheral)
            displayedPeripherials.append(peripheral)
        }
    }
}


