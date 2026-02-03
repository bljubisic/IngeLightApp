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
    
    func connect(to peripheral: CBPeripheral) {
        bluetoothManager.stopScan()
        bluetoothManager.connect(peripheral, options: nil)
    }
}

extension PeripheralListViewModel: CBCentralManagerDelegate {
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        self.state = central.state
    }
    
    func centralManager(_ central: CBCentralManager,
                        didDiscover peripheral: CBPeripheral,
                        advertisementData: [String: Any],
                        rssi RSSI: NSNumber) {
        if !discoveredPeripherials.contains(peripheral) {
            discoveredPeripherials.insert(peripheral)
            displayedPeripherials.append(peripheral)
        }
    }
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        print("Connected to \(peripheral.name ?? "Unknown")")
        peripheral.delegate = self
        peripheral.discoverServices(nil)
    }
}

extension PeripheralListViewModel: CBPeripheralDelegate {
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        if let error = error {
            print("Error discovering services: \(error.localizedDescription)")
            return
        }
        
        guard let services = peripheral.services else { return }
        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

}


