import AppKit
import FreeJigCore
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @ObservedObject var controller: Controller
    private let accent = Color(red: 0.20, green: 0.73, blue: 0.48)

    var body: some View {
        VStack(spacing: 18) {
            header
            if let notice = controller.notice {
                HStack(alignment: .top) {
                    Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                    Text(notice).font(.callout)
                    Spacer()
                    Button { controller.notice = nil } label: { Image(systemName: "xmark") }
                        .buttonStyle(.plain).accessibilityLabel("Dismiss notice")
                }.padding(12).background(.orange.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
            }
            HStack(alignment: .top, spacing: 14) {
                VStack(spacing: 14) {
                    movementCard
                    actionCard
                }
                VStack(spacing: 14) {
                    scheduleCard
                    stopCard
                    appCard
                }
            }
            footer
        }
        .padding(22)
        .frame(width: 740)
        .background(Color(nsColor: .windowBackgroundColor))
        .tint(accent)
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 14).fill(accent.gradient).frame(width: 52, height: 52)
                Image(systemName: "cursorarrow.motionlines").font(.system(size: 26, weight: .medium)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("FreeJig").font(.system(size: 25, weight: .bold, design: .rounded))
                    Text("FREE & OPEN SOURCE").font(.system(size: 9, weight: .bold)).tracking(0.7)
                        .foregroundStyle(.secondary).padding(.horizontal, 6).padding(.vertical, 4)
                        .background(.quaternary, in: Capsule())
                }
                HStack(spacing: 6) {
                    Circle().fill(statusColor).frame(width: 7, height: 7)
                    Text(controller.state.title).font(.system(size: 12)).foregroundStyle(.secondary)
                }.accessibilityElement(children: .combine)
            }
            Spacer(minLength: 6)
            Button(controller.enabled ? "Stop" : "Start", systemImage: controller.enabled ? "stop.fill" : "play.fill") {
                controller.toggle()
            }
            .buttonStyle(.borderedProminent).controlSize(.large)
            .keyboardShortcut("j", modifiers: [.control, .command])
            .help("Start or stop. Control-Command-J works globally.")
            .accessibilityIdentifier("sessionToggle")
        }
    }

    private var statusColor: Color {
        if controller.state == .active { return accent }
        return controller.enabled ? .orange : .secondary
    }

    private var movementCard: some View {
        card("Movement", icon: "cursorarrow.motionlines") {
            Picker("Mode", selection: $controller.settings.mode) {
                ForEach(MovementMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            Text(modeDescription).font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            Divider()
            secondsRow("Start after idle", value: $controller.settings.startAfter)
            secondsRow("Repeat every", value: $controller.settings.interval)
            Picker("Movement range", selection: $controller.settings.range) {
                ForEach(MovementRange.allCases) { Text($0.title).tag($0) }
            }.disabled(controller.settings.mode != .natural)
            if !controller.hasAccessibility && needsPermission {
                Divider()
                Label("Allow Accessibility to send input events.", systemImage: "hand.raised")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Open Accessibility settings") { controller.requestAccessibility() }
                    .buttonStyle(.bordered).frame(maxWidth: .infinity, alignment: .leading)
                Text("Already enabled? Remove the old FreeJig entry, add this copy again, then reopen FreeJig. Replacing an ad-hoc signed build can invalidate its grant.")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Button("Reveal this copy in Finder") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }.buttonStyle(.borderless)
            }
        }
    }

    private var modeDescription: String {
        switch controller.settings.mode {
        case .natural: return "A smooth move within the selected range. Pauses when you use your Mac."
        case .subtle: return "Moves one pixel and back. Your pointer stays where you left it."
        case .silent: return "Keeps the display awake without moving the pointer. No permission needed unless you add input actions."
        }
    }

    private var needsPermission: Bool {
        controller.settings.mode != .silent || controller.settings.click != .none ||
        controller.settings.scroll != .none || controller.settings.pressShift
    }

    private var actionCard: some View {
        card("Extra actions", icon: "hand.tap") {
            Picker("Click at pointer", selection: $controller.settings.click) {
                ForEach(ClickMode.allCases) { Text($0.title).tag($0) }
            }
            Picker("Scroll", selection: $controller.settings.scroll) {
                ForEach(ScrollMode.allCases) { Text($0.title).tag($0) }
            }
            Toggle("Press and release Shift", isOn: $controller.settings.pressShift).toggleStyle(.switch)
            Text("Actions repeat with each movement interval and affect the app under your pointer or in front.")
                .font(.system(size: 11)).foregroundStyle(.secondary).fixedSize(horizontal: false, vertical: true)
            if controller.settings.click != .none {
                Label("Clicks can activate buttons or links. Place your pointer carefully.", systemImage: "exclamationmark.triangle")
                    .font(.system(size: 11)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var scheduleCard: some View {
        card("Schedule", icon: "calendar") {
            Toggle("Only during these hours", isOn: $controller.settings.schedule.enabled).toggleStyle(.switch)
            VStack(spacing: 10) {
                HStack {
                    DatePicker("From", selection: minuteBinding($controller.settings.schedule.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("To", selection: minuteBinding($controller.settings.schedule.endMinute), displayedComponents: .hourAndMinute)
                }
                HStack(spacing: 4) {
                    ForEach([2, 3, 4, 5, 6, 7, 1], id: \.self) { day in
                        let selected = controller.settings.schedule.weekdays.contains(day)
                        Button {
                            if selected { controller.settings.schedule.weekdays.remove(day) }
                            else { controller.settings.schedule.weekdays.insert(day) }
                        } label: {
                            Text(Calendar.current.veryShortWeekdaySymbols[day - 1])
                                .font(.system(size: 11, weight: .semibold))
                                .frame(maxWidth: .infinity).padding(.vertical, 7)
                                .background(selected ? accent.opacity(0.18) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                                .foregroundStyle(selected ? accent : .secondary)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(Calendar.current.weekdaySymbols[day - 1])
                        .accessibilityValue(selected ? "Selected" : "Not selected")
                    }
                }
                if controller.settings.schedule.weekdays.isEmpty {
                    Text("Choose at least one day.").font(.caption).foregroundStyle(.orange)
                }
                if controller.settings.schedule.startMinute > controller.settings.schedule.endMinute {
                    Text("Ends the following day.").font(.caption).foregroundStyle(.secondary)
                }
            }.disabled(!controller.settings.schedule.enabled)
        }
    }

    private var stopCard: some View {
        card("Automatic stop", icon: "timer") {
            Picker("Stop", selection: $controller.settings.autoStop.mode) {
                ForEach(StopMode.allCases) { Text($0.title).tag($0) }
            }.pickerStyle(.segmented).labelsHidden()
            if controller.settings.autoStop.mode == .after {
                HStack {
                    Text("After")
                    Spacer()
                    TextField("Minutes", value: $controller.settings.autoStop.afterMinutes, format: .number.precision(.fractionLength(0)))
                        .frame(width: 60).textFieldStyle(.roundedBorder)
                    Text("minutes").foregroundStyle(.secondary)
                }
            } else if controller.settings.autoStop.mode == .at {
                DatePicker("At", selection: minuteBinding($controller.settings.autoStop.atMinute), displayedComponents: .hourAndMinute)
            }
            if let deadline = controller.deadline {
                Text("Stops \(deadline.formatted(date: .abbreviated, time: .shortened))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private var appCard: some View {
        card("App condition", icon: "app.badge") {
            Picker("Only while", selection: $controller.settings.appRule.condition) {
                ForEach(AppCondition.allCases) { Text($0.title).tag($0) }
            }.labelsHidden()
            if controller.settings.appRule.condition != .any {
                ForEach(controller.settings.appRule.bundleIDs, id: \.self) { id in
                    HStack {
                        Text(appName(id)).lineLimit(1).help(id)
                        Spacer()
                        Button {
                            controller.settings.appRule.bundleIDs.removeAll { $0 == id }
                        } label: { Image(systemName: "minus.circle") }
                            .buttonStyle(.plain).foregroundStyle(.secondary)
                            .accessibilityLabel("Remove \(appName(id))")
                    }
                }
                Button("Choose app…", systemImage: "plus") { chooseApp() }.buttonStyle(.bordered)
                if controller.settings.appRule.bundleIDs.isEmpty {
                    Text("Choose an app to allow this session to run.").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 12) {
            Divider()
            HStack {
                Toggle("Launch at login", isOn: Binding(get: { controller.launchAtLogin }, set: { controller.setLaunchAtLogin($0) }))
                    .toggleStyle(.switch).controlSize(.small)
                Spacer()
                Text("⌃⌘J to start or stop").font(.system(size: 11)).foregroundStyle(.secondary)
                Button("Quit") { controller.stop(); NSApp.terminate(nil) }.buttonStyle(.borderless)
            }
        }
    }

    private func card<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(title, systemImage: icon).font(.system(size: 13, weight: .semibold))
            content().font(.system(size: 12))
        }
        .padding(15).frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Color.primary.opacity(0.06)))
    }

    private func secondsRow(_ label: String, value: Binding<Double>) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField(label, value: value, format: .number.precision(.fractionLength(0)))
                .textFieldStyle(.roundedBorder).frame(width: 54)
            Text("sec").foregroundStyle(.secondary)
            Stepper(label, value: value, in: 1...3600, step: 5).labelsHidden()
        }
    }

    private func minuteBinding(_ minute: Binding<Int>) -> Binding<Date> {
        Binding(get: {
            Calendar.current.date(from: DateComponents(year: 2001, month: 1, day: 15,
                                                      hour: minute.wrappedValue / 60,
                                                      minute: minute.wrappedValue % 60)) ?? Date()
        }, set: { date in
            let components = Calendar.current.dateComponents([.hour, .minute], from: date)
            minute.wrappedValue = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        })
    }

    private func appName(_ id: String) -> String {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: id)
            .map { FileManager.default.displayName(atPath: $0.path) } ?? id
    }

    private func chooseApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.allowedContentTypes = [.application]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowsMultipleSelection = true
        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            guard let id = Bundle(url: url)?.bundleIdentifier else {
                controller.notice = "\(url.lastPathComponent) has no application identifier."
                continue
            }
            if !controller.settings.appRule.bundleIDs.contains(id) {
                controller.settings.appRule.bundleIDs.append(id)
            }
        }
    }
}
