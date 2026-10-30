//
//  BluetoothServiceProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

/// Protocol representing a Bluetooth Low Energy service.
protocol BluetoothServiceProtocol {
    /// Unique identifier of the service.
    var uuid: CBUUID { get }
    /// Whether this is a primary service.
    var isPrimary: Bool { get }
    /// The characteristics of this service as an observable sequence.
    var characteristics: Observable<[BluetoothCharacteristicProtocol]> { get }
    /// The underlying CoreBluetooth service.
    var service: CBService { get }

    /// Discovers the characteristics of this service.
    /// - Returns: A single that emits the discovered characteristics.
    func discoverCharacteristics() -> Single<[BluetoothCharacteristicProtocol]>

    /// Returns the cached characteristic for the given UUID.
    /// - Parameter uuid: The UUID of the characteristic to look up.
    /// - Returns: The matching BluetoothCharacteristic, or nil if not cached.
    func getCharacteristic(for uuid: CBUUID) -> BluetoothCharacteristicProtocol?
}
