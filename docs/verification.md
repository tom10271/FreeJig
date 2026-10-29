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

After the user authenticated in System Settings and added the exact updated app copy, FreeJig recognized the grant. The permission warning disappeared, and a Natural-mode session reached Waiting for you to be idle instead of being blocked. The 60-second delay, 60-second interval and 180-minute automatic stop were preserved. The local session was left enabled with optional clicks, scroll and Shift off.

The subsequent user screenshot showed no menu bar icon. Control Center's tracking log did not prove visibility, so the earlier claim of a resolved menu item was incorrect. System Settings subsequently showed ChatGPT's menu-bar entry off and FreeJig's entry on. FreeJig does not depend on ChatGPT's setting.

## Dock access repair on 29 October 2026

The local test labels 0.1.2, 0.1.3 and 0.1.4 below were not published releases. Those labels were incorrectly advanced during debugging. The release version is 0.1.1; subsequent test packages increment only CFBundleVersion. The app header displays both values directly.

Versions through 0.1.1 explicitly hid FreeJig from the Dock with accessory activation and LSUIElement=true. Version 0.1.2 uses regular activation and LSUIElement=false. Closing the settings window keeps the app running, and reopening it invokes the existing window-reopen handler. This change does not alter input behavior, timers, or thread scheduling. Per-process efficiency-core residency and battery-life savings have not been measured.

The 0.1.2 release build, signature check, runtime self-check, and 80 policy checks passed. The running process reported regular activation and a non-nil application icon. These metadata checks do not prove visible Dock or menu bar icons. After the Dock UI inspector timed out, the user confirmed that the Dock icon was visible and the menu bar icon was still missing. The rebuilt app showed the Accessibility warning again because the ad-hoc code signature changed.

The same 0.1.2 build was installed in /Applications/FreeJig.app. Its executable SHA-256 matched the project build. The project process was stopped before launching the installed copy. The menu bar issue remains unresolved.

## Permanent menu identity and native popup on 29 October 2026

The original development identity was repeatedly moved to Control Center's blocked list after launch. Removing the status item's autosave name, toggling FreeJig's Menu Bar setting off and on, and launching through Finder did not clear that block. The autosave-name experiment was reverted. A temporary copy with a fresh identity was visible, and the user confirmed its icon reopened the controls after the normal window was closed. This diagnostic copy was not the installed app and did not establish a permanent fix.

The manual menu-click path could open a normal window. That window did not dismiss after outside clicks, and the click path rebuilt and measured the hosting view. The unreleased fixes replace that path with native MenuBarExtra window presentation. An interim build used io.github.tom10271.FreeJig. The existing preferences suite remains authoritative. Temporary presentation diagnostics were removed. The build script updates the bundle directory timestamp before packaging.

The release build, runtime self-check and signature verification passed. Independent review found no blocking issues. The installed executable matched the project package. Finder launched the installed app under the new identity, and the 60-second idle delay, 60-second interval and 180-minute stop remained intact. The UI inspector retained stale metadata for the old identity. A physical metadata copy launched a second process instead of binding to the installed process, causing two visible icons. Both inspector copies were stopped and disabled.

Startup now exits before creating a controller or menu item when another instance already exists. Activation of that instance is best effort, and activation failure cannot create a duplicate. The runtime duplicate-launch check exited successfully with only the existing installed process remaining. Independent review confirmed the unconditional return. The self-check remains isolated from this guard.

Native popup dismissal, final Command-Q and repeated reopen checks are in progress. Accessibility has not been granted to the permanent identity yet. No per-core residency or battery-life improvement is claimed.

## Full content sizing and isolated diagnostics

The fixed 750-point popup and always-bidirectional scroll wrapper produced both scrollbars and hid the footer. Both presentations now share SettingsContent, which chooses natural content before bounded overflow scrolling. Actual SwiftUI checks measured natural content at 740 by 786 points, a full-size presentation at 757 by 786 points, and a small-display presentation at 608 by 416 points. Hosting size is measured before automatic sizing is disabled and retained across attachment. The final live normal-window check passed with an actual 757 by 818-point frame centered at 377,65 inside the 1512 by 949-point display.

The interim identity was later blocked again. Enabling ChatGPT's Menu Bar setting unblocked the exact existing host, and restoring ChatGPT to off blocked that host again. The setting was restored to off. This is evidence of the launcher-record association, not a resolved icon. A normal Finder relaunch of the interim identity did not clear its polluted record.

The final macOS bundle/signing identifier is io.github.tom10271.FreeJig.macOS. At this stage, --verify-placement ran AppDelegate's normal window without the SwiftUI App lifecycle. Its live frame check passed, and Control Center recorded no menu host for this identity during that diagnostic. The diagnostic terminated after PASS and rejected an already-running instance explicitly. This isolated lifecycle later proved insufficient to catch the startup crash described below.

The user's next popup screenshot showed a thin strip. A focused native check reproduced this as `menu popup collapses to (757.0, 0.0) for natural content (740.0, 786.0)`. Fixing the bounded view at its ideal vertical size changed its minimum to approximately 785.2 points. The normal, wide-but-short and narrow display cases passed. Native view-hierarchy checks found no scroll view on the normal layout and an active scroll view in both overflow layouts. Independent review found no remaining blocker. Actual final popup appearance, outside-click dismissal and reopening remain pending user confirmation.

Four old runnable task bundles were archived as ZIPs and removed. The current build stages under .build/FreeJig.noindex; dist contains the release ZIP. A Spotlight metadata query subsequently returned only /Applications/FreeJig.app. The installed executable matched the staged build. The Spotlight UI inspector timed out, so visual search confirmation remains separate.

## Startup constraint loop on 29 October 2026

Normal Finder launches of 0.1.1 build 13 crashed in NSHostingView.updateWindowContentSizeExtremaIfNecessary. AppKit reported more constraint-update passes than views in the window. Temporary instrumentation showed the window alternating between 818 and 813 points tall while a five-point top safe-area inset appeared and disappeared. Disabling scene bridging did not resolve it and was reverted.

The manually sized AppKit host now disables SwiftUI's added safe-area regions on macOS 13.3 and later. The instrumented build stopped alternating sizes and remained running for more than five minutes after a Finder launch. The native menu popup uses a separate host. All temporary instrumentation was removed from build 18.

The placement diagnostic now uses the SwiftUI App lifecycle and verifies the displayed window after two seconds. Without the fix it exited with SIGTRAP and the same constraint-update stack as the user's report. With the fix it exited with status 0 and reported `PASS: visible window {{377, 65}, {757, 818}} fits display {{0, 0}, {1512, 949}}`. GitHub Actions now runs this diagnostic after building.

Build 18 passed all 80 policy checks, the three native sizing cases, power-assertion checks and strict signature verification. Its installed executable matched the staged artifact. Normal Finder launch remained running without a new crash report. Live popup sizing, outside-click dismissal, Command-Q and reopening still require direct confirmation because the FreeJig UI inspector timed out. Active input delivery and battery use remain unverified.

## Diagnostic menu isolation

The user reported that build 18 still had no menu icon. Control Center logs showed that the diagnostic's `MenuBarExtra` with insertion set to false still registered a host, changed its visibility to false and moved it to the blocked list. The subsequent installed-app host was also blocked. Refreshing FreeJig's latest two menu-setting entries did not unblock it. The previously approved ChatGPT toggle test unblocked that exact host; ChatGPT's setting was then restored to off. These logs establish a launcher-permission association, not a working menu icon.

Build 19 replaces the diagnostic scene with a separate Settings-only SwiftUI app sharing AppDelegate. It never constructs MenuBarExtra. The normal scene again uses the original MenuBarExtra initializer. The Settings-only diagnostic reproduced the unfixed crash and passed with the safe-area fix. Its Control Center log window contained no FreeJig menu-host messages. The packaged diagnostic also exited 0 with the centered window. Independent review found no blocker.

The installed build 19 executable matches the staged artifact, and its strict signature verification passed. The staged app's Launch Services registration was removed and the installed copy's registration refreshed. The user manually launched the correct Applications copy and confirmed that its icon was still absent. Launch Services recorded Spotlight as its parent; Control Center still explicitly blocked the host. The launch route alone therefore did not explain the failure.

A temporary same-process probe compared the original SwiftUI item with a native NSStatusItem named FreeJig.Controls. Control Center blocked both. That probe was removed and the exact verified build 19 restored. Both remote CI runs passed, including the startup check. Visible menu access and popup behavior remain unresolved. The system-wide Control Centre reset was inspected and cancelled; testing it requires approval because it resets the user's layout.
