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
    // The Bluetooth manager used to perform BLE operations.
    private let bluetoothManager: BluetoothManagerProtocol
    // RxSwift dispose bag used to dispose all subscriptions.
    private let disposeBag = DisposeBag()
    // Service providing the person's Microsoft Teams presence.
    private let presenceService: PresenceServiceProtocol

    // The Busy Status characteristic UUID published from the person's Teams presence.
    private let busyStatusUUID = CBUUID(string: "9202d270-84ba-4561-a59d-7919212768a1")

    // The latest Bluetooth state, observed by the UI.
    private(set) var state: CBManagerState = .unknown
    // The devices currently displayed in the list.
    private(set) var displayedDevices: [BluetoothDeviceProtocol] = []
    // The device currently connected, if any.
    private(set) var connectedDevice: BluetoothDeviceProtocol?
    // The services discovered on the connected device.
    private(set) var discoveredServices: [BluetoothServiceProtocol] = []
    // A user-facing error message, if any.
    private(set) var errorMessage: String?

    init(bluetoothManager: BluetoothManagerProtocol = BluetoothManager(),
         presenceService: PresenceServiceProtocol = TeamsLocalPresenceService()) {
        // Store the injected dependencies and set up reactive bindings to their streams.
        self.bluetoothManager = bluetoothManager
        self.presenceService = presenceService
        setupBindings()
        setupPresenceBinding()

        // The Teams local API only exists on the Mac that runs Teams.
        if ProcessInfo.processInfo.isiOSAppOnMac || ProcessInfo.processInfo.isMacCatalystApp {
            presenceService.start()
        }
    }

    // Subscribes to the manager state streams and updates the published state.
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

    // Subscribes to the connected device's services stream and updates the discovered services.
    private func setupDeviceBinding(_ device: BluetoothDeviceProtocol?) {
        guard let device = device else {
            // No device connected, so there is nothing to load services from.
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

    /// Starts a new BLE scan.
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

    /// Stops the ongoing BLE scan.
    func stopScan() {
        bluetoothManager.stopScanning()
    }

    /// Connects to the given device and discovers its services afterwards.
    /// - Parameter device: The device to connect to.
    func connect(to device: BluetoothDeviceProtocol) {
        // Connecting while scanning is wasteful, so stop the scan first.
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

    /// Disconnects from the given device.
    /// - Parameter device: The device to disconnect from.
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

    // Discovers the services of the given device.
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

    // Writes the Teams presence to the Busy Status characteristic whenever either of them changes.
    private func setupPresenceBinding() {
        let busyStatusUUID = self.busyStatusUUID

        // The Busy Status characteristic of the connected device, once its characteristics are discovered.
        let busyCharacteristic = bluetoothManager.connectedDevice
            .flatMapLatest { device -> Observable<BluetoothCharacteristicProtocol?> in
                guard let device else { return .just(nil) }
                return device.services
                    .flatMapLatest { services -> Observable<BluetoothCharacteristicProtocol?> in
                        guard !services.isEmpty else { return .just(nil) }
                        return Observable.combineLatest(services.map { $0.characteristics })
                            .map { $0.joined().first { $0.uuid == busyStatusUUID } }
                    }
            }

        Observable.combineLatest(busyCharacteristic, presenceService.status)
            .map { characteristic, status in (characteristic, status?.busyStatusValue) }
            // Only write when the characteristic or the value actually changes.
            .distinctUntilChanged { previous, current in
                previous.0?.characteristic === current.0?.characteristic && previous.1 == current.1
            }
            .compactMap { characteristic, value -> (BluetoothCharacteristicProtocol, String)? in
                guard let characteristic, let value else { return nil }
                return (characteristic, value)
            }
            .observe(on: MainScheduler.instance)
            .subscribe(onNext: { [weak self] characteristic, value in
                self?.writeCharacteristic(characteristic, data: Data(value.utf8))
            })
            .disposed(by: disposeBag)
    }

    // Reads a characteristic value and reports read failures.
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

    // Writes the given data to a characteristic.
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

    // Enables or disables notifications for a characteristic.
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


