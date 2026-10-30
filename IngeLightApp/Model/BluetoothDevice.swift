//
//  BluetoothDevice.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift
import RxCocoa

final class BluetoothDevice: NSObject, BluetoothDeviceProtocol {
    // Unique identifier of this device.
    let identifier: UUID
    // User-facing name of the device, if advertised by the peripheral.
    let name: String?
    // The underlying CoreBluetooth peripheral.
    let peripheral: CBPeripheral

    // Relay emitting the latest signal strength to subscribers.
    private let rssiRelay = BehaviorRelay<Int>(value: 0)
    /// The current signal strength of the device.
    var rssi: Observable<Int> {
        rssiRelay.asObservable()
    }

    // Relay emitting the connection state to subscribers.
    private let stateRelay = BehaviorRelay<CBPeripheralState>(value: .disconnected)
    /// The current connection state of the device.
    var state: Observable<CBPeripheralState> {
        stateRelay.asObservable()
    }

    // Relay emitting the discovered services of this device to subscribers.
    private let servicesRelay = BehaviorRelay<[BluetoothServiceProtocol]>(value: [])
    /// The services discovered on this device.
    var services: Observable<[BluetoothServiceProtocol]> {
        servicesRelay.asObservable()
    }

    // Weak reference to the central manager that owns this device.
    private weak var centralManager: CBCentralManager?
    // RxSwift dispose bag used to dispose subscriptions.
    private let disposeBag = DisposeBag()

    init(peripheral: CBPeripheral, rssi: NSNumber, centralManager: CBCentralManager) {
        // Store the peripheral details and adopt the initial state.
        self.peripheral = peripheral
        self.identifier = peripheral.identifier
        self.name = peripheral.name
        self.centralManager = centralManager

        super.init()

        // The device owns the peripheral delegate callbacks.
        self.peripheral.delegate = self
        rssiRelay.accept(rssi.intValue)
        stateRelay.accept(peripheral.state)
    }

    /// Updates the cached signal strength of the device.
    /// - Parameter rssi: The new signal strength value.
    func updateRSSI(_ rssi: NSNumber) {
        rssiRelay.accept(rssi.intValue)
    }

    /// Updates the connection state of the device.
    /// - Parameter state: The new connection state.
    func updateState(_ state: CBPeripheralState) {
        stateRelay.accept(state)
    }

    /// Replaces the cached list of services with the given ones.
    /// - Parameter services: The discovered CoreBluetooth services.
    func updateServices(_ services: [CBService]) {
        let wrappedServices = services.map { service in
            BluetoothService(service: service, peripheral: peripheral)
        }
        servicesRelay.accept(wrappedServices)
    }

    /// Connects this device via the central manager.
    /// - Returns: A completable that completes once connected.
    func connect() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let centralManager = self.centralManager else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            centralManager.connect(self.peripheral, options: nil)

            // Complete when the device reports being connected.
            let subscription = self.state
                .filter { $0 == .connected }
                .take(1)
                .subscribe(onNext: { _ in
                    observer(.completed)
                })

            return subscription
        }
    }

    /// Disconnects this device via the central manager.
    /// - Returns: A completable that completes once disconnected.
    func disconnect() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let centralManager = self.centralManager else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            centralManager.cancelPeripheralConnection(self.peripheral)

            // Complete when the device reports being disconnected.
            let subscription = self.state
                .filter { $0 == .disconnected }
                .take(1)
                .subscribe(onNext: { _ in
                    observer(.completed)
                })

            return subscription
        }
    }

    /// Discovers the services of this device.
    /// - Returns: A single that emits the discovered services.
    func discoverServices() -> Single<[BluetoothServiceProtocol]> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            self.peripheral.discoverServices(nil)

            // Wait for the first service emission, which signals discovery completion.
            let subscription = self.services
                .skip(1)
                .take(1)
                .subscribe(onNext: { services in
                    observer(.success(services))
                })

            return subscription
        }
    }
}

extension BluetoothDevice: CBPeripheralDelegate {
    /// Notifies that the peripheral discovered its services.
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            return
        }
        updateServices(services)

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

    /// Notifies that the peripheral discovered characteristics for a service.
    func peripheral(_ peripheral: CBPeripheral,
                    didDiscoverCharacteristicsFor service: CBService,
                    error: Error?) {
        guard error == nil, let characteristics = service.characteristics else {
            return
        }

        if let bluetoothService = servicesRelay.value.first(where: { $0.uuid == service.uuid }) as? BluetoothService {
            bluetoothService.updateCharacteristics(characteristics)
        }
    }

    /// Notifies that a characteristic value was updated from the peripheral.
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateValueFor characteristic: CBCharacteristic,
                    error: Error?) {
        guard error == nil else { return }

        for service in servicesRelay.value {
            if let btService = service as? BluetoothService,
               let btChar = btService.getCharacteristic(for: characteristic.uuid) {
                btChar.updateValue(characteristic.value)
            }
        }
    }

    /// Notifies that a characteristic value was written to the peripheral.
    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
        // Value writes are handled through the explicit write flow.
    }

    /// Notifies about updates to the characteristic notification state.
    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
        // Notification state updates are handled through the notify flow.
    }
}
