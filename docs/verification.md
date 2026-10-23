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
