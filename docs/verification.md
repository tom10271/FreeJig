# Verified on 23 October 2026

Environment: Apple Silicon, macOS 26.5.1, Swift 6.3.2 Command Line Tools. The executable targets macOS 13 and later. Older operating systems and Intel hardware were not exercised.

## Passed

- FreeJigChecks in debug and release builds, 15 groups and 80 checks. A deliberately incorrect optimized check exited with status 1.
- Release build, valid application property list, ad-hoc code signature, and expected icon pixel dimensions.
- A real IOKit display-sleep assertion was created, observed in the process assertion table, released, and confirmed absent.
- The live Silent-mode session became active in the UI and appeared in `pmset -g assertions`. Stopping removed the assertion.
- Pointer mode without an Accessibility grant showed the permission-needed state.
- Control-Command-J started and stopped the session. Schedule and automatic-stop controls expanded. The app-condition menu and native application picker opened.
- Actual displayed normal-window frame was 740 by 737 points at 386, 106 in a usable display rectangle of 1512 by 949 points. The runtime check verified both containment and centering.
- Default launch with an unavailable menu bar anchor opened the same centered settings window.
- Closing the settings window and reopening the running app restored the window and passed the same position check.
- Independent scoped source reviews covered the native controller and presentation. Reported normalization, date-picker, and window-lifetime issues were corrected.

## Not verified

- Real delivery of pointer movement, clicks, scroll events, and Shift. FreeJig had no Accessibility grant during testing.
- Permission revocation, screen lock, sleep, and fast-user-switch transitions on a live session.
- Popover placement after an actual menu bar click. The startup anchor on this Mac reported no visible frame, so the centered settings-window fallback was the exercised path.
- Launch at login, Intel builds, and older macOS releases.
- Developer ID signing and Apple notarization. The ZIP is ad-hoc signed.

Default settings were restored, and FreeJig was stopped and closed after the UI checks.

## Power and permission repair on 29 October 2026

The original release repeatedly published unchanged permission and status values once per second. A live stack sample showed those publications causing SwiftUI layout and menu-icon recreation. It also showed enumeration of every running app while the app condition was Any app. The new runtime regression check failed on the original implementation with `unchanged stopped state published 10 UI updates` after five ticks. The repaired implementation passes both stopped and enabled checks without publishing unchanged values. All 80 policy checks also pass.

In the same permission-blocked mode on this Mac, five consecutive five-second CPU-time measurements before the repair ranged from 3.788% to 3.795% of one core, with a median of 3.793%. After the repair, an undisturbed repeat ranged from 0.0% to 0.200%, with a median of 0.0%. These short sequential process-CPU observations are not battery measurements or a conversion of Activity Monitor's Energy Impact. The sampler's CPU-time resolution accounts for zero readings. A first post-repair run that overlapped a menu-service restart was excluded.

The enabled Accessibility entry pointed to the correct app path. However, the macOS privacy log explicitly rejected its stored code requirement because its code hash belonged to an older build. Restarting the unchanged app did not repair that mismatch. FreeJig now explains how to replace the stale entry and reveal the exact app copy. Its permission checks and signing requirements remain unchanged.

Control Center explicitly blocked FreeJig's menu item even while FreeJig was enabled in Menu Bar settings. Switching the UI implementation to SwiftUI MenuBarExtra did not fix the block, so that experiment was reverted. Giving the existing menu item a stable name and restarting Control Center did not clear it either. With user approval, enabling ChatGPT's menu-bar entry changed FreeJig from a blocked host to a tracked host. No protected Control Center registry file was modified.

After the user authenticated in System Settings and added the exact updated app copy, FreeJig recognized the grant. The permission warning disappeared, and a Natural-mode session reached Waiting for you to be idle instead of being blocked. The 60-second delay, 60-second interval and 180-minute automatic stop were preserved. The menu-bar unblock was verified through Control Center's log; a physical click on its icon was not automated. The local session was left enabled with optional clicks, scroll and Shift off. ChatGPT's menu-bar entry remains enabled as the approved workaround.
