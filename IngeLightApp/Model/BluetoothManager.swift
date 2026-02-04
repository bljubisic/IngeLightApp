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
    private let centralManager: CBCentralManager

    private let stateRelay = BehaviorRelay<CBManagerState>(value: .unknown)
    var state: Observable<CBManagerState> {
        stateRelay.asObservable()
    }

    private let discoveredDevicesRelay = BehaviorRelay<[BluetoothDeviceProtocol]>(value: [])
    var discoveredDevices: Observable<[BluetoothDeviceProtocol]> {
        discoveredDevicesRelay.asObservable()
    }

    private let connectedDeviceRelay = BehaviorRelay<BluetoothDeviceProtocol?>(value: nil)
    var connectedDevice: Observable<BluetoothDeviceProtocol?> {
        connectedDeviceRelay.asObservable()
    }

    private var deviceCache: [UUID: BluetoothDevice] = [:]
    private let disposeBag = DisposeBag()

    override init() {
        centralManager = CBCentralManager(delegate: nil, queue: nil)
        super.init()
        centralManager.delegate = self
    }

    func startScanning(services: [CBUUID]? = nil) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(BluetoothError.unknown))
                return Disposables.create()
            }

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

    func stopScanning() {
        centralManager.stopScan()
    }

    func connect(to device: BluetoothDeviceProtocol) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(BluetoothError.unknown))
                return Disposables.create()
            }

            self.centralManager.connect(device.peripheral, options: nil)

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

    func disconnect(from device: BluetoothDeviceProtocol) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self else {
                observer(.error(BluetoothError.unknown))
                return Disposables.create()
            }

            self.centralManager.cancelPeripheralConnection(device.peripheral)

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

    private func getOrCreateDevice(peripheral: CBPeripheral, rssi: NSNumber) -> BluetoothDevice {
        if let existingDevice = deviceCache[peripheral.identifier] {
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
    func centralManagerDidUpdateState(_ central: CBCentralManager) {
        stateRelay.accept(central.state)
    }

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

    func centralManager(_ central: CBCentralManager, didConnect peripheral: CBPeripheral) {
        if let device = deviceCache[peripheral.identifier] {
            device.updateState(.connected)
            connectedDeviceRelay.accept(device)
        }
    }

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

    func centralManager(_ central: CBCentralManager,
                       didFailToConnect peripheral: CBPeripheral,
                       error: Error?) {
        if let device = deviceCache[peripheral.identifier] {
            device.updateState(.disconnected)
        }
    }
}
