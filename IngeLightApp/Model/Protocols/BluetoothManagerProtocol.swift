//
//  BluetoothManagerProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

/// Main interface for the Bluetooth manager used to scan and connect to peripherals.
protocol BluetoothManagerProtocol {
    /// The current Bluetooth manager state.
    var state: Observable<CBManagerState> { get }
    /// The list of discovered devices.
    var discoveredDevices: Observable<[BluetoothDeviceProtocol]> { get }
    /// The device the central manager is currently connected to, if any.
    var connectedDevice: Observable<BluetoothDeviceProtocol?> { get }

    /// Starts scanning for BLE devices.
    /// - Parameter services: Optional list of service UUIDs to filter by.
    /// - Returns: A completable that signals scan start.
    func startScanning(services: [CBUUID]?) -> Completable

    /// Stops scanning.
    func stopScanning()

    /// Connects to a device.
    /// - Parameter device: The device to connect to.
    /// - Returns: A completable that signals a successful connection.
    func connect(to device: BluetoothDeviceProtocol) -> Completable

    /// Disconnects from a device.
    /// - Parameter device: The device to disconnect from.
    /// - Returns: A completable that signals disconnection.
    func disconnect(from device: BluetoothDeviceProtocol) -> Completable
}
