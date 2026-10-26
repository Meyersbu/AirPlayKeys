import AppKit
import ApplicationServices
import Foundation

// AirPlayKeys controls speakers selected inside Apple Music.
// It does not modify macOS system output or install an audio driver.

private enum MediaKey: Int {
    case louder = 0
    case quieter = 1
    case mute = 7
}

private final class AirPlayKeysApp: NSObject, NSApplicationDelegate {
    private let musicQueue = DispatchQueue(label: "net.meyershome.AirPlayKeys.Music")
    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var captureMenuItem: NSMenuItem!
    private var louderMenuItem: NSMenuItem!
    private var quieterMenuItem: NSMenuItem!
    private var muteMenuItem: NSMenuItem!
    private var tap: CFMachPort?
    private var source: CFRunLoopSource?
    private var hasAirPlay = false
    private var isChecking = false
    private var enabled = UserDefaults.standard.object(forKey: "captureEnabled") as? Bool ?? true
    private var statusText = "Verbinde mit Apple Music …"
    private var lastError: String?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        configureMenu()
        installTap()
        checkAirPlay()
        Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            self?.checkAirPlay()
        }
    }

    private func menuItem(_ title: String, symbol: String? = nil, action: Selector? = nil) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        if let symbol {
            item.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
        }
        return item
    }

    private func configureMenu() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let icon = NSImage(systemSymbolName: "airplayaudio", accessibilityDescription: "AirPlayKeys") {
            icon.isTemplate = true
            statusItem.button?.image = icon
        } else {
            statusItem.button?.title = "♫"
        }

        let menu = NSMenu()
        let heading = menuItem("AirPlayKeys")
        heading.isEnabled = false
        menu.addItem(heading)

        statusMenuItem = menuItem(statusText)
        statusMenuItem.isEnabled = false
        menu.addItem(statusMenuItem)
        menu.addItem(.separator())

        louderMenuItem = menuItem("Lauter", symbol: "speaker.wave.3", action: #selector(louder))
        quieterMenuItem = menuItem("Leiser", symbol: "speaker.wave.1", action: #selector(quieter))
        muteMenuItem = menuItem("Stumm / Ton an", symbol: "speaker.slash", action: #selector(toggleMute))
        menu.addItem(louderMenuItem)
        menu.addItem(quieterMenuItem)
        menu.addItem(muteMenuItem)
        menu.addItem(.separator())

        captureMenuItem = menuItem("Lautstärketasten übernehmen", action: #selector(toggleCapture))
        menu.addItem(captureMenuItem)
        menu.addItem(menuItem("Verbindung prüfen", symbol: "arrow.clockwise", action: #selector(recheck)))
        menu.addItem(menuItem("Apple Music öffnen", symbol: "music.note", action: #selector(openMusic)))
        menu.addItem(.separator())
        menu.addItem(menuItem("Beenden", action: #selector(quitApp)))
        statusItem.menu = menu
        updateStatus()
    }

    private func updateStatus() {
        statusMenuItem.title = statusText
        statusItem.button?.toolTip = "AirPlayKeys · \(statusText)"
        captureMenuItem.state = enabled ? .on : .off
        louderMenuItem.isEnabled = hasAirPlay
        quieterMenuItem.isEnabled = hasAirPlay
        muteMenuItem.isEnabled = hasAirPlay
    }

    private func installTap() {
        if tap != nil { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        if !AXIsProcessTrustedWithOptions(opts) {
            statusText = "Bedienungshilfen-Berechtigung fehlt"
            updateStatus()
            return
        }
        let mask = CGEventMask(1) << 14
        tap = CGEvent.tapCreate(tap: .cgSessionEventTap,
                                place: .headInsertEventTap,
                                options: .defaultTap,
                                eventsOfInterest: mask,
                                callback: airPlayKeysCallback,
                                userInfo: Unmanaged.passUnretained(self).toOpaque())
        guard let tap else {
            statusText = "Tastaturzugriff nicht verfügbar"
            updateStatus()
            return
        }
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let source {
            CFRunLoopAddSource(CFRunLoopGetMain(), source, CFRunLoopMode.commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        statusText = "Warte auf AirPlay in Apple Music"
        updateStatus()
    }

    fileprivate func handleSystemEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap { CGEvent.tapEnable(tap: tap, enable: true) }
            return Unmanaged.passUnretained(event)
        }
        guard type.rawValue == 14,
              let keyEvent = NSEvent(cgEvent: event),
              keyEvent.type == .systemDefined,
              keyEvent.subtype.rawValue == 8 else {
            return Unmanaged.passUnretained(event)
        }
        let data = keyEvent.data1
        let keyCode = (data >> 16) & 0xFFFF
        let state = (data >> 8) & 0xFF
        guard let key = MediaKey(rawValue: keyCode), enabled, hasAirPlay else {
            return Unmanaged.passUnretained(event)
        }
        if state == 0xA { perform(key) }
        return nil
    }

    private func checkAirPlay() {
        guard !isChecking else { return }
        guard !NSRunningApplication.runningApplications(withBundleIdentifier: "com.apple.Music").isEmpty else {
            hasAirPlay = false
            statusText = "Apple Music ist nicht geöffnet"
            updateStatus()
            return
        }
        isChecking = true
        musicQueue.async { [weak self] in
            guard let self else { return }
            let script = """
            tell application "Music"
                set deviceCount to 0
                repeat with aSpeaker in (every AirPlay device whose selected is true)
                    if (name of aSpeaker as text) is not "Computer" then
                        set deviceCount to deviceCount + 1
                    end if
                end repeat
                return deviceCount
            end tell
            """
            let output = self.execute(script)
            let count = output.flatMap { Int($0) }
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isChecking = false
                self.hasAirPlay = (count ?? 0) > 0
                switch count {
                case nil:
                    self.statusText = "Apple Music: Zugriff prüfen"
                case .some(0):
                    self.statusText = "Kein AirPlay-Gerät ausgewählt"
                case .some(let number):
                    self.statusText = number == 1 ? "1 AirPlay-Gerät verbunden" : "\(number) AirPlay-Geräte verbunden"
                }
                self.updateStatus()
            }
        }
    }

    private func perform(_ key: MediaKey) {
        musicQueue.async { [weak self] in
            guard let self else { return }
            let script: String
            switch key {
            case .mute:
                script = """
                tell application "Music"
                    set mute to (not mute)
                end tell
                """
            case .louder, .quieter:
                let step = key == .louder ? 5 : -5
                script = """
                tell application "Music"
                    repeat with aSpeaker in (every AirPlay device whose selected is true)
                        if (name of aSpeaker as text) is not "Computer" then
                            set newLevel to (sound volume of aSpeaker) + (\(step))
                            if newLevel > 100 then set newLevel to 100
                            if newLevel < 0 then set newLevel to 0
                            set sound volume of aSpeaker to newLevel
                        end if
                    end repeat
                end tell
                """
            }
            _ = self.execute(script)
        }
    }

    private func execute(_ script: String) -> String? {
        guard let appleScript = NSAppleScript(source: script) else { return nil }
        var error: NSDictionary?
        let result = appleScript.executeAndReturnError(&error)
        if let error {
            let message = error.description
            if message != lastError {
                lastError = message
                NSLog("AirPlayKeys: Apple Music automation failed: %@", message)
            }
            return nil
        }
        lastError = nil
        return String(result.int32Value)
    }

    @objc private func louder() { perform(.louder) }
    @objc private func quieter() { perform(.quieter) }
    @objc private func toggleMute() { perform(.mute) }
    @objc private func recheck() { installTap(); checkAirPlay() }
    @objc private func toggleCapture() {
        enabled.toggle()
        UserDefaults.standard.set(enabled, forKey: "captureEnabled")
        updateStatus()
    }
    @objc private func openMusic() {
        if let app = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Music") {
            NSWorkspace.shared.open(app)
        }
    }
    @objc private func quitApp() { NSApp.terminate(nil) }
}

private let airPlayKeysCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return Unmanaged.passUnretained(event) }
    let app = Unmanaged<AirPlayKeysApp>.fromOpaque(userInfo).takeUnretainedValue()
    return app.handleSystemEvent(type: type, event: event)
}

let application = NSApplication.shared
private let delegate = AirPlayKeysApp()
application.delegate = delegate
application.run()
