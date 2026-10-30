//
//  BluetoothCharacteristic.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift
import RxCocoa

final class BluetoothCharacteristic: BluetoothCharacteristicProtocol {
    // Unique identifier of this characteristic.
    let uuid: CBUUID
    // The properties (read/write/notify) supported by this characteristic.
    let properties: CBCharacteristicProperties
    // The underlying CoreBluetooth characteristic.
    let characteristic: CBCharacteristic

    // Relay emitting the latest value of the characteristic to subscribers.
    private let valueRelay = BehaviorRelay<Data?>(value: nil)
    /// The current value of the characteristic as an observable sequence.
    var value: Observable<Data?> {
        valueRelay.asObservable()
    }

    // Whether the characteristic is currently notifying.
    var isNotifying: Bool {
        characteristic.isNotifying
    }

    // Weak reference to the parent peripheral (reads/writes are scoped per peripheral).
    private weak var peripheral: CBPeripheral?
    // RxSwift dispose bag used to dispose subscriptions.
    private let disposeBag = DisposeBag()

    init(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        // Adopt the CoreBluetooth characteristic and its initial value.
        self.characteristic = characteristic
        self.uuid = characteristic.uuid
        self.properties = characteristic.properties
        self.peripheral = peripheral

        if let value = characteristic.value {
            valueRelay.accept(value)
        }
    }

    /// Updates the cached value of the characteristic.
    /// - Parameter data: The new value to emit.
    func updateValue(_ data: Data?) {
        valueRelay.accept(data)
    }

    /// Reads the value of the characteristic from the peripheral.
    /// - Returns: A single that emits the read value.
    func readValue() -> Single<Data?> {
        return Single.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.failure(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.readValue(for: self.characteristic)

            // Wait for the first value emission, which signals the read completion.
            let subscription = self.value
                .skip(1)
                .take(1)
                .subscribe(onNext: { value in
                    observer(.success(value))
                })

            return subscription
        }
    }

    /// Writes a value to the characteristic.
    /// - Parameters:
    ///   - data: The data to write.
    ///   - type: The write type (with or without response).
    /// - Returns: A completable that completes once the write is done.
    func writeValue(_ data: Data, type: CBCharacteristicWriteType) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.writeValue(data, for: self.characteristic, type: type)

            // Writes without a response complete immediately; others complete on confirmation.
            if type == .withoutResponse {
                observer(.completed)
            }

            return Disposables.create()
        }
    }

    /// Enables or disables notifications for this characteristic.
    /// - Parameter enabled: Whether notifications should be enabled.
    /// - Returns: A completable that completes once the notification state is set.
    func setNotifyValue(_ enabled: Bool) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.setNotifyValue(enabled, for: self.characteristic)
            observer(.completed)

            return Disposables.create()
        }
    }
}

enum BluetoothError: Error {
    // The peripheral is no longer available.
    case peripheralNotAvailable
    // The operation requires a connected device.
    case deviceNotConnected
    // The requested service was not found.
    case serviceNotFound
    // The requested characteristic was not found.
    case characteristicNotFound
    // The data is invalid.
    case invalidData
    // The scan failed.
    case scanningFailed
    // The connection failed.
    case connectionFailed
    // An unknown error occurred.
    case unknown
}
