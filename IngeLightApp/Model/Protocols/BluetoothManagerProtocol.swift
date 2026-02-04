//
//  BluetoothManagerProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

protocol BluetoothManagerProtocol {
    var state: Observable<CBManagerState> { get }
    var discoveredDevices: Observable<[BluetoothDeviceProtocol]> { get }
    var connectedDevice: Observable<BluetoothDeviceProtocol?> { get }

    func startScanning(services: [CBUUID]?) -> Completable
    func stopScanning()
    func connect(to device: BluetoothDeviceProtocol) -> Completable
    func disconnect(from device: BluetoothDeviceProtocol) -> Completable
}
