import AppKit
import ApplicationServices
import Carbon
import Combine
import FreeJigCore
import IOKit.pwr_mgt
import ServiceManagement

final class PowerAssertion {
    private(set) var id: IOPMAssertionID = 0

    func acquire() -> Bool {
        if id != 0 { return true }
        return IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "FreeJig active session" as CFString, &id
        ) == kIOReturnSuccess
    }

    func release() {
        if id != 0 { IOPMAssertionRelease(id); id = 0 }
    }

    deinit { release() }
}

@MainActor
final class Controller: ObservableObject {
    enum State: Equatable {
        case stopped, scheduled, appCondition, idle, locked, permission, active, failure(String)

        var title: String {
            switch self {
            case .stopped: return "Stopped"
            case .scheduled: return "Waiting for schedule"
            case .appCondition: return "Waiting for selected apps"
            case .idle: return "Waiting for you to be idle"
            case .locked: return "Paused while locked or asleep"
            case .permission: return "Accessibility permission needed"
            case .active: return "Keeping your Mac awake"
            case .failure(let message): return message
            }
        }
    }

    @Published var settings: Settings {
        didSet {
            let clean = settings.validated()
            if clean != settings { settings = clean }
            do { defaults.set(try JSONEncoder().encode(settings), forKey: "settings") }
            catch { notice = "Could not save settings. \(error.localizedDescription)" }
            if oldValue.autoStop != settings.autoStop, let startedAt {
                deadline = settings.autoStop.deadline(startedAt: startedAt, calendar: .current)
            }
            cancelMovement()
            lastPulse = nil
            tick()
        }
    }
    @Published private(set) var enabled = false
    @Published private(set) var state: State = .stopped
    @Published private(set) var deadline: Date?
    @Published private(set) var hasAccessibility = AXIsProcessTrusted()
    @Published var notice: String?
    @Published private(set) var launchAtLogin = false
    let power = PowerAssertion()
    private let defaults: UserDefaults
    private var timer: Timer?
    private var movementTimer: Timer?
    private var source = CGEventSource(stateID: .privateState)
    private var lastPulse: Date?
    private var startedAt: Date?
    private var locked = false
    private var sleeping = false
    private var alternatingDown = false
    private var observers: [NSObjectProtocol] = []

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: "settings") {
            do { settings = try JSONDecoder().decode(Settings.self, from: data).validated() }
            catch {
                settings = Settings()
                notice = "Saved settings could not be read. Safe defaults are in use."
            }
        } else { settings = Settings() }
        source?.localEventsSuppressionInterval = 0
        launchAtLogin = SMAppService.mainApp.status == .enabled
        let workspace = NSWorkspace.shared.notificationCenter
        observers.append(workspace.addObserver(forName: NSWorkspace.willSleepNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleeping = true; self?.tick() }
        })
        observers.append(workspace.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.sleeping = false; self?.lastPulse = Date(); self?.tick() }
        })
        let distributed = DistributedNotificationCenter.default()
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsLocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.locked = true; self?.tick() }
        })
        observers.append(distributed.addObserver(forName: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.locked = false; self?.lastPulse = Date(); self?.tick() }
        })
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
    }

    func toggle() { enabled ? stop() : start() }

    func start() {
        startedAt = Date()
        deadline = settings.autoStop.deadline(startedAt: startedAt!, calendar: .current)
        lastPulse = nil
        enabled = true
        tick()
    }

    func stop() {
        enabled = false
        startedAt = nil
        deadline = nil
        lastPulse = nil
        transition(.stopped)
    }

    func requestAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func setLaunchAtLogin(_ value: Bool) {
        do {
            if value { try SMAppService.mainApp.register() }
            else { try SMAppService.mainApp.unregister() }
        } catch { notice = "Could not change launch at login. \(error.localizedDescription)" }
        launchAtLogin = SMAppService.mainApp.status == .enabled
        if SMAppService.mainApp.status == .requiresApproval {
            notice = "Allow FreeJig in System Settings > General > Login Items."
            SMAppService.openSystemSettingsLoginItems()
        }
    }

    private var needsInputPermission: Bool {
        settings.mode != .silent || settings.click != .none || settings.scroll != .none || settings.pressShift
    }

    private var physicalIdle: TimeInterval {
        CGEventSource.secondsSinceLastEventType(.hidSystemState, eventType: CGEventType(rawValue: UInt32.max)!)
    }

    private var inputBusy: Bool {
        CGEventSource.buttonState(.combinedSessionState, button: .left) ||
        CGEventSource.buttonState(.combinedSessionState, button: .right) ||
        CGEventSource.buttonState(.combinedSessionState, button: .center) ||
        !CGEventSource.flagsState(.combinedSessionState).intersection([.maskShift, .maskControl, .maskAlternate, .maskCommand]).isEmpty
    }

    private var sessionLocked: Bool {
        let info = CGSessionCopyCurrentDictionary() as? [String: Any]
        return locked || (info?["CGSSessionScreenIsLocked"] as? Bool == true) ||
            (info?[kCGSessionOnConsoleKey as String] as? Bool == false)
    }

    func tick() {
        hasAccessibility = AXIsProcessTrusted()
        guard enabled else { transition(.stopped); return }
        let now = Date()
        if let deadline, now >= deadline { stop(); return }
        guard !sleeping, !sessionLocked else { transition(.locked); return }
        guard settings.schedule.contains(now, calendar: .current) else { transition(.scheduled); return }
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        guard settings.appRule.allows(running: running, frontmost: NSWorkspace.shared.frontmostApplication?.bundleIdentifier) else {
            transition(.appCondition); return
        }
        guard !needsInputPermission || hasAccessibility else { transition(.permission); return }
        guard physicalIdle >= settings.startAfter, !inputBusy else {
            lastPulse = nil
            transition(.idle); return
        }
        guard power.acquire() else { transition(.failure("macOS could not prevent idle sleep")); return }
        state = .active
        guard lastPulse == nil || now.timeIntervalSince(lastPulse!) >= settings.interval else { return }
        lastPulse = now
        pulse()
    }

    private func transition(_ next: State) {
        state = next
        if next != .active { power.release(); cancelMovement() }
    }

    private func cancelMovement() {
        movementTimer?.invalidate()
        movementTimer = nil
    }

    private func post(_ event: CGEvent?) -> Bool {
        guard let event else {
            transition(.failure("macOS could not create an input event"))
            return false
        }
        event.setIntegerValueField(.eventSourceUserData, value: 0x46524A47)
        event.post(tap: .cghidEventTap)
        return true
    }

    private func pulse() {
        if settings.mode != .silent {
            guard let current = CGEvent(source: nil)?.location else {
                transition(.failure("macOS could not read the pointer position")); return
            }
            let displays = NSScreen.screens.compactMap { screen -> CGRect? in
                guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return nil }
                return CGDisplayBounds(CGDirectDisplayID(number.uint32Value))
            }
            guard let bounds = displays.first(where: { $0.contains(current) }) else { return }
            let target: CGPoint
            if settings.mode == .subtle {
                target = CGPoint(x: min(max(current.x + (current.x < bounds.midX ? 1 : -1), bounds.minX + 1), bounds.maxX - 2), y: current.y)
            } else {
                let radius: Double
                switch settings.range {
                case .small: radius = 12
                case .medium: radius = 100
                case .full: radius = max(bounds.width, bounds.height)
                }
                target = CGPoint(
                    x: min(max(current.x + Double.random(in: -radius...radius), bounds.minX + 2), bounds.maxX - 2),
                    y: min(max(current.y + Double.random(in: -radius...radius), bounds.minY + 2), bounds.maxY - 2)
                )
            }
            animate(from: current, to: target, returnToOrigin: settings.mode == .subtle)
        } else { optionalActions() }
    }

    private func animate(from origin: CGPoint, to target: CGPoint, returnToOrigin: Bool) {
        cancelMovement()
        var frame = 0
        let frames = returnToOrigin ? 2 : 20
        var previous = origin
        movementTimer = Timer.scheduledTimer(withTimeInterval: 0.02, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self, self.enabled, self.state == .active, self.hasAccessibility,
                      !self.sessionLocked, !self.sleeping,
                      self.physicalIdle >= self.settings.startAfter, !self.inputBusy,
                      let actual = CGEvent(source: nil)?.location,
                      hypot(actual.x - previous.x, actual.y - previous.y) < 3 else {
                    timer.invalidate(); return
                }
                frame += 1
                let progress = Double(frame) / Double(frames)
                let eased = progress * progress * (3 - 2 * progress)
                let point = returnToOrigin ? (frame == 1 ? target : origin) : CGPoint(
                    x: origin.x + (target.x - origin.x) * eased,
                    y: origin.y + (target.y - origin.y) * eased
                )
                guard self.post(CGEvent(mouseEventSource: self.source, mouseType: .mouseMoved, mouseCursorPosition: point, mouseButton: .left)) else {
                    timer.invalidate(); return
                }
                previous = point
                if frame >= frames { timer.invalidate(); self.movementTimer = nil; self.optionalActions() }
            }
        }
    }

    private func optionalActions() {
        guard enabled, state == .active, !sessionLocked, !sleeping,
              physicalIdle >= settings.startAfter, !inputBusy,
              !needsInputPermission || AXIsProcessTrusted() else { return }
        if settings.click != .none, let point = CGEvent(source: nil)?.location {
            let right = settings.click == .right
            let count = settings.click == .double ? 2 : 1
            for index in 1...count {
                let down = CGEvent(mouseEventSource: source, mouseType: right ? .rightMouseDown : .leftMouseDown, mouseCursorPosition: point, mouseButton: right ? .right : .left)
                let up = CGEvent(mouseEventSource: source, mouseType: right ? .rightMouseUp : .leftMouseUp, mouseCursorPosition: point, mouseButton: right ? .right : .left)
                guard let down, let up else { transition(.failure("Could not create a click")); return }
                down.setIntegerValueField(.mouseEventClickState, value: Int64(index))
                up.setIntegerValueField(.mouseEventClickState, value: Int64(index))
                _ = post(down); _ = post(up)
            }
        }
        if settings.scroll != .none {
            let down = settings.scroll == .down || (settings.scroll == .alternating && alternatingDown)
            _ = post(CGEvent(scrollWheelEvent2Source: source, units: .line, wheelCount: 1, wheel1: down ? -1 : 1, wheel2: 0, wheel3: 0))
            alternatingDown.toggle()
        }
        if settings.pressShift {
            guard let down = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: true),
                  let up = CGEvent(keyboardEventSource: source, virtualKey: 56, keyDown: false) else {
                transition(.failure("Could not create a Shift pulse")); return
            }
            down.type = .flagsChanged
            down.flags = .maskShift
            up.type = .flagsChanged
            up.flags = []
            _ = post(down); _ = post(up)
        }
    }
}
