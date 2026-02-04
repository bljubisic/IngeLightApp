//
//  BluetoothCharacteristicProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

protocol BluetoothCharacteristicProtocol {
    var uuid: CBUUID { get }
    var properties: CBCharacteristicProperties { get }
    var value: Observable<Data?> { get }
    var characteristic: CBCharacteristic { get }
    var isNotifying: Bool { get }

    func readValue() -> Single<Data?>
    func writeValue(_ data: Data, type: CBCharacteristicWriteType) -> Completable
    func setNotifyValue(_ enabled: Bool) -> Completable
}
