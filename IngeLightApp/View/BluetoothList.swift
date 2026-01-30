//
//  BluetoothList.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.01.26.
//

import CoreBluetooth
import SwiftUI

struct BluetoothList: View {
    @State var viewModel: PeripheralListViewModel
    
    var body: some View {
        switch viewModel.state {
        case .poweredOn:
            List {
                ForEach(viewModel.displayedPeripherials, id: \.identifier) { peripheral in
                    VStack(alignment: .leading) {
                        Text(peripheral.name ?? "No Name")
                        Text(peripheral.identifier.uuidString)
                            .font(.caption)
                    }
                }
            }.task {
                viewModel.scan()
            }
        default:
            Text("BLE not available")
        }
    }
}
