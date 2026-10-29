# FreeJig

A free, open-source mouse jiggler for macOS. All controls are included under the MIT license.

FreeJig provides Dock and menu bar access. Start it when you want your Mac to stay awake, then let it wait until you stop using the keyboard and mouse. Control-Command-J starts or stops the session from any app.

## Build and run

Requires macOS 13 or later and Apple's Swift Command Line Tools. There are no third-party dependencies.

```sh
xcode-select --install
git clone https://github.com/tom10271/FreeJig.git
cd FreeJig
bash scripts/build-app.sh
open dist/FreeJig.app
```

The script creates an app bundle and a ZIP for the Mac architecture used to build it. Move the app to Applications before granting Accessibility permission or enabling launch at login. Rebuilding an ad-hoc-signed app can require removing and adding its Accessibility entry again.

If FreeJig is enabled in Accessibility but still reports that permission is needed, quit FreeJig, remove its old entry, and add the current app again. macOS checks the build's signing requirement as well as the app name. An old enabled entry can therefore reject a replacement build. The app's **Reveal this copy in Finder** button identifies the exact copy to add.

The first release is ad-hoc signed, without Apple notarization. On a downloaded build, macOS may require **System Settings > Privacy & Security > Open Anyway** after you try opening it. You can also build from source using the commands above. Build on an Intel Mac to produce an Intel binary.

Opening FreeJig from the Dock shows a centered settings window. Clicking its menu bar icon opens a native popup that closes when you click outside it.

On macOS 26, also enable FreeJig in **System Settings > Menu Bar**. Version 0.1.4 uses the macOS bundle identifier io.github.tom10271.FreeJig.macOS after macOS repeatedly blocked development identities. Existing settings stay in their original preferences store. Open the GUI through Finder, the Dock, or `open dist/FreeJig.app`.

## Use FreeJig

1. Open FreeJig from the Dock or the menu bar.
2. Choose a movement mode and an idle delay.
3. For pointer movement, grant FreeJig access in **System Settings > Privacy & Security > Accessibility**. Silent mode needs no Accessibility access unless you enable an extra action.
4. Click **Start**. The status explains what FreeJig is waiting for.
5. Click **Stop**, press Control-Command-J, or press Command-Q while FreeJig is focused to end the session.

Sessions always start stopped after opening the app. Settings persist locally. If the schedule or app condition blocks a session, FreeJig releases its sleep assertion until the condition matches again. An automatic stop ends the session even while another condition blocks it.

## Controls

| Control | Behavior |
| --- | --- |
| Natural | Smoothly moves the pointer within the selected range on its current display. |
| Subtle | Moves the pointer one pixel and back. |
| Silent | Prevents idle display sleep without moving the pointer. |
| Start after idle | Waits this many seconds after physical keyboard or pointer input. |
| Repeat every | Sets the interval between input pulses. |
| Movement range | Small is up to 12 points on each axis. Medium is up to 100. Full can reach across the current display. |
| Schedule | Runs during selected days and local hours. Overnight schedules belong to their starting day. Equal start and end means a full selected day. |
| Automatic stop | Stops after a duration or at the next occurrence of a local time. |
| App condition | Allows any app, any selected running app, any selected frontmost app, or no selected app in front. |
| Click at pointer | Sends a left, right, or double click at the current pointer position after movement. Off by default. |
| Scroll | Scrolls one line up, down, or alternates direction. Off by default. |
| Shift | Presses and releases the Shift key. Off by default. |
| Launch at login | Opens the app at login with the session stopped. |

Input pulses pause when you use your Mac, hold a mouse button or modifier, lock the session, switch users, or put the Mac to sleep. Clicks can activate buttons and links. Enable them only when you intend to interact with the app at the pointer. Shift can also trigger shortcuts or application behavior.

Silent mode controls idle sleep. It does not manufacture keyboard or mouse activity or guarantee any particular chat application's presence indicator. FreeJig does not bypass screen locking, a closed lid, or explicit sleep.

## Check a change

```sh
swift run FreeJigChecks
bash scripts/build-app.sh
dist/FreeJig.app/Contents/MacOS/FreeJig --self-check
```

The policy checks cover scheduling, overnight boundaries, app conditions, stop deadlines, and settings validation. The app's self-check creates a real macOS power assertion, observes it through IOKit, releases it, and checks that it disappeared.

For a UI check, run `open dist/FreeJig.app --args --show-window`. Check Start, Stop, schedule controls, app selection, and the Accessibility prompt. Real pointer movement, click, scroll, and Shift checks need an Accessibility grant. Check them in an empty test document with no actionable content under the pointer.

Add `--verify-placement` to check the actual displayed window against the screen bounds. This diagnostic checks centering without registering a menu item, then exits automatically. Quit an existing FreeJig instance before running it. A mismatch or an already-running instance exits with status 1.

GitHub Actions runs the policy checks, builds the app, and uploads a ZIP. Contributor changes can use the same commands. See [the design](docs/design.md) for ownership and policy contracts.

See [the verification record](docs/verification.md) for the exact local checks and untested behavior in this first release.

## Privacy and license

FreeJig has no network client, telemetry, accounts, subscriptions, or payment code. Settings use macOS UserDefaults. App conditions read running app identifiers and the frontmost app identifier. Idle detection reads the elapsed time since an input event, not what you type.

Original implementation and artwork. Licensed under [MIT](LICENSE).

The input-source and power behavior use Apple's [Core Graphics event source states](https://developer.apple.com/documentation/coregraphics/cgeventsourcestateid) and [IOKit power assertions](https://developer.apple.com/documentation/iokit/1557134-iopmassertioncreatewithname).
