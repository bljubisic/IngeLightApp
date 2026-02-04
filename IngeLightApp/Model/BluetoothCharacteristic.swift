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
    let uuid: CBUUID
    let properties: CBCharacteristicProperties
    let characteristic: CBCharacteristic

    private let valueRelay = BehaviorRelay<Data?>(value: nil)
    var value: Observable<Data?> {
        valueRelay.asObservable()
    }

    var isNotifying: Bool {
        characteristic.isNotifying
    }

    private weak var peripheral: CBPeripheral?
    private let disposeBag = DisposeBag()

    init(characteristic: CBCharacteristic, peripheral: CBPeripheral) {
        self.characteristic = characteristic
        self.uuid = characteristic.uuid
        self.properties = characteristic.properties
        self.peripheral = peripheral

        if let value = characteristic.value {
            valueRelay.accept(value)
        }
    }

    func updateValue(_ data: Data?) {
        valueRelay.accept(data)
    }

    func readValue() -> Single<Data?> {
        return Single.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.failure(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.readValue(for: self.characteristic)

            let subscription = self.value
                .skip(1)
                .take(1)
                .subscribe(onNext: { value in
                    observer(.success(value))
                })

            return subscription
        }
    }

    func writeValue(_ data: Data, type: CBCharacteristicWriteType) -> Completable {
        return Completable.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.error(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.writeValue(data, for: self.characteristic, type: type)

            if type == .withoutResponse {
                observer(.completed)
            }

            return Disposables.create()
        }
    }

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
    case peripheralNotAvailable
    case deviceNotConnected
    case serviceNotFound
    case characteristicNotFound
    case invalidData
    case scanningFailed
    case connectionFailed
    case unknown
}
