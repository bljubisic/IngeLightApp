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
    let identifier: UUID
    let name: String?
    let peripheral: CBPeripheral

    private let rssiRelay = BehaviorRelay<Int>(value: 0)
    var rssi: Observable<Int> {
        rssiRelay.asObservable()
    }

    private let stateRelay = BehaviorRelay<CBPeripheralState>(value: .disconnected)
    var state: Observable<CBPeripheralState> {
        stateRelay.asObservable()
    }

    private let servicesRelay = BehaviorRelay<[BluetoothServiceProtocol]>(value: [])
    var services: Observable<[BluetoothServiceProtocol]> {
        servicesRelay.asObservable()
    }

    private weak var centralManager: CBCentralManager?
    private let disposeBag = DisposeBag()

    init(peripheral: CBPeripheral, rssi: NSNumber, centralManager: CBCentralManager) {
        self.peripheral = peripheral
        self.identifier = peripheral.identifier
        self.name = peripheral.name
        self.centralManager = centralManager

        super.init()

        self.peripheral.delegate = self
        rssiRelay.accept(rssi.intValue)
        stateRelay.accept(peripheral.state)
    }

    func updateRSSI(_ rssi: NSNumber) {
        rssiRelay.accept(rssi.intValue)
    }

    func updateState(_ state: CBPeripheralState) {
        stateRelay.accept(state)
    }

    func updateServices(_ services: [CBService]) {
        let wrappedServices = services.map { service in
            BluetoothService(service: service, peripheral: peripheral)
        }
        servicesRelay.accept(wrappedServices)
    }

    func connect() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let centralManager = self.centralManager else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            centralManager.connect(self.peripheral, options: nil)

            let subscription = self.state
                .filter { $0 == .connected }
                .take(1)
                .subscribe(onNext: { _ in
                    observer(.completed)
                })

            return subscription
        }
    }

    func disconnect() -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let centralManager = self.centralManager else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            centralManager.cancelPeripheralConnection(self.peripheral)

            let subscription = self.state
                .filter { $0 == .disconnected }
                .take(1)
                .subscribe(onNext: { _ in
                    observer(.completed)
                })

            return subscription
        }
    }

    func discoverServices() -> Single<[BluetoothServiceProtocol]> {
        return Single.create { [weak self] observer in
            guard let self = self else {
                observer(.failure(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            self.peripheral.discoverServices(nil)

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
    func peripheral(_ peripheral: CBPeripheral, didDiscoverServices error: Error?) {
        guard error == nil, let services = peripheral.services else {
            return
        }
        updateServices(services)

        for service in services {
            peripheral.discoverCharacteristics(nil, for: service)
        }
    }

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

    func peripheral(_ peripheral: CBPeripheral, didWriteValueFor characteristic: CBCharacteristic, error: Error?) {
    }

    func peripheral(_ peripheral: CBPeripheral,
                    didUpdateNotificationStateFor characteristic: CBCharacteristic,
                    error: Error?) {
    }
}
