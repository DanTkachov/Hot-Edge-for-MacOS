# Hot Edge for macOS

A macOS port of the GNOME Shell extension [Hot Edge](https://github.com/jdoda/hotedge).
It turns the whole bottom edge of the screen into a hot area: push the cursor
into it and Mission Control (or another action you choose) opens. Push again to close it.

## Build & install

Needs only the Xcode Command Line Tools.

```bash
./scripts/build.sh --install
```

This builds `build/Hot Edge.app`, runs the self-tests, copies the app to
`/Applications` and launches it. Hot Edge lives in the menu bar. Launch it again
to open Settings.

## How it maps to the original

| GNOME setting | macOS | Default |
|---|---|---|
| `pressure-threshold` | Activation pressure: how far you push past the edge within 1 s (same `PressureBarrier` algorithm) | 150 px |
| `fallback-timeout` | Activation timeout, used when "Rest on the edge" is selected | 250 ms |
| `edge-size` | Edge size, centered, % of display width | 100 % |
| `suppress-activation-when-button-held` | Suppress on mouse button | on |
| `suppress-activation-when-fullscreen` | Suppress on fullscreen | on |
| `primary-monitor-only` | Only on the primary (menu bar) monitor | off |
| `show-animation` | Ripple animation at the hit point | on |

Multi-monitor works like the original: a screen gets a hot edge only when no
other screen sits directly below it.

On macOS the action is configurable: Mission Control, App Exposé,
Apps/Launchpad, Show Desktop, or any app.

## Notes

- No permissions are needed. Watching mouse movement doesn't require Accessibility access.
- Move the Dock to the left or right, or auto-hide it, so it doesn't pop up on the bottom edge.
- Hot Edge doesn't disable macOS hot corners. Manage those in System Settings → Desktop & Dock → Hot Corners.
- `HotEdge --selftest` runs the pressure-logic tests.
