# Window Pin

Window Pin keeps a window visible above your other work on an Apple silicon Mac. Choose a window, and the app shows a live view that stays on top. Drag that view anywhere. When you are finished, the original window comes back where you left the pin.

The pin is view-only. You cannot click or type inside it. That is deliberate: a call, a video, or a chat can keep playing while you work in another app.

This repository supports **macOS on Apple silicon (arm64) only**. It does not include an Intel build.

## Download

The current release is [Window Pin 1.0.0](https://github.com/hatemragab/window-pin/releases/tag/v1.0.0).

Download **WindowPin-arm64.dmg**. It contains a menu-bar app for macOS 14 Sonoma or newer on Apple silicon.

| | |
| --- | --- |
| Mac | Apple silicon only (M1 or newer) |
| macOS | 14.0 or newer |
| Intel Macs | Not supported |
| Kind of app | Menu-bar app, no Dock icon |

## Install

1. Open `WindowPin-arm64.dmg`.
2. Drag **Window Pin** into **Applications**.
3. Open **Window Pin** from Applications. A pin icon appears in the menu bar.
4. Allow **Screen Recording** and **Accessibility** when macOS asks.
5. Click **Relaunch** in the Window Pin window after you allow Screen Recording.

macOS applies Screen Recording only to a freshly opened copy of the app. If the status lines stay red after you allow access, quit Window Pin and open it again from Applications.

The release is signed with a Developer ID certificate. It is not notarized. The first time you open it, macOS may say it cannot be opened. Use **Right click → Open**, or go to **System Settings → Privacy & Security** and choose **Open Anyway**.

## Permissions

Window Pin asks for two permissions. Both stay on your Mac. The app has no account, no analytics, and no network service. It does not save a recording.

**Screen Recording** lets macOS share the pixels of the window you picked, so the pin can draw a live view. Window Pin does not record the whole screen and does not write video to disk.

**Accessibility** lets Window Pin move the original window almost entirely off screen while the pin is showing, then put that window back when you unpin it. A thin sliver stays on screen so some apps, including Chromium browsers, keep drawing video instead of pausing.

If you turn a permission on in System Settings and Window Pin still says it is not allowed, the switch may belong to an older copy of the app. Turn **Window Pin** off, open the copy in Applications, allow the new prompt, and relaunch.

## Use it

- Click the pin in the menu bar and choose **Pin a Window…**, or press **Control-Command-P**.
- Click the window you want. Press **Esc** to cancel.
- Or choose **Pin from List** and pick a window by name.
- Drag the pin to move it. Drag the bottom-right corner to resize it. The picture keeps its original shape.
- Click the red pin badge, or choose **Unpin** in the menu, to bring the original window back.
- **Unpin All** restores every pinned window.
- **Launch at Login** is available after the app is in Applications.

You can pin more than one window. Each pin has its own live view.

The original window is parked at the left edge of the desktop while its pin is visible. Unpin puts it back at the pin’s top-left, at its original size, and raises it. If Window Pin quits unexpectedly, the next launch moves any parked window back on screen.

Some windows cannot be captured. The desktop, the Dock, and Window Pin’s own windows are skipped. A window that refuses screen capture shows an error instead of a pin, and it is not moved.

## Privacy

Everything happens locally.

- Screen Recording is used only to draw the live pin.
- Accessibility is used only to park and restore the window you pinned.
- No video file is created.
- No account is required.
- The app does not send window contents anywhere.

Parked-window positions are stored in `~/Library/Application Support/Window Pin/` so a crash can restore them. That file is removed as windows are unpinned.

## Build

Build on an Apple silicon Mac with macOS 14 or newer and the Xcode command line tools. The script does not download packages.

```sh
git clone https://github.com/hatemragab/window-pin.git
cd window-pin
zsh build-app.sh
```

The script compiles an arm64 release, draws the app icon, and writes:

- `dist/Window Pin.app`
- `dist/WindowPin-arm64.dmg`

If a **Developer ID Application** certificate for Hatem Ragab is in the login keychain, the script signs with that identity and does not add a timestamp. Otherwise it uses an ad-hoc signature, which is enough for the same Mac but will not match a permission grant after the app is signed again.

The build does not notarize the app. `build-app.sh` passes `--arch arm64` and does not produce an Intel slice.

## How it works

1. You click a window, or pick one from the menu.
2. ScreenCaptureKit starts a live capture of that window.
3. A borderless window at floating level shows the frames above normal windows, on every Space.
4. Accessibility moves the source window off to the side so you are not looking at two copies.
5. Unpin stops the capture and moves the source window back.

The live view uses `AVSampleBufferDisplayLayer`. Capture size follows the window’s display scale and is capped so a very large window stays responsive.

## Limits

- Apple silicon only. An Intel Mac cannot run this build.
- The pin is not a second interactive window. Click the red pin when you need the real window.
- Full-screen apps and some protected windows may not appear in the list or may not capture.
- A permission grant is tied to this app’s signature. Replacing the app with a differently signed copy makes macOS treat it as a new app.
- The app is not notarized, so Gatekeeper asks the first time you open a downloaded copy.

## License

Copyright Hatem Ragab. This repository is public so you can read the source and download the arm64 release. No license is granted to copy or redistribute it.
