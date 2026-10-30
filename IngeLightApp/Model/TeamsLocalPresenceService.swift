//
//  TeamsLocalPresenceService.swift
//  IngeLightApp
//
//  Created by Bratislav Ljubisic on 30.10.26.
//

import Foundation
import RxSwift
import RxCocoa

/// The presence statuses derived from the Microsoft Teams meeting state.
enum TeamPresenceStatus: Equatable {
    // Not in a meeting.
    case available
    // In a meeting.
    case busy
    // Sharing the screen or recording a meeting.
    case doNotDisturb
    // Teams is not reachable (not running, or the local API is disabled).
    case unknown
}

extension TeamPresenceStatus {
    /// Maps a Teams presence status to the Busy Status characteristic value.
    var busyStatusValue: String {
        switch self {
        case .available:
            return "free"
        case .busy:
            return "busy"
        case .doNotDisturb:
            return "dnd"
        case .unknown:
            return "unknown"
        }
    }
}

/// Listens to the Microsoft Teams third-party local API running on the same Mac.
///
/// The API must be enabled in Teams under Settings → Privacy → Manage API.
/// The first connection has to be approved in Teams; the pairing token is then stored and reused.
final class TeamsLocalPresenceService: PresenceServiceProtocol {
    // The Teams local API WebSocket endpoint.
    private let endpoint = "ws://127.0.0.1:8124"
    // UserDefaults key under which the pairing token is stored.
    private let tokenKey = "TeamsLocalAPIToken"
    // The longest delay between reconnection attempts, in seconds.
    private let maxReconnectDelay: TimeInterval = 30

    // Relay emitting the latest presence status to subscribers.
    private let statusRelay = BehaviorRelay<TeamPresenceStatus?>(value: nil)
    /// The current presence status, or nil until Teams has been reached.
    var status: Observable<TeamPresenceStatus?> {
        statusRelay.asObservable().distinctUntilChanged()
    }

    // The active WebSocket connection, if any.
    private var task: URLSessionWebSocketTask?
    // Whether the service should keep the connection alive.
    private var isRunning = false
    // The delay before the next reconnection attempt.
    private var reconnectDelay: TimeInterval = 1
    // Increasing identifier attached to outgoing requests.
    private var requestId = 0
    // Persistent storage for the pairing token.
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Connects to Teams and keeps reconnecting until stopped.
    func start() {
        guard !isRunning else { return }
        isRunning = true
        connect()
    }

    /// Closes the connection to Teams.
    func stop() {
        isRunning = false
        task?.cancel(with: .goingAway, reason: nil)
        task = nil
        statusRelay.accept(nil)
    }

    // Opens the WebSocket connection with the stored pairing token, if any.
    private func connect() {
        guard isRunning, let url = makeURL() else { return }

        let task = URLSession.shared.webSocketTask(with: url)
        self.task = task
        task.resume()
        receive(on: task)
        // Ask Teams for the current state; in a meeting this also triggers the pairing prompt.
        send(action: "query-state", on: task)
    }

    // Builds the connection URL including the client description required by Teams.
    private func makeURL() -> URL? {
        var components = URLComponents(string: endpoint)
        components?.queryItems = [
            URLQueryItem(name: "token", value: defaults.string(forKey: tokenKey) ?? ""),
            URLQueryItem(name: "protocol-version", value: "2.0.0"),
            URLQueryItem(name: "manufacturer", value: "IngeLight"),
            URLQueryItem(name: "device", value: "Mac"),
            URLQueryItem(name: "app", value: "IngeLightApp"),
            URLQueryItem(name: "app-version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0")
        ]
        return components?.url
    }

    // Sends an action request to Teams.
    private func send(action: String, on task: URLSessionWebSocketTask) {
        requestId += 1
        let message = "{\"action\":\"\(action)\",\"parameters\":{},\"requestId\":\(requestId)}"
        task.send(.string(message)) { _ in
            // Send failures surface as receive failures, which trigger the reconnect.
        }
    }

    // Receives the next message and schedules the following receive.
    private func receive(on task: URLSessionWebSocketTask) {
        // The service stays alive until the pending receive returns; cancelling the task in stop() ends it.
        task.receive { result in
            Task { @MainActor in
                // Ignore callbacks from a connection that has since been replaced or closed.
                guard self.task === task else { return }

                switch result {
                case .success(let message):
                    self.reconnectDelay = 1
                    self.handle(message)
                    self.receive(on: task)
                case .failure:
                    self.handleDisconnect()
                }
            }
        }
    }

    // Decodes a Teams message and updates the token or the presence status.
    private func handle(_ message: URLSessionWebSocketTask.Message) {
        let data: Data
        switch message {
        case .string(let text):
            data = Data(text.utf8)
        case .data(let raw):
            data = raw
        @unknown default:
            return
        }

        guard let decoded = try? JSONDecoder().decode(TeamsLocalMessage.self, from: data) else {
            return
        }

        if let token = decoded.tokenRefresh {
            defaults.set(token, forKey: tokenKey)
        }

        if let state = decoded.meetingUpdate?.meetingState {
            statusRelay.accept(state.presenceStatus)
        }
    }

    // Marks Teams as unreachable and retries with an increasing delay.
    private func handleDisconnect() {
        task = nil
        guard isRunning else { return }

        statusRelay.accept(.unknown)

        let delay = reconnectDelay
        reconnectDelay = min(reconnectDelay * 2, maxReconnectDelay)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.connect()
        }
    }
}

/// Message shape sent by the Teams local API.
private struct TeamsLocalMessage: Decodable {
    struct MeetingUpdate: Decodable {
        let meetingState: MeetingState?
    }

    struct MeetingState: Decodable {
        let isInMeeting: Bool?
        let isSharing: Bool?
        let isRecordingOn: Bool?

        // Sharing or recording is treated as do-not-disturb, any other meeting as busy.
        var presenceStatus: TeamPresenceStatus {
            guard isInMeeting == true else { return .available }
            if isSharing == true || isRecordingOn == true {
                return .doNotDisturb
            }
            return .busy
        }
    }

    let meetingUpdate: MeetingUpdate?
    let tokenRefresh: String?
}
