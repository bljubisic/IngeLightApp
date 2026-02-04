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
    let uuid: CBUUID
    let isPrimary: Bool
    let service: CBService

    let characteristicsRelay = BehaviorRelay<[BluetoothCharacteristicProtocol]>(value: [])
    var characteristics: Observable<[BluetoothCharacteristicProtocol]> {
        characteristicsRelay.asObservable()
    }

    private weak var peripheral: CBPeripheral?
    private let disposeBag = DisposeBag()
    private var characteristicCache: [CBUUID: BluetoothCharacteristic] = [:]

    init(service: CBService, peripheral: CBPeripheral) {
        self.service = service
        self.uuid = service.uuid
        self.isPrimary = service.isPrimary
        self.peripheral = peripheral
    }

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

    func getCharacteristic(for uuid: CBUUID) -> BluetoothCharacteristic? {
        return characteristicCache[uuid]
    }

    func discoverCharacteristics() -> Single<[BluetoothCharacteristicProtocol]> {
        return Single.create { [weak self] observer in
            guard let self = self, let peripheral = self.peripheral else {
                observer(.failure(BluetoothError.peripheralNotAvailable))
                return Disposables.create()
            }

            peripheral.discoverCharacteristics(nil, for: self.service)

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
