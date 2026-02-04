//
//  PeripheralListViewModel.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.01.26.
//

import CoreBluetooth
import Foundation
import SwiftUI
import RxSwift
import RxCocoa

@Observable
final class PeripheralListViewModel {
    private let bluetoothManager: BluetoothManagerProtocol
    private let disposeBag = DisposeBag()

    private(set) var state: CBManagerState = .unknown
    private(set) var displayedDevices: [BluetoothDeviceProtocol] = []
    private(set) var connectedDevice: BluetoothDeviceProtocol?
    private(set) var discoveredServices: [BluetoothServiceProtocol] = []
    private(set) var errorMessage: String?

    init(bluetoothManager: BluetoothManagerProtocol = BluetoothManager()) {
        self.bluetoothManager = bluetoothManager
        setupBindings()
    }

    private func setupBindings() {
        bluetoothManager.state
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] state in
                self?.state = state
            })
            .disposed(by: disposeBag)

        bluetoothManager.discoveredDevices
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] devices in
                self?.displayedDevices = devices
            })
            .disposed(by: disposeBag)

        bluetoothManager.connectedDevice
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] device in
                self?.connectedDevice = device
                self?.setupDeviceBinding(device)
            })
            .disposed(by: disposeBag)
    }

    private func setupDeviceBinding(_ device: BluetoothDeviceProtocol?) {
        guard let device = device else {
            discoveredServices = []
            return
        }

        device.services
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] services in
                self?.discoveredServices = services
            })
            .disposed(by: disposeBag)
    }

    func scan() {
        bluetoothManager.startScanning(services: nil)
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                self?.errorMessage = nil
            }, onError: { [weak self] error in
                self?.errorMessage = "Scanning failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }

    func stopScan() {
        bluetoothManager.stopScanning()
    }

    func connect(to device: BluetoothDeviceProtocol) {
        stopScan()

        bluetoothManager.connect(to: device)
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                self?.errorMessage = nil
                self?.discoverServices(for: device)
            }, onError: { [weak self] error in
                self?.errorMessage = "Connection failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }

    func disconnect(from device: BluetoothDeviceProtocol) {
        bluetoothManager.disconnect(from: device)
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                self?.errorMessage = nil
                self?.discoveredServices = []
            }, onError: { [weak self] error in
                self?.errorMessage = "Disconnection failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }

    private func discoverServices(for device: BluetoothDeviceProtocol) {
        device.discoverServices()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { [weak self] services in
                self?.discoveredServices = services
            }, onFailure: { [weak self] error in
                self?.errorMessage = "Service discovery failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }

    func readCharacteristic(_ characteristic: BluetoothCharacteristicProtocol) {
        characteristic.readValue()
            .observe(on: MainScheduler.instance)
            .subscribe(onSuccess: { data in
                if let data = data {
                    print("Read value: \(data.map { String(format: "%02x", $0) }.joined())")
                }
            }, onFailure: { [weak self] error in
                self?.errorMessage = "Read failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }

    func writeCharacteristic(_ characteristic: BluetoothCharacteristicProtocol, data: Data) {
        characteristic.writeValue(data, type: .withResponse)
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                self?.errorMessage = nil
            }, onError: { [weak self] error in
                self?.errorMessage = "Write failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }

    func setNotify(_ enabled: Bool, for characteristic: BluetoothCharacteristicProtocol) {
        characteristic.setNotifyValue(enabled)
            .observe(on: MainScheduler.instance)
            .subscribe(onCompleted: { [weak self] in
                self?.errorMessage = nil
            }, onError: { [weak self] error in
                self?.errorMessage = "Notify setup failed: \(error.localizedDescription)"
            })
            .disposed(by: disposeBag)
    }
}


