# Model Layer Usage Guide

## Overview
The IngeLightApp now has a comprehensive Model layer built with RxSwift that provides a clean, reactive interface for Bluetooth operations.

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                         View                             │
│                  (BluetoothList.swift)                   │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                     ViewModel                            │
│             (PeripheralListViewModel.swift)              │
└──────────────────────┬──────────────────────────────────┘
                       │
┌──────────────────────▼──────────────────────────────────┐
│                       Model                              │
│  ┌────────────────────────────────────────────────┐     │
│  │         BluetoothManager (Manager)             │     │
│  └────┬───────────────────────────────────────────┘     │
│       │                                                  │
│  ┌────▼──────────────────────────────────────────┐      │
│  │        BluetoothDevice (Device)               │      │
│  └────┬──────────────────────────────────────────┘      │
│       │                                                  │
│  ┌────▼──────────────────────────────────────────┐      │
│  │        BluetoothService (Service)             │      │
│  └────┬──────────────────────────────────────────┘      │
│       │                                                  │
│  ┌────▼──────────────────────────────────────────┐      │
│  │   BluetoothCharacteristic (Characteristic)    │      │
│  └───────────────────────────────────────────────┘      │
└─────────────────────────────────────────────────────────┘
```

## Protocols

### BluetoothManagerProtocol
Main interface for Bluetooth operations:
- `state: Observable<CBManagerState>` - Current Bluetooth state
- `discoveredDevices: Observable<[BluetoothDeviceProtocol]>` - List of discovered devices
- `connectedDevice: Observable<BluetoothDeviceProtocol?>` - Currently connected device
- `startScanning(services:) -> Completable` - Start scanning for devices
- `stopScanning()` - Stop scanning
- `connect(to:) -> Completable` - Connect to a device
- `disconnect(from:) -> Completable` - Disconnect from a device

### BluetoothDeviceProtocol
Represents a Bluetooth device:
- `identifier: UUID` - Unique device identifier
- `name: String?` - Device name
- `rssi: Observable<Int>` - Signal strength
- `state: Observable<CBPeripheralState>` - Connection state
- `services: Observable<[BluetoothServiceProtocol]>` - Available services
- `connect() -> Completable` - Connect to this device
- `disconnect() -> Completable` - Disconnect from this device
- `discoverServices() -> Single<[BluetoothServiceProtocol]>` - Discover services

### BluetoothServiceProtocol
Represents a BLE service:
- `uuid: CBUUID` - Service UUID
- `isPrimary: Bool` - Whether this is a primary service
- `characteristics: Observable<[BluetoothCharacteristicProtocol]>` - Available characteristics
- `discoverCharacteristics() -> Single<[BluetoothCharacteristicProtocol]>` - Discover characteristics

### BluetoothCharacteristicProtocol
Represents a BLE characteristic:
- `uuid: CBUUID` - Characteristic UUID
- `properties: CBCharacteristicProperties` - Supported operations
- `value: Observable<Data?>` - Current value
- `isNotifying: Bool` - Whether notifications are enabled
- `readValue() -> Single<Data?>` - Read the characteristic value
- `writeValue(_:type:) -> Completable` - Write to the characteristic
- `setNotifyValue(_:) -> Completable` - Enable/disable notifications

## Usage Examples

### 1. Initialize the Manager

```swift
// The ViewModel already does this for you
let viewModel = PeripheralListViewModel()
```

### 2. Start Scanning for Devices

```swift
viewModel.scan()

// The ViewModel subscribes to:
// - discoveredDevices: Updates displayedDevices
// - state: Updates Bluetooth state
```

### 3. Connect to a Device

```swift
let device = viewModel.displayedDevices.first!
viewModel.connect(to: device)

// Automatically:
// - Stops scanning
// - Establishes connection
// - Discovers services
// - Updates connectedDevice
```

### 4. Read a Characteristic

```swift
viewModel.readCharacteristic(characteristic)

// Or directly on the characteristic:
characteristic.readValue()
    .subscribe(onSuccess: { data in
        print("Value: \(data)")
    })
    .disposed(by: disposeBag)
```

### 5. Write to a Characteristic

```swift
let data = Data([0x01, 0x02, 0x03])
viewModel.writeCharacteristic(characteristic, data: data)

// Or directly:
characteristic.writeValue(data, type: .withResponse)
    .subscribe(onCompleted: {
        print("Write successful")
    })
    .disposed(by: disposeBag)
```

### 6. Subscribe to Characteristic Updates

```swift
characteristic.value
    .subscribe(onNext: { data in
        if let data = data {
            print("New value: \(data.hexString)")
        }
    })
    .disposed(by: disposeBag)

// Enable notifications
viewModel.setNotify(true, for: characteristic)
```

### 7. Observe Connection State

```swift
device.state
    .subscribe(onNext: { state in
        switch state {
        case .connected:
            print("Device connected")
        case .disconnected:
            print("Device disconnected")
        case .connecting:
            print("Connecting...")
        case .disconnecting:
            print("Disconnecting...")
        @unknown default:
            break
        }
    })
    .disposed(by: disposeBag)
```

### 8. Disconnect from Device

```swift
if let connectedDevice = viewModel.connectedDevice {
    viewModel.disconnect(from: connectedDevice)
}
```

## RxSwift Benefits

1. **Reactive State Updates**: All properties are observable, so UI automatically updates
2. **Async Operations**: Completable and Single make async operations clean
3. **Error Handling**: Proper error propagation through the reactive chain
4. **Memory Management**: DisposeBag handles subscription cleanup
5. **Threading**: Easy to switch between threads with `observe(on:)`
6. **Testability**: Easy to mock observables for unit tests

## Error Handling

All errors are typed with the `BluetoothError` enum:
- `peripheralNotAvailable` - Device is no longer available
- `deviceNotConnected` - Operation requires connection
- `serviceNotFound` - Requested service doesn't exist
- `characteristicNotFound` - Requested characteristic doesn't exist
- `invalidData` - Data format is invalid
- `scanningFailed` - Scanning couldn't start
- `connectionFailed` - Connection attempt failed
- `unknown` - Unexpected error

## Testing

To test with mock implementations:

```swift
class MockBluetoothManager: BluetoothManagerProtocol {
    let state = BehaviorRelay<CBManagerState>(value: .poweredOn)
    let discoveredDevices = BehaviorRelay<[BluetoothDeviceProtocol]>(value: [])
    let connectedDevice = BehaviorRelay<BluetoothDeviceProtocol?>(value: nil)

    func startScanning(services: [CBUUID]?) -> Completable {
        return .empty()
    }

    // ... implement other methods
}

let viewModel = PeripheralListViewModel(bluetoothManager: MockBluetoothManager())
```

## Best Practices

1. Always dispose subscriptions using `disposed(by: disposeBag)`
2. Use `observe(on: MainScheduler.instance)` for UI updates
3. Handle errors in subscribe blocks
4. Use weak self in closures to prevent retain cycles
5. Check device state before operations
6. Stop scanning when connecting to save battery
7. Disconnect devices when done to free resources

## File Structure

```
IngeLightApp/
├── Model/
│   ├── Protocols/
│   │   ├── BluetoothManagerProtocol.swift
│   │   ├── BluetoothDeviceProtocol.swift
│   │   ├── BluetoothServiceProtocol.swift
│   │   └── BluetoothCharacteristicProtocol.swift
│   ├── BluetoothManager.swift
│   ├── BluetoothDevice.swift
│   ├── BluetoothService.swift
│   └── BluetoothCharacteristic.swift
├── ViewModel/
│   └── PeripheralListViewModel.swift
└── View/
    ├── BluetoothList.swift
    └── CharacteristicsList.swift
```
