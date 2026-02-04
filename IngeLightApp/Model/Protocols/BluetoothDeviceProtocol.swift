//
//  BluetoothDeviceProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

protocol BluetoothDeviceProtocol {
    var identifier: UUID { get }
    var name: String? { get }
    var rssi: Observable<Int> { get }
    var state: Observable<CBPeripheralState> { get }
    var services: Observable<[BluetoothServiceProtocol]> { get }
    var peripheral: CBPeripheral { get }

    func connect() -> Completable
    func disconnect() -> Completable
    func discoverServices() -> Single<[BluetoothServiceProtocol]>
}
