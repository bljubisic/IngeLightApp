//
//  BluetoothManager.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift
import RxCocoa

final class BluetoothManager: NSObject, BluetoothManagerProtocol {
    // Central manager used to scan, connect and communicate with BLE peripherals.
    private let centralManager: CBCentralManager

    // Relay emitting the latest central manager state to subscribers.
    private let stateRelay = BehaviorRelay<CBManagerState>(value: .unknown)
    /// The current Bluetooth manager state.
    var state: Observable<CBManagerState> {
        stateRelay.asObservable()
    }

    // Relay emitting the discovered devices list to subscribers.
    private let discoveredDevicesRelay = BehaviorRelay<[BluetoothDeviceProtocol]>(value: [])
    /// The list of currently discovered BLE devices.
    var discoveredDevices: Observable<[BluetoothDeviceProtocol]> {
        discoveredDevicesRelay.asObservable()
    }

    // Relay emitting the currently connected device (nil when disconnected) to subscribers.
    private let connectedDeviceRelay = BehaviorRelay<BluetoothDeviceProtocol?>(value: nil)
    /// The device the central manager is currently connected to, if any.
    var connectedDevice: Observable<BluetoothDeviceProtocol?> {
        connectedDeviceRelay.asObservable()
    }

    // Cache of known devices keyed by peripheral UUID to reuse instances and avoid duplicates.
    private var deviceCache: [UUID: BluetoothDevice] = [:]
    // RxSwift dispose bag used to dispose all subscriptions created by this manager.
    private let disposeBag = DisposeBag()

    override init() {
        // Initialize the central manager and make it the delegate.
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        centralManager.delegate = self
    }

    /// Starts scanning for BLE devices, optionally filtered by service UUIDs.
    /// - Parameter services: Optional list of service UUIDs to filter discovered devices.
    /// - Returns: A completable that completes once the scan has been started.
    func startScanning(services: [CBUUID]? = nil) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(BluetoothError.unknown))
                return Disposables.create()
            }

            // Scanning can only start when the central manager is powered on.
            guard self.centralManager.state == .poweredOn else {
                observer(.error(BluetoothError.scanningFailed))
                return Disposables.create()
            }

            self.centralManager.scanForPeripherals(withServices: services, options: [
                CBCentralManagerScanOptionAllowDuplicatesKey: false
            ])

            observer(.completed)
            return Disposables.create()
        }
    }

    /// Stops an ongoing BLE scan.
    func stopScanning() {
        centralManager.stopScan()
    }

    /// Connects the central manager to the given device.
    /// - Parameter device: The Bluetooth device to connect to.
    /// - Returns: A completable that completes once the connection is established.
    func connect(to device: BluetoothDeviceProtocol) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(BluetoothError.unknown))
                return Disposables.create()
            }

            self.centralManager.connect(device.peripheral, options: nil)

            // Complete the sequence once the device reports being connected.
            let subscription = device.state
                .filter { $0 == .connected }
                .take(1)
                .subscribe(onNext: { [weak self] _ in
                    self?.connectedDeviceRelay.accept(device)
                    observer(.completed)
                }, onError: { error in
                    observer(.error(error))
                })

            return subscription
        }
    }

    /// Disconnects the central manager from the given device.
    /// - Parameter device: The Bluetooth device to disconnect from.
    /// - Returns: A completable that completes once the disconnection is confirmed.
    func disconnect(from device: BluetoothDeviceProtocol) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(BluetoothError.unknown))
                return Disposables.create()
            }

            self.centralManager.cancelPeripheralConnection(device.peripheral)

            // Complete the sequence once the device reports being disconnected.
            let subscription = device.state
                .filter { $0 == .disconnected }
                .take(1)
                .subscribe(onNext: { [weak self] _ in
                    self?.connectedDeviceRelay.accept(nil)
                    observer(.completed)
                }, onError: { error in
                    observer(.error(error))
                })

            return subscription
        }
    }

    /// Returns the cached device for the peripheral, creating and caching it when unknown.
    /// - Parameters:
    ///   - peripheral: The peripheral to resolve the device for.
    ///   - rssi: The received signal strength of the peripheral.
    /// - Returns: The BluetoothDevice representing the peripheral.
    private func getOrCreateDevice(peripheral: CBPeripheral, rssi: NSNumber) -> BluetoothDevice {
        if let existingDevice = deviceCache[peripheral.identifier] {
            // Reuse the cached instance and refresh its signal strength.
            existingDevice.updateRSSI(rssi)
            return existingDevice
        } else {
            let newDevice = BluetoothDevice(
                peripheral: peripheral,
                rssi: rssi,
                centralManager: centralManager
            )
            deviceCache[peripheral.identifier] = newDevice
            return newDevice
        }
    }
}

extension BluetoothManager: CBCentralManagerDelegate {
    /// Notifies subscribers about a central manager state change.
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateRelay.accept(central.state)
    }

    /// Notifies subscribers about a discovered peripheral during scanning.
    func centralManager(_ central: CBCentralManager,
                       didDiscover peripheral: CBPeripheral,
                       advertisementData: [String: Any],
                       rssi RSSI: NSNumber) {
        let device = getOrCreateDevice(peripheral: peripheral, rssi: RSSI)

        var currentDevices = discoveredDevicesRelay.value
        if !currentDevices.contains(where: { $0.identifier == device.identifier }) {
            currentDevices.append(device)
            discoveredDevicesRelay.accept(currentDevices)
        }
    }

    /// Notifies subscribers that the central manager connected to a peripheral.
    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let device = deviceCache[peripheral.identifier] {
            device.updateState(.connected)
            connectedDeviceRelay.accept(device)
        }
    }

    /// Notifies subscribers that the central manager disconnected from a peripheral.
    func centralManager(_ central: CBCentralManager,
                       didDisconnectPeripheral peripheral: CBPeripheral,
                       error: Error?) {
        if let device = deviceCache[peripheral.identifier] {
            device.updateState(.disconnected)
            if connectedDeviceRelay.value?.identifier == device.identifier {
                connectedDeviceRelay.accept(nil)
            }
        }
    }

    /// Notifies subscribers that connecting to a peripheral failed.
    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        if let device = deviceCache[peripheral.identifier] {
            device.updateState(.disconnected)
        }
    }
}
