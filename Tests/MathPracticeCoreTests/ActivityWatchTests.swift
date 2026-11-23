//  ActivityWatchTests.swift
//  The ActivityWatch payload and the "send a heartbeat now?" decision.

import Foundation
import Testing
@testable import MathPracticeCore

@Suite("ActivityWatch heartbeats")
struct ActivityWatchTests {
    let t0 = Date(timeIntervalSince1970: 1_800_000_000)

    func context(
        tab: ActivityTab = .practice,
        className: String = "Data - POGO 511",
        problem: String = "VYKYMF4C"
    ) -> ActivityContext {
        ActivityContextBuilder.make(
            tab: tab,
            selection: .pickers(topic: "Derivatives", subtype: "Quotient rule"),
            level: 5,
            problemID: problem,
            className: className
        )
    }

    // MARK: Payload

    @Test("Payload carries every field, level as a string")
    func payloadFields() {
        let data = context().data
        #expect(data == [
            "class": "Data - POGO 511",
            "tab": "Practice",
            "topic": "Derivatives",
            "subtype": "Quotient rule",
            "level": "5",
            "problem": "VYKYMF4C",
            "mode": "practice"
        ])
    }

    @Test("Each tab maps to its mode", arguments: [
        (ActivityTab.practice, "Practice", "practice"),
        (.progress, "Progress", "review"),
        (.sessions, "Sessions", "review"),
        (.key, "Key", "review"),
        (.worksheets, "Worksheets", "worksheet"),
        (.settings, "Settings", "practice")
    ])
    func tabModes(tab: ActivityTab, tabName: String, mode: String) {
        let data = context(tab: tab).data
        #expect(data["tab"] == tabName)
        #expect(data["mode"] == mode)
    }

    @Test("Every mode is reachable from some tab")
    func everyModeReachable() {
        #expect(Set(ActivityTab.allCases.map(\.mode)) == Set(ActivityMode.allCases))
    }

    @Test("Custom mix reports 'custom mix' with the checked sub-types comma-separated")
    func customMix() {
        let ctx = ActivityContextBuilder.make(
            tab: .practice,
            selection: .customMix(subtypes: ["Derivatives · Chain rule", "Derivatives · Quotient rule"]),
            level: 4,
            problemID: nil,
            className: "Econ - PUBP 720"
        )
        #expect(ctx.data["topic"] == "custom mix")
        #expect(ctx.data["subtype"] == "Derivatives · Chain rule, Derivatives · Quotient rule")
        #expect(ctx.data["problem"] == "")
        #expect(ctx.data["level"] == "4")
    }

    @Test("Unselected pickers report 'random mix'")
    func randomMix() {
        let ctx = ActivityContextBuilder.make(
            tab: .practice, selection: .pickers(topic: nil, subtype: nil), level: nil, problemID: nil, className: ""
        )
        #expect(ctx.data["topic"] == "random mix")
        #expect(ctx.data["subtype"] == "random mix")
        #expect(ctx.data["level"] == "")
    }

    @Test("An empty class is sent as an empty string")
    func emptyClass() {
        #expect(context(className: "").data["class"] == "")
    }

    @Test("Heartbeat body has timestamp, zero duration and the data object")
    func heartbeatBody() throws {
        let body = try ActivityWatchAPI.heartbeatBody(Heartbeat(timestamp: t0, context: context()))
        let json = try #require(JSONSerialization.jsonObject(with: body) as? [String: Any])
        #expect(json["duration"] as? Int == 0)
        #expect((json["timestamp"] as? String)?.hasPrefix("2027-01-15T08:00:00") == true)
        #expect(json["data"] as? [String: String] == context().data)
    }

    // MARK: Class resolution

    @Test("Worksheet tag beats session tag beats default")
    func classResolution() {
        #expect(ActivityClass.resolve(worksheetTag: "RD - POGO 801", sessionTag: "Econ - PUBP 720", defaultClass: "D") == "RD - POGO 801")
        #expect(ActivityClass.resolve(worksheetTag: nil, sessionTag: "Econ - PUBP 720", defaultClass: "D") == "Econ - PUBP 720")
        #expect(ActivityClass.resolve(worksheetTag: nil, sessionTag: nil, defaultClass: "D") == "D")
    }

    @Test("An explicit empty tag means no class and is not overridden")
    func explicitNoClass() {
        #expect(ActivityClass.resolve(worksheetTag: "", sessionTag: "Econ - PUBP 720", defaultClass: "D") == "")
        #expect(ActivityClass.resolve(worksheetTag: nil, sessionTag: "", defaultClass: "D") == "")
    }

    // MARK: Bucket and pulsetime

    @Test("Bucket name, type and client")
    func bucket() {
        #expect(ActivityWatchAPI.bucketID(hostname: "Joshs-Mac") == "aw-watcher-mathpractice_Joshs-Mac")
        #expect(ActivityWatchAPI.bucketBody(hostname: "h") == [
            "client": "math-practice", "type": "app.mathpractice.activity", "hostname": "h"
        ])
    }

    @Test("pulsetime is twice the interval")
    func pulsetime() {
        #expect(ActivityWatchAPI.pulsetime(interval: 30) == 60)
        #expect(ActivityWatchAPI.pulsetimeQuery(interval: 30) == "60")
        #expect(ActivityWatchAPI.pulsetimeQuery(interval: 2.25) == "4.5")
        #expect(ActivityWatchAPI.defaultInterval == 30)
    }

    // MARK: Tracker

    @Test("First context sends at once")
    func firstSend() {
        var tracker = HeartbeatTracker(interval: 30)
        #expect(tracker.update(context(), now: t0) == [Heartbeat(timestamp: t0, context: context())])
    }

    @Test("Same context repeats only once the interval has passed")
    func repeatsOnInterval() {
        var tracker = HeartbeatTracker(interval: 30)
        _ = tracker.update(context(), now: t0)
        #expect(tracker.update(context(), now: t0.addingTimeInterval(10)).isEmpty)
        #expect(tracker.update(context(), now: t0.addingTimeInterval(29.9)).isEmpty)
        let due = t0.addingTimeInterval(30)
        #expect(tracker.update(context(), now: due) == [Heartbeat(timestamp: due, context: context())])
        #expect(tracker.update(context(), now: due.addingTimeInterval(5)).isEmpty)
    }

    @Test("A change closes the old event and opens the new one at the same moment")
    func changeSendsTwo() {
        var tracker = HeartbeatTracker(interval: 30)
        _ = tracker.update(context(), now: t0)
        let changed = context(problem: "ABCD1234")
        let now = t0.addingTimeInterval(3)
        #expect(tracker.update(changed, now: now) == [
            Heartbeat(timestamp: now, context: context()),
            Heartbeat(timestamp: now, context: changed)
        ])
    }

    @Test("Resigning active closes the event, then stays silent")
    func resignActive() {
        var tracker = HeartbeatTracker(interval: 30)
        _ = tracker.update(context(), now: t0)
        let now = t0.addingTimeInterval(7)
        #expect(tracker.update(nil, now: now) == [Heartbeat(timestamp: now, context: context())])
        #expect(tracker.update(nil, now: now.addingTimeInterval(120)).isEmpty)
        #expect(tracker.current == nil)
    }

    @Test("Becoming active again starts a fresh event")
    func reactivate() {
        var tracker = HeartbeatTracker(interval: 30)
        _ = tracker.update(context(), now: t0)
        _ = tracker.update(nil, now: t0.addingTimeInterval(5))
        let back = t0.addingTimeInterval(500)
        #expect(tracker.update(context(), now: back) == [Heartbeat(timestamp: back, context: context())])
    }

    @Test("A class change counts as a context change")
    func classChange() {
        var tracker = HeartbeatTracker(interval: 30)
        _ = tracker.update(context(), now: t0)
        #expect(tracker.update(context(className: ""), now: t0.addingTimeInterval(1)).count == 2)
    }
}
