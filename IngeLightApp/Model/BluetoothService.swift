//
//  BluetoothService.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift
import RxCocoa

final class BluetoothService: BluetoothServiceProtocol {
    // Unique identifier of this service.
    let uuid: CBUUID
    // Whether this service is a primary service.
    let isPrimary: Bool
    // The underlying CoreBluetooth service.
    let service: CBService

    // Relay emitting the discovered characteristics of this service to subscribers.
    let characteristicsRelay = BehaviorRelay<[BluetoothCharacteristicProtocol]>(value: [])
    /// The characteristics of this service as an observable sequence.
    var characteristics: Observable<[BluetoothCharacteristicProtocol]> {
        characteristicsRelay.asObservable()
    }

    // Weak reference to the parent peripheral (services are scoped per peripheral).
    private weak var peripheral: CBPeripheral?
    // RxSwift dispose bag used to dispose subscriptions.
    private let disposeBag = DisposeBag()
    // Cache of wrapped characteristics keyed by characteristic UUID.
    private var characteristicCache: [CBUUID: BluetoothCharacteristic] = [:]

    init(service: CBService, peripheral: CBPeripheral) {
        // Adopt the CoreBluetooth service and keep a reference to its parent peripheral.
        self.service = service
        self.uuid = service.uuid
        self.isPrimary = service.isPrimary
        self.peripheral = peripheral
    }

    /// Updates the characteristic cache and emits the discovered characteristics.
    /// - Parameter characteristics: The list of discovered CoreBluetooth characteristics.
    func updateCharacteristics(_ characteristics: [CBCharacteristic]) {
        guard let peripheral = peripheral else { return }

        let wrappedCharacteristics = characteristics.map { characteristic -> BluetoothCharacteristic in
            if let cached = characteristicCache[characteristic.uuid] {
                return cached
            } else {
                let newChar = BluetoothCharacteristic(characteristic: characteristic, peripheral: peripheral)
                characteristicCache[characteristic.uuid] = newChar
                return newChar
            }
        }
        characteristicsRelay.accept(wrappedCharacteristics)
    }

    /// Returns the cached characteristic for the given UUID.
    /// - Parameter uuid: The UUID of the characteristic to look up.
    /// - Returns: The matching BluetoothCharacteristic, or nil if not cached.
    func getCharacteristic(for uuid: CBUUID) -> BluetoothCharacteristicProtocol? {
        return characteristicCache[uuid]
    }

    /// Discovers the characteristics of this service.
    /// - Returns: A single that emits the discovered characteristics once available.
    func discoverCharacteristics() -> Single<[BluetoothCharacteristicProtocol]> {
        return Single.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.failure(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.discoverCharacteristics(nil, for: self.service)

            // Wait for the first characteristic emission, which signals discovery completion.
            let subscription = self.characteristics
                .skip(1)
                .take(1)
                .subscribe(onNext: { characteristics in
                    observer(.success(characteristics))
                })

            return subscription
        }
    }
}
