//
//  PresenceServiceProtocol.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.10.26.
//

import Foundation
import RxSwift

/// Protocol for a source of the user's Microsoft Teams presence.
protocol PresenceServiceProtocol {
    /// The current presence status, or nil while no presence source is available.
    var status: Observable<TeamPresenceStatus?> { get }

    /// Starts listening for presence updates.
    func start()

    /// Stops listening for presence updates.
    func stop()
}
