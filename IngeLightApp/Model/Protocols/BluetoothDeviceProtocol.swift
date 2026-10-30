//
//  BluetoothDeviceProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

/// Protocol representing a Bluetooth device and its lifecycle.
protocol BluetoothDeviceProtocol {
    /// Unique identifier of the device.
    var identifier: UUID { get }
    /// User-facing name of the device, if advertised.
    var name: String? { get }
    /// The current signal strength of the device.
    var rssi: Observable<Int> { get }
    /// The current connection state of the device.
    var state: Observable<CBPeripheralState> { get }
    /// The services discovered on this device.
    var services: Observable<[BluetoothServiceProtocol]> { get }
    /// The underlying CoreBluetooth peripheral.
    var peripheral: CBPeripheral { get }

    /// Connects to this device.
    /// - Returns: A completable that signals a successful connection.
    func connect() -> Completable

    /// Disconnects from this device.
    /// - Returns: A completable that signals disconnection.
    func disconnect() -> Completable

    /// Discovers the services of this device.
    /// - Returns: A single that emits the discovered services.
    func discoverServices() -> Single<[BluetoothServiceProtocol]>
}
