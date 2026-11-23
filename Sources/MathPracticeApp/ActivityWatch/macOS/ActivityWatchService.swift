//  ActivityWatchService.swift
//  Sends heartbeats describing what MathPractice is doing to the local ActivityWatch server,
//  so the Classes dashboard can credit the time to the right class. macOS only —
//  ActivityWatch has no iOS server, so on iOS this file compiles to nothing.
//
//  It must never get in the way: the HTTP calls run off the main thread with a 2 s timeout,
//  a server that isn't running is dropped silently and retried after 15 s, and nothing here
//  ever shows an error, writes to the event log, or touches CloudKit.
//
//  The platform gate is folder-based, like PDF export: the iOS target excludes
//  `ActivityWatch/macOS/**` and compiles the no-op twin in `ActivityWatch/iOS/` instead.

import AppKit
import Foundation
import MathPracticeCore
import Observation

@MainActor
@Observable
final class ActivityWatchService {
    enum Result: Equatable {
        case sent
        case notRunning
    }

    /// For the Settings status line.
    private(set) var bucket: String?
    private(set) var lastHeartbeat: Date?
    private(set) var lastResult: Result?

    /// How often the current context is sampled. Sampling is pure and cheap; a heartbeat is
    /// only sent when the context changes or `HeartbeatTracker.interval` has passed.
    private static let sampleEvery: TimeInterval = 1

    @ObservationIgnored private var tracker = HeartbeatTracker(interval: ActivityWatchAPI.defaultInterval)
    @ObservationIgnored private var sampler: Timer?
    @ObservationIgnored private var sender: Task<Void, Never>?
    @ObservationIgnored private var outbox: AsyncStream<Outgoing>.Continuation?
    @ObservationIgnored private let client = ActivityWatchClient()

    private struct Outgoing: Sendable {
        let heartbeats: [Heartbeat]
        let server: String
        let interval: TimeInterval
    }

    /// Starts sampling. `context` is `nil` when there is nothing to report.
    func start(
        context: @escaping @MainActor () -> ActivityContext?,
        isEnabled: @escaping @MainActor () -> Bool,
        server: @escaping @MainActor () -> String
    ) {
        guard sampler == nil else { return }

        // One consumer drains the outbox in order, so a change's close-then-open pair can
        // never arrive at the server reversed.
        let (stream, continuation) = AsyncStream<Outgoing>.makeStream(bufferingPolicy: .bufferingNewest(20))
        outbox = continuation
        let client = client
        sender = Task.detached(priority: .utility) { [weak self] in
            for await outgoing in stream {
                for heartbeat in outgoing.heartbeats {
                    let outcome = await client.send(heartbeat, server: outgoing.server, interval: outgoing.interval)
                    await self?.record(outcome, at: heartbeat.timestamp)
                }
            }
        }

        let timer = Timer(timeInterval: Self.sampleEvery, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated {
                self?.sample(context: context, isEnabled: isEnabled, server: server)
            }
        }
        // `.common` so sampling carries on while a menu is open or a window is being dragged.
        RunLoop.main.add(timer, forMode: .common)
        sampler = timer
        sample(context: context, isEnabled: isEnabled, server: server)
    }

    private func sample(
        context: @MainActor () -> ActivityContext?,
        isEnabled: @MainActor () -> Bool,
        server: @MainActor () -> String
    ) {
        guard isEnabled() else {
            // Switched off: forget the open event rather than sending a closing heartbeat.
            tracker = HeartbeatTracker(interval: tracker.interval)
            return
        }
        // Only while MathPractice is the active app; resigning active closes the event and
        // then sends nothing until it comes back (the AFK and window watchers cover idle time).
        let current = NSApp.isActive ? context() : nil
        let heartbeats = tracker.update(current, now: Date())
        guard !heartbeats.isEmpty else { return }
        outbox?.yield(Outgoing(heartbeats: heartbeats, server: server(), interval: tracker.interval))
    }

    private func record(_ outcome: ActivityWatchClient.Outcome, at time: Date) {
        switch outcome {
        case let .sent(bucket):
            self.bucket = bucket
            lastHeartbeat = time
            lastResult = .sent
        case .notRunning:
            lastHeartbeat = time
            lastResult = .notRunning
        case .backingOff:
            break
        }
    }
}

/// Loopback HTTP to aw-server's REST API. Serialised by the actor; never on the main thread.
actor ActivityWatchClient {
    enum Outcome: Sendable {
        case sent(bucket: String)
        /// The request failed — ActivityWatch is assumed not to be running.
        case notRunning
        /// Dropped without trying, inside the retry wait after a failure.
        case backingOff
    }

    private static let timeout: TimeInterval = 2
    private static let retryAfter: TimeInterval = 15

    private let session: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()

    private var bucket: String?
    private var bucketServer: String?
    private var retryAt = Date.distantPast

    func send(_ heartbeat: Heartbeat, server: String, interval: TimeInterval) async -> Outcome {
        guard Date() >= retryAt else { return .backingOff }
        do {
            let bucket = try await ensureBucket(server: server)
            let path = "buckets/\(Self.escape(bucket))/heartbeat?pulsetime=\(ActivityWatchAPI.pulsetimeQuery(interval: interval))"
            _ = try await request(server, path, method: "POST", body: ActivityWatchAPI.heartbeatBody(heartbeat))
            return .sent(bucket: bucket)
        } catch {
            retryAt = Date().addingTimeInterval(Self.retryAfter)
            // Check (and if need be recreate) the bucket once ActivityWatch is back.
            bucket = nil
            return .notRunning
        }
    }

    /// The bucket is named after aw-server's own hostname, so it matches the window watcher
    /// on the same Mac. Created on first use; 304 means it was already there.
    private func ensureBucket(server: String) async throws -> String {
        if let bucket, bucketServer == server { return bucket }
        struct Info: Decodable { let hostname: String }
        let info = try JSONDecoder().decode(Info.self, from: try await request(server, "info", method: "GET"))
        let id = ActivityWatchAPI.bucketID(hostname: info.hostname)
        let body = try JSONSerialization.data(withJSONObject: ActivityWatchAPI.bucketBody(hostname: info.hostname))
        _ = try await request(server, "buckets/\(Self.escape(id))", method: "POST", body: body, accept: [304])
        bucket = id
        bucketServer = server
        return id
    }

    private func request(_ server: String, _ path: String, method: String, body: Data? = nil, accept: Set<Int> = []) async throws -> Data {
        let base = server.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let url = URL(string: "\(base)/api/0/\(path)") else { throw URLError(.badURL) }
        var request = URLRequest(url: url, timeoutInterval: Self.timeout)
        request.httpMethod = method
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        let (data, response) = try await session.data(for: request)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode), !accept.contains(http.statusCode) {
            throw URLError(.badServerResponse)
        }
        return data
    }

    private static func escape(_ component: String) -> String {
        component.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed.subtracting(CharacterSet(charactersIn: "/"))) ?? component
    }
}
