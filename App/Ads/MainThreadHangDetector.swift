import Combine
import Foundation
import QuartzCore
import UIKit

/// Background watchdog used only under `-uiTestHangDetector`.
///
/// A `CADisplayLink` on the main run loop records heartbeats. A 50 ms timer on a
/// private queue flags a stall when the heartbeat is late by ≥ 250 ms. This is
/// the actual main-thread pause a user would feel; it is independent of
/// XCUITest's "wait for app to idle", which also waits on WKWebView / Core
/// Animation activity that does not block input.
///
/// Not started in production or TestFlight.
final class MainThreadHangDetector: NSObject, ObservableObject {
    static let shared = MainThreadHangDetector()

    static var isEnabled: Bool {
        ProcessInfo.processInfo.arguments.contains("-uiTestHangDetector")
    }

    /// Compact, parseable report, e.g. `maxMs=0 count=0 maxEditingMs=0 countEditing=0 events=`.
    @Published private(set) var report: String = Self.emptyReport

    private static let emptyReport = "maxMs=0 count=0 maxEditingMs=0 countEditing=0 events="
    private static let thresholdMs = 250

    private let lock = NSLock()
    private var lastBeatNs: UInt64 = 0
    private var graceUntilNs: UInt64 = 0
    private var isEditing = false
    private var hasStartedEditing = false
    private var running = false
    private var displayLink: CADisplayLink?
    private var timer: DispatchSourceTimer?
    private var stalled = false
    private var stallStartNs: UInt64 = 0
    private var stallWasEditing = false
    private var events: [(ms: Int, editing: Bool)] = []

    private override init() {
        super.init()
    }

    func start() {
        guard Self.isEnabled, !running else { return }
        running = true
        let now = DispatchTime.now().uptimeNanoseconds
        lastBeatNs = now
        graceUntilNs = now &+ 2_000_000_000

        let link = CADisplayLink(target: self, selector: #selector(displayBeat))
        link.add(to: .main, forMode: .common)
        displayLink = link

        NotificationCenter.default.addObserver(
            self, selector: #selector(editingBegan),
            name: UITextField.textDidBeginEditingNotification, object: nil
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(editingEnded),
            name: UITextField.textDidEndEditingNotification, object: nil
        )

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "big2.hang-detector"))
        timer.schedule(deadline: .now() + 0.05, repeating: 0.05)
        timer.setEventHandler { [weak self] in self?.check() }
        timer.resume()
        self.timer = timer
        NSLog("[HangDetector] started (threshold %dms)", Self.thresholdMs)
    }

    @objc private func displayBeat(_ link: CADisplayLink) {
        lock.lock()
        lastBeatNs = DispatchTime.now().uptimeNanoseconds
        lock.unlock()
    }

    @objc private func editingBegan() {
        lock.lock()
        let first = !hasStartedEditing
        if first {
            hasStartedEditing = true
            events.removeAll()
        }
        isEditing = true
        lock.unlock()
        if first {
            publishReport()
            NSLog("[HangDetector] editing began (recording window)")
        }
    }

    @objc private func editingEnded() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            self.isEditing = false
            self.lock.unlock()
        }
    }

    private func check() {
        let now = DispatchTime.now().uptimeNanoseconds
        lock.lock()
        let last = lastBeatNs
        let grace = graceUntilNs
        let editing = isEditing
        lock.unlock()
        if now < grace { return }
        let ms = Int((now &- last) / 1_000_000)
        if ms >= Self.thresholdMs {
            if !stalled {
                stalled = true
                stallStartNs = last
                stallWasEditing = editing
            } else if editing {
                stallWasEditing = true
            }
        } else if stalled {
            let duration = Int((now &- stallStartNs) / 1_000_000)
            stalled = false
            record(ms: duration, editing: stallWasEditing)
        }
    }

    private func record(ms: Int, editing: Bool) {
        lock.lock()
        events.append((ms, editing))
        lock.unlock()
        NSLog("[HangDetector] main-thread stall %dms (editing=%@)", ms, editing ? "yes" : "no")
        publishReport()
    }

    func flush() {
        if stalled {
            let duration = Int((DispatchTime.now().uptimeNanoseconds &- stallStartNs) / 1_000_000)
            stalled = false
            if duration >= Self.thresholdMs {
                record(ms: duration, editing: stallWasEditing)
                return
            }
        }
        publishReport()
    }

    private func publishReport() {
        lock.lock()
        let snapshot = events
        lock.unlock()
        let all = snapshot.map(\.ms)
        let editing = snapshot.filter(\.editing).map(\.ms)
        let text = String(
            format: "maxMs=%d count=%d maxEditingMs=%d countEditing=%d events=%@",
            all.max() ?? 0, all.count, editing.max() ?? 0, editing.count,
            snapshot.map { "\($0.ms)\($0.editing ? "e" : "")" }.joined(separator: ",")
        )
        DispatchQueue.main.async { self.report = text }
        NSLog("[HangDetector] report %@", text)
    }
}
