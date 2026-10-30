//
//  BluetoothCharacteristicProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 04.02.26.
//

import CoreBluetooth
import Foundation
import RxSwift

/// Protocol representing a Bluetooth Low Energy characteristic.
protocol BluetoothCharacteristicProtocol {
    /// Unique identifier of the characteristic.
    var uuid: CBUUID { get }
    /// The properties supported by the characteristic.
    var properties: CBCharacteristicProperties { get }
    /// The current value of the characteristic as an observable sequence.
    var value: Observable<Data?> { get }
    /// The underlying CoreBluetooth characteristic.
    var characteristic: CBCharacteristic { get }
    /// Whether the characteristic is currently notifying.
    var isNotifying: Bool { get }

    /// Updates the current value of the characteristic.
    /// - Parameter data: The new value to emit, or nil when cleared.
    func updateValue(_ data: Data?)

    /// Reads the value of the characteristic.
    /// - Returns: A single that emits the read value.
    func readValue() -> Single<Data?>

    /// Writes a value to the characteristic.
    /// - Parameters:
    ///   - data: The data to write.
    ///   - type: The write type (with or without response).
    /// - Returns: A completable that signals a successful write.
    func writeValue(_ data: Data, type: CBCharacteristicWriteType) -> Completable

    /// Enables or disables notifications for the characteristic.
    /// - Parameter enabled: Whether notifications should be enabled.
    /// - Returns: A completable that signals a successful notify setup.
    func setNotifyValue(_ enabled: Bool) -> Completable
}
