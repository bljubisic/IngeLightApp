//
//  BluetoothServiceProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

protocol BluetoothServiceProtocol {
    var uuid: CBUUID { get }
    var isPrimary: Bool { get }
    var characteristics: Observable<[BluetoothCharacteristicProtocol]> { get }
    var service: CBService { get }

    func discoverCharacteristics() -> Single<[BluetoothCharacteristicProtocol]>
}
