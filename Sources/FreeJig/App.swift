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
    let controller = Controller()
    private var item: NSStatusItem!
    private let popover = NSPopover()
    private var window: NSWindow?
    private var hotKey: EventHotKeyRef?
    private var hotKeyHandler: EventHandlerRef?
    private var subscription: AnyCancellable?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        item.button?.target = self
        item.button?.action = #selector(showPopover)
        item.button?.setAccessibilityLabel("FreeJig")
        popover.behavior = .transient
        subscription = controller.$state.sink { [weak self] state in
            let symbol = state == .active ? "cursorarrow.motionlines" : "computermouse"
            self?.item.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "FreeJig. \(state.title)")
            self?.item.button?.toolTip = "FreeJig. \(state.title)"
        }
        installShortcut()
        if CommandLine.arguments.contains("--show-window") {
            showWindow()
        } else {
            DispatchQueue.main.async { self.showPopover() }
        }
    }

    private func showWindow() {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main!
        let view = makeContentController(on: screen)
        let window = self.window ?? NSWindow(contentRect: .zero,
                                            styleMask: [.titled, .closable, .miniaturizable],
                                            backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentViewController = view
        window.setContentSize(view.preferredContentSize)
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

    @objc private func showPopover() {
        guard let button = item.button, let anchor = button.window,
              anchor.isVisible, anchor.frame.height > 0, let screen = anchor.screen else {
            showWindow()
            return
        }
        if popover.isShown { popover.performClose(nil) }
        else {
            popover.contentViewController = makeContentController(on: screen)
            popover.contentSize = popover.contentViewController!.preferredContentSize
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
            DispatchQueue.main.async {
                if let window = self.popover.contentViewController?.view.window {
                    self.verifyPlacement(of: window, inside: screen.frame)
                } else if CommandLine.arguments.contains("--verify-placement") {
                    fputs("FAIL: menu-bar popover has no visible window\n", stderr); exit(1)
                }
            }
        }
    }

    private func verifyPlacement(of window: NSWindow, inside bounds: CGRect, centered: Bool = false) {
        guard CommandLine.arguments.contains("--verify-placement") else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            guard bounds.contains(window.frame) else {
                fputs("FAIL: visible window \(NSStringFromRect(window.frame)) exceeds display \(NSStringFromRect(bounds))\n", stderr)
                exit(1)
            }
            if centered && (abs(window.frame.midX - bounds.midX) > 1 || abs(window.frame.midY - bounds.midY) > 1) {
                fputs("FAIL: visible window is not centered\n", stderr); exit(1)
            }
            print("PASS: visible window \(NSStringFromRect(window.frame)) fits display \(NSStringFromRect(bounds))")
            fflush(stdout)
        }
    }

    private func makeContentController(on screen: NSScreen) -> NSViewController {
        let content = ContentView(controller: controller)
        let idealSize = NSHostingController(rootView: content).view.fittingSize
        let width = min(idealSize.width, screen.visibleFrame.width - 32)
        let height = min(idealSize.height, screen.visibleFrame.height - 64)
        let host = NSHostingController(rootView:
            ScrollView([.horizontal, .vertical]) { content }
                .frame(width: width, height: height)
        )
        host.sizingOptions = []
        host.preferredContentSize = CGSize(width: width, height: height)
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

@main
struct FreeJigApp {
    @MainActor static func main() {
        if CommandLine.arguments.contains("--self-check") {
            selfCheck()
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        withExtendedLifetime(delegate) { application.run() }
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
        print("PASS: window placement fits display bounds. macOS power assertion acquired, observed, and released. Input actions are off by default.")
    }
}
