<p align="center">
  <img src="Assets/AppIcon.svg" width="96" height="96" alt="AirPlayKeys icon">
</p>

<h1 align="center">AirPlayKeys</h1>
<p align="center">Volume keys for AirPlay speakers selected in Apple Music.<br>A small, free, native macOS menu bar utility.</p>

---

AirPlayKeys lets you use the Mac keyboard volume keys with AirPlay speakers selected **inside Apple Music**. For example, control the output of a Belkin SoundForm Connect attached to an amplifier.

| Key | Action |
| --- | --- |
| F10 | Toggle Apple Music mute |
| F11 | Lower each selected AirPlay speaker by 5 percentage points |
| F12 | Raise each selected AirPlay speaker by 5 percentage points |

The menu bar provides volume controls, connection status and a capture on/off switch. When no selected Music AirPlay device is available, the original key events are passed through to macOS.

**Status: Experimental v0.2.0.** A previous version compiled successfully on macOS. This version and actual device behavior still require testing.

## Installation

Requires macOS 12+, Apple Music and Xcode Command Line Tools. To install the tools, run `xcode-select --install`.

Download the repository ZIP or clone it, then run from its directory:

```sh
./build.sh
open build/AirPlayKeys.app
```

1. Allow **Accessibility** in System Settings → Privacy & Security → Accessibility. Some macOS configurations may also request Input Monitoring.
2. Allow **Music Automation** when macOS prompts you.
3. Select an AirPlay speaker using the **AirPlay button in Apple Music** (not the macOS Sound output selector).
4. In the app's menu bar menu, choose **Verbindung prüfen** (Check connection).

Depending on keyboard settings you may need to hold Fn/Globe for the media functions. To run at login, move the built app to a permanent folder (for example, Applications) and add it under System Settings → General → Login Items.

## Limitations

- **Apple Music only.** This does not change system audio output volume for Spotify, Safari, games or other apps.
- AirPlay selected in macOS Sound settings is **not** sufficient; speakers must be selected in Music.
- F10 switches **Music's mute setting**, not each speaker's individual mute setting.
- Build is signed locally with an **ad-hoc** signature. No notarized binary release is provided.
- Accessibility/Input Monitoring is required to intercept media key events; AppleScript locally controls Music. No network communication or telemetry is included.

## Troubleshooting

| Problem | What to check |
| --- | --- |
| Volume keys still change Mac volume | Accessibility permission, capture enabled, AirPlay selected in Apple Music, then use **Verbindung prüfen** |
| Music access error | System Settings → Privacy & Security → Automation → Music access for AirPlayKeys; restart the app |
| No Dock icon | Expected: AirPlayKeys is a menu bar app |
| Build fails | Ensure Command Line Tools are installed; check the first compiler error |

## Project

```text
AirPlayKeys.swift            Swift / AppKit application
Info.plist                   App metadata and permissions
build.sh                     Local build, icon generation and signing
Tools/GenerateIcon.swift     Render the application icon
Assets/                      Vector branding used by this README
.github/workflows/build.yml  macOS build check
```

No third-party dependencies. Contributions and issue reports are welcome.

MIT licensed.