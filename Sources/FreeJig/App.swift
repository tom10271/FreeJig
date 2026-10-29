import AppKit
import Carbon
import Combine
import FreeJigCore
import IOKit.pwr_mgt
import SwiftUI

func centeredFrame(size: CGSize, inside visibleFrame: CGRect) -> CGRect {
    let width = min(size.width, visibleFrame.width)
    let height = min(size.height, visibleFrame.height)
    return CGRect(x: visibleFrame.midX - width / 2, y: visibleFrame.midY - height / 2,
                  width: width, height: height)
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    // Keep the preferences domain stable across the bundle-identifier repair.
    let controller = Controller(defaults: UserDefaults(suiteName: "dev.tomlo.FreeJig")!)
    private var window: NSWindow?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        installShortcut()
        showWindow()
    }

    private func showWindow() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let view = makeContentController(on: screen)
        let contentSize = view.preferredContentSize
        let window = self.window ?? NSWindow(contentRect: .zero,
                                            styleMask: [.titled, .closable, .miniaturizable],
                                            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = view
        window.setContentSize(contentSize)
        window.title = "FreeJig"
        window.setFrame(centeredFrame(size: window.frame.size, inside: screen.visibleFrame.insetBy(dx: 16, dy: 16)), display: false)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        verifyPlacement(of: window, inside: screen.visibleFrame, centered: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag { showWindow() }
        return true
    }

    private func verifyPlacement(of window: NSWindow, inside bounds: CGRect, centered: Bool = false) {
        guard CommandLine.arguments.contains("--verify-placement") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            guard bounds.contains(window.frame) else {
                fputs("FAIL: visible window \(NSStringFromRect(window.frame)) exceeds display \(NSStringFromRect(bounds))\n", stderr)
                exit(1)
            }
            if centered && (abs(window.frame.midX - bounds.midX) > 1 || abs(window.frame.midY - bounds.midY) > 1) {
                fputs("FAIL: visible window is not centered\n", stderr); exit(1)
            }
            print("PASS: visible window \(NSStringFromRect(window.frame)) fits display \(NSStringFromRect(bounds))")
            fflush(stdout)
            NSApp.terminate(nil)
        }
    }

    private func makeContentController(on screen: NSScreen) -> NSViewController {
        let host = NSHostingController(rootView:
            SettingsContent(controller: controller, availableSize: screen.visibleFrame.size)
        )
        let contentSize = host.view.fittingSize
        host.sizingOptions = []
        host.preferredContentSize = contentSize
        return host
    }

    private func installShortcut() {
        var type = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        let handlerResult = InstallEventHandler(GetApplicationEventTarget(), { _, _, context in
            guard let context else { return OSStatus(eventNotHandledErr) }
            let delegate = Unmanaged<AppDelegate>.fromOpaque(context).takeUnretainedValue()
            MainActor.assumeIsolated { delegate.controller.toggle() }
            return noErr
        }, 1, &type, Unmanaged.passUnretained(self).toOpaque(), &hotKeyHandler)
        let id = EventHotKeyID(signature: OSType(0x46524A47), id: 1)
        let keyResult = RegisterEventHotKey(UInt32(kVK_ANSI_J), UInt32(controlKey | cmdKey), id, GetApplicationEventTarget(), 0, &hotKey)
        if handlerResult != noErr || keyResult != noErr {
            controller.notice = "Control-Command-J is unavailable. Another app may be using it. The Start button still works."
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        controller.stop()
        if let hotKey { UnregisterEventHotKey(hotKey) }
        if let hotKeyHandler { RemoveEventHandler(hotKeyHandler) }
    }
}

private struct SettingsContent: View {
    @ObservedObject var controller: Controller
    let availableSize: CGSize

    var body: some View {
        let preferredWidth = 740 + NSScroller.scrollerWidth(for: .regular, scrollerStyle: .legacy)
        let width = min(preferredWidth, availableSize.width - 32)
        ViewThatFits {
            ContentView(controller: controller)
            ScrollView(width < preferredWidth ? [.horizontal, .vertical] : .vertical) {
                ContentView(controller: controller)
            }
        }
        .frame(width: width)
        .frame(maxHeight: availableSize.height - 64)
        .fixedSize(horizontal: false, vertical: true)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private struct MenuStatusIcon: View {
    @ObservedObject var controller: Controller

    var body: some View {
        Image(systemName: controller.state == .active ? "cursorarrow.motionlines" : "computermouse")
            .accessibilityLabel("FreeJig. \(controller.state.title)")
            .help("FreeJig. \(controller.state.title)")
    }
}

private struct FreeJigScenes: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        MenuBarExtra(isInserted: .constant(!CommandLine.arguments.contains("--verify-placement"))) {
            let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
            SettingsContent(controller: delegate.controller, availableSize: screen.visibleFrame.size)
        } label: {
            MenuStatusIcon(controller: delegate.controller)
        }
        .menuBarExtraStyle(.window)
    }
}

@main
struct FreeJigApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-check") {
            selfCheck()
            return
        }
        if let identifier = Bundle.main.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
            .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }) {
            if CommandLine.arguments.contains("--verify-placement") {
                fputs("FAIL: quit the running FreeJig before checking window placement\n", stderr)
                exit(1)
            }
            _ = running.activate(options: [.activateAllWindows, .activateIgnoringOtherApps])
            return
        }
        FreeJigScenes.main()
    }

    @MainActor private static func selfCheck() {
        let suiteName = "dev.tomlo.FreeJig.checks.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let controller = Controller(defaults: defaults)
        controller.settings.mode = .silent
        controller.settings.startAfter = 3600
        var updates = 0
        let observation = controller.objectWillChange.sink { updates += 1 }
        for _ in 0..<5 { controller.tick() }
        guard updates == 0 else {
            fputs("FAIL: unchanged stopped state published \(updates) UI updates\n", stderr); exit(1)
        }
        controller.start()
        updates = 0
        for _ in 0..<5 { controller.tick() }
        guard updates == 0 else {
            fputs("FAIL: unchanged enabled state published \(updates) UI updates\n", stderr); exit(1)
        }
        controller.stop()
        observation.cancel()
        _ = NSApplication.shared
        controller.settings.mode = .natural
        controller.settings.autoStop.mode = .after
        let naturalSize = NSHostingController(rootView: ContentView(controller: controller)).view.fittingSize
        func hasScrollView(_ view: NSView) -> Bool {
            if view is NSScrollView, !view.isHiddenOrHasHiddenAncestor,
               view.frame.width > 0, view.frame.height > 0 { return true }
            return view.subviews.contains(where: hasScrollView)
        }
        for displaySize in [CGSize(width: 1512, height: 949), CGSize(width: 1512, height: 480), CGSize(width: 640, height: 480)] {
            let host = NSHostingController(rootView: SettingsContent(controller: controller, availableSize: displaySize))
            let fitted = host.view.fittingSize
            guard fitted.width <= displaySize.width - 32, fitted.height <= displaySize.height - 64,
                  fitted.height >= min(naturalSize.height, displaySize.height - 64) - 1 else {
                fputs("FAIL: settings fit \(fitted) hides natural content \(naturalSize) on display \(displaySize)\n", stderr)
                exit(1)
            }
            print("PASS: settings fit \(fitted) preserves natural content \(naturalSize) on display \(displaySize)")
            let minimum = host.sizeThatFits(in: CGSize(width: fitted.width, height: 0))
            guard minimum.height >= min(naturalSize.height, displaySize.height - 64) - 1 else {
                fputs("FAIL: menu popup collapses to \(minimum) for natural content \(naturalSize)\n", stderr)
                exit(1)
            }
            let window = NSWindow(contentRect: CGRect(origin: .zero, size: fitted), styleMask: [], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.contentViewController = host
            window.setContentSize(fitted)
            host.view.layoutSubtreeIfNeeded()
            let needsScrolling = naturalSize.width > fitted.width || naturalSize.height > fitted.height
            guard hasScrollView(host.view) == needsScrolling else {
                fputs("FAIL: scroll fallback does not match content overflow on \(displaySize)\n", stderr)
                exit(1)
            }
            print("PASS: menu minimum \(minimum), scrolling=\(needsScrolling)")
            window.close()
        }
        for screen in [CGRect(x: 0, y: 0, width: 1512, height: 945),
                       CGRect(x: -1920, y: 200, width: 1920, height: 1055),
                       CGRect(x: 0, y: -900, width: 640, height: 480)] {
            for size in [CGSize(width: 740, height: 750), CGSize(width: 2000, height: 1400)] {
                guard screen.contains(centeredFrame(size: size, inside: screen)) else {
                    fputs("FAIL: window extends beyond the display\n", stderr); exit(1)
                }
            }
        }
        let assertion = PowerAssertion()
        guard assertion.acquire(), assertion.id != 0 else {
            fputs("FAIL: macOS rejected the idle-display-sleep assertion\n", stderr)
            exit(1)
        }
        var assertions: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&assertions) == kIOReturnSuccess,
              let table = assertions?.takeRetainedValue() as? [NSNumber: [[String: Any]]],
              let ours = table[NSNumber(value: ProcessInfo.processInfo.processIdentifier)],
              ours.contains(where: { ($0[kIOPMAssertionNameKey] as? String) == "FreeJig active session" }) else {
            fputs("FAIL: power assertion is not visible in macOS\n", stderr)
            exit(1)
        }
        assertion.release()
        guard assertion.id == 0 else { exit(1) }
        var released: Unmanaged<CFDictionary>?
        guard IOPMCopyAssertionsByProcess(&released) == kIOReturnSuccess else { exit(1) }
        let remaining = released?.takeRetainedValue() as? [NSNumber: [[String: Any]]]
        guard !(remaining?[NSNumber(value: ProcessInfo.processInfo.processIdentifier)] ?? [])
            .contains(where: { ($0[kIOPMAssertionNameKey] as? String) == "FreeJig active session" }) else {
            fputs("FAIL: power assertion remained after release\n", stderr); exit(1)
        }
        let settings = Settings()
        guard settings.click == .none, settings.scroll == .none, !settings.pressShift else { exit(1) }
        print("PASS: unchanged controller states produce no UI updates. Window placement fits display bounds. macOS power assertion acquired, observed, and released.")
    }
}
