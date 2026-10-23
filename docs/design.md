# FreeJig design

FreeJig is a native macOS menu bar utility. The user enables a session, chooses when it is eligible to run, and chooses the events it may generate. Settings persist locally. Starting the app never starts a session.

## Design decision

An all-in-one SwiftUI view would keep file count low but mix scheduling, permission checks, and synthetic input with rendering. A small Foundation policy module plus a main-actor macOS controller keeps calendar behavior testable without moving the user's mouse. We choose the latter. The UI binds to one controller's settings. The controller is the only owner of the timer and power assertion.

No existing code or index exists in this new project. Exploration is sequential under the user's AGENTS.md. Native Apple APIs supply all platform integration. No third-party package is needed.

## Responsibilities

- FreeJigCore owns persisted settings, schedule eligibility, app conditions, and stop deadlines.
- Controller owns Accessibility checks, session state, timer, lock and sleep suspension, input events, persistence, and power assertions.
- Views own native controls and app selection. They never calculate schedule eligibility or post events.
- AppDelegate owns the status item, popover, and global Control-Command-J shortcut.
- The build script produces an ad-hoc-signed application bundle. Distribution with a Developer ID is a separate release process.

## Behavior contract

`Settings` is Codable and Equatable with a default initializer. Properties are `mode: MovementMode`, `range: MovementRange`, `startAfter: Double`, `interval: Double`, `schedule: WeeklySchedule`, `autoStop: AutoStop`, `appRule: AppRule`, `click: ClickMode`, `scroll: ScrollMode`, `pressShift: Bool`.

Enums have String raw values, Codable, CaseIterable, Identifiable, and `title: String`. Cases are MovementMode natural/subtle/silent, MovementRange small/medium/full, StopMode never/after/at, AppCondition any/running/frontmost/notFrontmost, ClickMode none/left/right/double, ScrollMode none/up/down/alternating.

`WeeklySchedule` has enabled Bool, startMinute Int, endMinute Int, weekdays Set<Int>. `contains(_ date: Date, calendar: Calendar) -> Bool` uses local calendar weekdays 1 through 7. Overnight windows belong to the starting weekday. Equal start and end means the selected full calendar day. Start is inclusive, end exclusive. An empty weekday selection matches nothing.

`AutoStop` has mode StopMode, afterMinutes Double, atMinute Int. `deadline(startedAt: Date, calendar: Calendar) -> Date?` uses next wall-clock occurrence for at, an absolute duration for after, and nil for never.

`AppRule` has condition AppCondition and bundleIDs [String]. `allows(running: Set<String>, frontmost: String?) -> Bool` matches any selected app for running/frontmost and excludes all selected apps for notFrontmost. Any ignores the list. An empty constrained list matches nothing.

Core owns `Settings.validated() -> Settings` for finite bounded numeric values and enum-safe decoding. Bad persisted data falls back to defaults, with a visible error. Defaults are natural, small, 60-second idle delay and interval, no schedule, no auto-stop, any app, and no click, scroll, or Shift.

The controller checks session stop deadline, lock/sleep state, schedule, app condition, Accessibility permission, physical input idle time, and event interval in that order. Waiting or blocked states release the display-sleep assertion. Silent mode uses only a display-sleep assertion and requires no Accessibility grant unless optional event actions are enabled. System sleep, screen locking, and explicit user sleep remain authoritative. Clicking and key pulses require explicit opt-in. The controller never moves the pointer while a mouse button is down.

## Verification

Core tests cover schedule boundaries, overnight weekday ownership, equal times, empty day sets, app conditions, stop deadlines, and persisted numeric validation. Runtime checks cover the built app, menu bar popover, safe defaults, power assertion lifecycle, and missing permission state. Input behavior requiring an Accessibility grant is reported separately if unavailable.
